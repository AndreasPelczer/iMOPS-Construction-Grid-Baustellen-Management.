//
//  Kausalkette.swift
//  Grap8 Branch 1 — Schritt→Schritt-Abhängigkeiten.
//
//  „Ohne Topf aufsetzen und Wasser erhitzen kann ich keine Nudeln kochen.“
//
//  Eine `Voraussetzung` mit `quelle` ist eine Kante im Graph: der abhängige
//  Auftrag (`auftrag`) darf erst starten, wenn der Quell-Auftrag fertig ist.
//  Eine `Voraussetzung` OHNE `quelle` bleibt, was sie war — ein manuelles
//  Häkchen an einem Geschoss (Welle 9, siehe `Hierarchie+Status.swift`).
//
//  Wie dort gilt: hier wird NICHTS persistiert. Startbarkeit ist immer live
//  aus dem Status der Vorgänger gerechnet, damit es keine zweite Wahrheit gibt,
//  die veralten kann.
//

import Foundation
import CoreData

// MARK: - Fehler

enum KausalketteFehler: LocalizedError {
    /// Die Kante würde einen Kreis schließen — direkt oder über Zwischenschritte.
    case zyklus(ziel: String, quelle: String)
    /// Ein Schritt kann nicht auf sich selbst warten.
    case selbstbezug(String)

    var errorDescription: String? {
        switch self {
        case let .zyklus(ziel, quelle):
            return "„\(ziel)“ kann nicht auf „\(quelle)“ warten: "
                 + "„\(quelle)“ wartet (direkt oder über Zwischenschritte) bereits auf „\(ziel)“. "
                 + "Das wäre ein Kreis — dann könnte keiner von beiden je anfangen."
        case let .selbstbezug(name):
            return "„\(name)“ kann nicht seine eigene Voraussetzung sein."
        }
    }
}

// MARK: - Der Dienst

enum Kausalkette {

    /// Gilt ein Auftrag als erledigt?
    ///
    /// Die Krücke ist abgelöst: hier stand eine ODER-Prüfung über `isCompleted`
    /// **und** `status`, weil die beiden Felder auseinanderliefen. Seit
    /// `Auftrag.istFertig` gibt es genau eine Quelle, und `status` ist sie.
    ///
    /// *Nachtrag zur Begründung von damals:* Die Richtung war falsch beschrieben.
    /// Nicht `AuftragDetailView` setzte allein den Status — umgekehrt setzten die
    /// Checklisten-Aktionen dort **nur** `isCompleted` und nie `status`, und
    /// `resetCompletion()` öffnete den Auftrag, ließ `status` aber auf
    /// `.completed`. Die Krücke war trotzdem nötig, nur eben andersherum.
    static func istFertig(_ auftrag: Auftrag) -> Bool {
        auftrag.istFertig
    }

    /// Legt die Kante „\(ziel) braucht vorher \(quelle)“ an.
    ///
    /// Wirft, wenn dadurch ein Kreis entstünde — der Graph muss ein DAG bleiben,
    /// sonst blockieren sich zwei Schritte gegenseitig für immer.
    @discardableResult
    static func verknuepfe(_ ziel: Auftrag,
                           brauchtVorher quelle: Auftrag,
                           name: String? = nil,
                           in context: NSManagedObjectContext) throws -> Voraussetzung {
        if quelle === ziel {
            throw KausalketteFehler.selbstbezug(bezeichnung(ziel))
        }
        if wuerdeZyklusErzeugen(ziel: ziel, quelle: quelle) {
            throw KausalketteFehler.zyklus(ziel: bezeichnung(ziel), quelle: bezeichnung(quelle))
        }

        let kante = Voraussetzung(context: context)
        kante.id = UUID()
        kante.name = name ?? bezeichnung(quelle)
        // Eine Graph-Kante rechnet sich aus dem Vorgänger — sie wird nicht abgehakt.
        kante.typ = VoraussetzungsTyp.automatisch.rawValue
        kante.reihenfolge = Int16(ziel.voraussetzungenArray.count)
        kante.quelle = quelle
        kante.auftrag = ziel
        return kante
    }

    /// Würde „ziel braucht quelle“ einen Kreis schließen?
    ///
    /// Tiefensuche rückwärts über die `quelle`-Kanten: erreicht man vom
    /// Vorgänger aus wieder das Ziel, hängt der Vorgänger bereits vom Ziel ab.
    static func wuerdeZyklusErzeugen(ziel: Auftrag, quelle: Auftrag) -> Bool {
        if quelle === ziel { return true }
        var gesehen = Set<ObjectIdentifier>()
        var stapel: [Auftrag] = [quelle]

        while let aktuell = stapel.popLast() {
            if aktuell === ziel { return true }
            // Schon besucht? Dann weiter — schützt auch vor Altdaten,
            // in denen bereits ein Kreis steckt (sonst liefe die Suche ewig).
            guard gesehen.insert(ObjectIdentifier(aktuell)).inserted else { continue }
            for kante in aktuell.voraussetzungenArray {
                if let vorgaenger = kante.quelle {
                    stapel.append(vorgaenger)
                }
            }
        }
        return false
    }

    /// Sprechender Name für Meldungen — `processingDetails` ist im Bestand das
    /// Feld, das die Gewerkbezeichnung trägt (siehe `KausalbauketteView`).
    static func bezeichnung(_ auftrag: Auftrag) -> String {
        let details = auftrag.processingDetails?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let details = details, !details.isEmpty { return details }
        return "Unbenannter Auftrag"
    }
}

// MARK: - Voraussetzung: erfüllt?

extension Voraussetzung {
    /// Eine Kante ist erfüllt, wenn ihr Vorgänger fertig ist.
    /// Ohne Vorgänger bleibt es beim gespeicherten Häkchen (Geschoss-Checkliste).
    var istErfuellt: Bool {
        if let quelle = quelle {
            return Kausalkette.istFertig(quelle)
        }
        return erfuellt
    }

    /// Kante im Schritt→Schritt-Graph (statt manuelles Geschoss-Häkchen)?
    var istKante: Bool { quelle != nil }
}

// MARK: - Auftrag: startbar?

extension Auftrag {
    /// Die Voraussetzungen DIESES Auftrags, in Reihenfolge.
    var voraussetzungenArray: [Voraussetzung] {
        ((voraussetzungen?.allObjects as? [Voraussetzung]) ?? [])
            .sorted { $0.reihenfolge < $1.reihenfolge }
    }

    /// Kanten, in denen dieser Auftrag der Vorgänger ist — wen blockiert er?
    var istVoraussetzungFuerArray: [Voraussetzung] {
        (istVoraussetzungFuer?.allObjects as? [Voraussetzung]) ?? []
    }

    /// Was noch fehlt, bevor losgelegt werden kann — die „Vorgewerk nicht
    /// fertig“-Blocker. Später der Eingang für Dispo und Eskalation.
    var offeneVoraussetzungen: [Voraussetzung] {
        voraussetzungenArray.filter { !$0.istErfuellt }
    }

    /// Startbar = alle Voraussetzungen erfüllt. Ohne Voraussetzungen: sofort.
    var istStartbar: Bool { offeneVoraussetzungen.isEmpty }

    /// Die Aufträge, die direkt vor diesem liegen.
    var vorgaenger: [Auftrag] {
        voraussetzungenArray.compactMap { $0.quelle }
    }
}
