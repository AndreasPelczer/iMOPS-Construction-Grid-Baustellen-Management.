//
//  Grap8Graph.swift
//  Core Data → Grap8-Leinwand. **Nur lesen.**
//
//  Die Leinwand (React Flow, `Grap8Web/`) erwartet Knoten und Kanten in einem
//  festen Format. Hier wird eine Baustelle in genau dieses Format übersetzt —
//  eine Einbahnstraße: was auf der Leinwand geklickt wird, kommt NICHT zurück.
//  Das ist Absicht für diesen Schritt, siehe `Grap8View`.
//
//  Was die Leinwand selbst rechnet und wir deshalb NICHT schicken:
//  „startklar" und „wartet" leitet sie aus den Kanten ab (`statusOf` in `App.jsx`).
//  Wir liefern nur den rohen Zustand (`base`) — genau wie `Auftrag.istStartbar`
//  auf der Swift-Seite live rechnet statt zu speichern. Eine Wahrheit, zwei Rechner.
//

import Foundation
import CoreData

// MARK: - Das Format der Leinwand

/// Ein Graph, wie ihn `window.grap8SetGraph(...)` in `App.jsx` erwartet.
struct Grap8Graph: Encodable {
    let baustelle: String
    let nodes: [Knoten]
    let edges: [Kante]

    struct Knoten: Encodable {
        let id: String
        let type: String        // immer "auftrag" — der einzige Knotentyp der Leinwand
        let position: Position
        let data: Daten
    }

    struct Position: Encodable {
        let x: Double
        let y: Double
    }

    struct Daten: Encodable {
        let title: String
        let kg: String
        let icon: String
        let base: String        // "offen" | "inArbeit" | "erledigt"
        let anf: [Anforderung]
    }

    /// Die Chips Material/Mensch/Maschine. Bleibt in diesem Schritt leer —
    /// im Modell steht nicht, welcher Auftrag was braucht. Eigener Schritt.
    struct Anforderung: Encodable {
        let typ: String
        let erfuellt: Bool
    }

    struct Kante: Encodable {
        let id: String
        let source: String
        let target: String
    }
}

// MARK: - Übersetzung

extension Grap8Graph {

    /// Baut den Graphen einer Baustelle aus Core Data.
    ///
    /// Liest ausschließlich; kein `save`, keine Änderung am Kontext.
    static func aus(_ event: Event) -> Grap8Graph {
        let auftraege = ((event.jobs?.allObjects as? [Auftrag]) ?? [])
            // Stabile Reihenfolge, damit ein zweites Öffnen dasselbe Bild ergibt.
            .sorted { Kausalkette.bezeichnung($0) < Kausalkette.bezeichnung($1) }

        let kennung = kennungen(fuer: auftraege)
        let spalten = spaltenAufteilung(auftraege)

        let knoten: [Knoten] = auftraege.compactMap { auftrag in
            guard let id = kennung[ObjectIdentifier(auftrag)] else { return nil }
            let platz = spalten[ObjectIdentifier(auftrag)] ?? (0, 0)
            return Knoten(
                id: id,
                type: "auftrag",
                position: Position(x: 40 + Double(platz.spalte) * 260,
                                   y: 40 + Double(platz.zeile) * 180),
                data: Daten(
                    title: Kausalkette.bezeichnung(auftrag),
                    kg: kostengruppe(auftrag),
                    icon: symbol(auftrag),
                    base: zustand(auftrag),
                    anf: []
                )
            )
        }

        // Eine Kante je `Voraussetzung` mit Quelle: „target braucht vorher source".
        // Voraussetzungen ohne Quelle sind Geschoss-Häkchen (Welle 9), keine Kanten —
        // `istKante` ist die Stelle, die das unterscheidet.
        var kanten: [Kante] = []
        for auftrag in auftraege {
            guard let zielID = kennung[ObjectIdentifier(auftrag)] else { continue }
            for kante in auftrag.voraussetzungenArray where kante.istKante {
                guard let quelle = kante.quelle,
                      let quellID = kennung[ObjectIdentifier(quelle)] else { continue }
                kanten.append(Kante(
                    id: kante.id?.uuidString ?? "\(quellID)->\(zielID)",
                    source: quellID,
                    target: zielID
                ))
            }
        }

        return Grap8Graph(baustelle: event.title ?? event.name ?? "Baustelle",
                          nodes: knoten,
                          edges: kanten)
    }

    // MARK: Kennungen

    /// Stabile Kennung je Auftrag.
    ///
    /// `Auftrag` hat **kein** eigenes ID-Feld (nachgesehen im Modell — anders als
    /// `Voraussetzung`, die eine UUID trägt). Darum die Core-Data-Objekt-URI: für
    /// gespeicherte Objekte eindeutig und über Sitzungen stabil.
    private static func kennungen(fuer auftraege: [Auftrag]) -> [ObjectIdentifier: String] {
        var tabelle: [ObjectIdentifier: String] = [:]
        for auftrag in auftraege {
            tabelle[ObjectIdentifier(auftrag)] = auftrag.objectID.uriRepresentation().absoluteString
        }
        return tabelle
    }

    // MARK: Anordnung

    /// Wo ein Knoten liegt: Spalte = wie tief in der Kette, Zeile = laufend.
    private typealias Platz = (spalte: Int, zeile: Int)

    /// Wie viele freistehende Aufträge nebeneinander, bevor umgebrochen wird.
    private static let rasterBreite = 4

    /// Hat dieser Auftrag überhaupt eine Kante — in eine der beiden Richtungen?
    private static func haengtInEinerKette(_ auftrag: Auftrag) -> Bool {
        !auftrag.vorgaenger.isEmpty || !auftrag.istVoraussetzungFuerArray.isEmpty
    }

    /// Einfaches Auto-Layout: Core Data kennt keine Leinwand-Positionen.
    ///
    /// Verkettete Aufträge stehen in Spalten nach Tiefe — Fundament links, Estrich
    /// rechts, ohne dass jemand etwas anordnen muss.
    ///
    /// Freistehende Aufträge (heute die Regel: die App hat noch keine Bedienung,
    /// um zwei Aufträge zu verknüpfen) kämen dabei alle in Spalte 0 und stünden
    /// als endlose Einerkolonne untereinander — nachgemessen im Simulator, neun
    /// Aufträge, neun Zeilen. Darum werden sie im Raster gesetzt: sichtbar auf
    /// einen Blick, statt scrollen zu müssen.
    private static func spaltenAufteilung(_ auftraege: [Auftrag]) -> [ObjectIdentifier: Platz] {
        var tiefe: [ObjectIdentifier: Int] = [:]
        // Ein Kreis in Altdaten darf die Rekursion nicht ewig laufen lassen —
        // dieselbe Vorsicht wie in `Kausalkette.wuerdeZyklusErzeugen`.
        var inArbeit: Set<ObjectIdentifier> = []

        func tiefeVon(_ auftrag: Auftrag) -> Int {
            let schluessel = ObjectIdentifier(auftrag)
            if let fertig = tiefe[schluessel] { return fertig }
            guard inArbeit.insert(schluessel).inserted else { return 0 }
            defer { inArbeit.remove(schluessel) }

            let vorgaenger = auftrag.vorgaenger
            let wert = vorgaenger.isEmpty ? 0 : (vorgaenger.map(tiefeVon).max() ?? 0) + 1
            tiefe[schluessel] = wert
            return wert
        }

        var plaetze: [ObjectIdentifier: Platz] = [:]
        var belegtInSpalte: [Int: Int] = [:]

        // 1. Die Ketten: Spalte = Tiefe.
        for auftrag in auftraege where haengtInEinerKette(auftrag) {
            let spalte = tiefeVon(auftrag)
            let zeile = belegtInSpalte[spalte, default: 0]
            belegtInSpalte[spalte] = zeile + 1
            plaetze[ObjectIdentifier(auftrag)] = (spalte, zeile)
        }

        // 2. Die Freistehenden ins Raster, unterhalb der Ketten.
        let versatz = belegtInSpalte.values.max().map { $0 + 1 } ?? 0
        for (nummer, auftrag) in auftraege.filter({ !haengtInEinerKette($0) }).enumerated() {
            plaetze[ObjectIdentifier(auftrag)] = (nummer % rasterBreite,
                                                  versatz + nummer / rasterBreite)
        }
        return plaetze
    }

    // MARK: Felder

    /// Der rohe Zustand für die Leinwand.
    ///
    /// `onHold` (Pausiert) hat auf der Leinwand kein Gegenstück — sie kennt nur
    /// offen/inArbeit/erledigt. Ein pausierter Auftrag ist angefangen, darum
    /// `inArbeit`. **Notlösung:** wer auf der Leinwand pausiert sehen will,
    /// braucht dort einen vierten Zustand.
    private static func zustand(_ auftrag: Auftrag) -> String {
        switch auftrag.status {
        case .completed:  return "erledigt"
        case .inProgress: return "inArbeit"
        case .onHold:     return "inArbeit"
        case .pending:    return "offen"
        }
    }

    private static func kostengruppe(_ auftrag: Auftrag) -> String {
        let nummer = auftrag.kostenGruppeNummer?.trimmingCharacters(in: .whitespaces) ?? ""
        return nummer.isEmpty ? "KG —" : "KG \(nummer)"
    }

    /// Symbol aus der Kostengruppe. Core Data speichert kein Symbol; die Zuordnung
    /// nutzt die neun Icons der Leinwand (`ICONS` in `App.jsx`) — mehr gibt es nicht.
    ///
    /// **Korrigiert:** die erste Fassung dieser Liste trug Bezeichnungen aus dem
    /// Gedächtnis, und drei davon waren falsch — 352 ist „Deckenöffnungen" (nicht
    /// Estrich, das ist 353), 336 ist „Außenwandbekleidung innen" (nicht tragende
    /// Innenwände, das ist 341), 534 ist „Stellplätze" (nicht Zäune). Jede Nummer
    /// hier ist jetzt gegen `DIN276BaumKatalog` geprüft; die Kommentare sind die
    /// Katalog-Bezeichnungen. Die alten Nummern bleiben stehen — Bestandsdaten
    /// können sie tragen —, aber sie stehen nicht mehr für das Falsche.
    ///
    /// Zwei Doppelungen, bewusst: **Sanitär und Heizung** teilen sich `Route`, weil
    /// die Palette kein Haustechnik-Symbol hat und beides Rohrleitungs-Gewerke sind.
    /// **Estrich und Ausbau** teilen sich `Grid2x2`, weil Fliesen und Bodenbeläge
    /// dieselbe Kostengruppe tragen (353).
    private static func symbol(_ auftrag: Auftrag) -> String {
        let nummer = auftrag.kostenGruppeNummer?.trimmingCharacters(in: .whitespaces) ?? ""
        switch nummer.prefix(3) {
        // 300 — Baukonstruktionen
        case "322": return "Box"        // Flachgründungen und Bodenplatten
        case "331": return "Blocks"     // Tragende Außenwände
        case "334": return "Blocks"     // Außenwandöffnungen
        case "336": return "Blocks"     // Außenwandbekleidung innen
        case "341": return "Blocks"     // Tragende Innenwände
        case "342": return "Blocks"     // Nichttragende Innenwände
        case "346": return "Blocks"     // Elementierte Innenwände
        case "345": return "Layers"     // Innenwandbekleidung
        case "351": return "Layers"     // Deckenkonstruktion
        case "352": return "Layers"     // Deckenöffnungen
        case "353": return "Grid2x2"    // Deckenbeläge
        case "354": return "Grid2x2"    // Deckenbekleidungen
        case "361": return "Home"       // Dachkonstruktionen
        case "363": return "Home"       // Dachbeläge
        case "397": return "SquarePlus" // Zusätzliche Maßnahmen
        // 400 — Technische Anlagen
        case "410", "411", "412": return "Route"   // Abwasser-, Wasser-, Gasanlagen
        case "420", "421", "422": return "Route"   // Wärmeversorgungsanlagen
        case "442": return "Zap"        // Eigenstromversorgungsanlagen
        case "444": return "Zap"        // Niederspannungsinstallationsanlagen
        // 500 — Außenanlagen und Freiflächen
        case "541": return "Fence"      // Einfriedungen
        case "544": return "Route"      // Rampen, Treppen, Tribünen
        case "523": return "Fence"      // Gründungsbeläge
        case "531": return "Fence"      // Wege
        case "533": return "Fence"      // Plätze, Höfe, Terrassen
        case "534": return "Fence"      // Stellplätze
        default:    return "Box"
        }
    }
}
