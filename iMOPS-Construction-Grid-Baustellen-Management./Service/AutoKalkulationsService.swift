import Foundation
import CoreData

// MARK: - AutoKalkulationsService  („Mops fass")
//
// Orchestriert die automatische Bepreisung eines importierten GAEB-LV.
//
// KEIN neuer Motor: die Kette existiert schon. Dieser Service RUFT sie über das ganze LV
//   1. `LeistungskatalogService.autoMatch(position:in:)` — findet das gelernte Rezept und
//      schreibt Lohn (+ Material/Gerät) auf die Position; Treffer=true, sonst false.
//   2. `LVKalkulator.kalkuliere(position:)` — rechnet daraus den Einheitspreis.
// und DIAGNOSTIZIERT, was zum vollständigen Preis noch fehlt.
//
// Das Mops-Protokoll: Kein Preis ohne Grundlage. Lieber eine ehrliche Lücke (ROT) als eine
// erfundene Zahl. Der Mops schätzt nichts von selbst — GELB heißt „Rezept da, aber ein Wert
// fehlt" (Aufwandswert/Material), zu füllen über die vorhandene Schätzung/Stammdaten.
enum AutoKalkulationsService {

    enum Status: String { case gruen, gelb, rot }

    struct Ergebnis: Identifiable {
        let id = UUID()
        let position: LVPosition
        let status: Status
        let meldungen: [String]
        let einheitspreisVK: Double
        /// Trägt einen von der KI geratenen Wert, der noch nicht bestätigt wurde.
        var enthaeltKI: Bool = false
    }

    /// Bilanz für die Ampel-Karte oben in der Review.
    struct Bilanz {
        let gruen: Int
        let gelb: Int
        let rot: Int
        /// Positionen mit einer ungeprüften KI-Schätzung — die sperren den Export mit.
        let kiUngeprueft: Int
        var gesamt: Int { gruen + gelb + rot }
        /// Export erst erlaubt, wenn keine Position mehr ROT ist UND keine ungeprüfte
        /// KI-Schätzung drinsteht — eine geratene Zahl darf nicht an die Stadt (Vier-Augen bleibt separat).
        var exportBereit: Bool { rot == 0 && kiUngeprueft == 0 && gesamt > 0 }
    }

    static func bilanz(_ ergebnisse: [Ergebnis]) -> Bilanz {
        Bilanz(
            gruen: ergebnisse.filter { $0.status == .gruen }.count,
            gelb: ergebnisse.filter { $0.status == .gelb }.count,
            rot: ergebnisse.filter { $0.status == .rot }.count,
            kiUngeprueft: ergebnisse.filter { $0.enthaeltKI }.count)
    }

    /// „Mops fass": über alle Positionen matchen + rechnen + diagnostizieren.
    /// Achtung: verändert die Positionen (schreibt das Rezept auf Treffer) — genau das ist
    /// das Ausfüllen. Gedacht direkt nach dem Import (leere Positionen).
    @discardableResult
    static func fass(positionen: [LVPosition], in ctx: NSManagedObjectContext) -> [Ergebnis] {
        positionen.map { bewerte($0, in: ctx) }
    }

    /// Legt den Mops-Vorschlag NUR dann an, wenn die Position noch nichts trägt — damit die
    /// Tiefenkalkulation beim Öffnen vorausgefüllt ist, ohne je von Hand Eingetragenes zu
    /// überschreiben. **Schutzregel:** `schreibeAufwandAusKolonne` löscht vorhandenen Lohn;
    /// darum rühren wir eine Position mit Lohn/Material/Gerät nicht an. Elemente rechnen über
    /// ihre Bausteine und bleiben ebenfalls unberührt.
    /// - Returns: true, wenn vorgefüllt wurde (die Position war leer).
    @discardableResult
    static func vorfuellenWennLeer(_ pos: LVPosition, in ctx: NSManagedObjectContext) -> Bool {
        guard !pos.istElement,
              pos.lohnArray.isEmpty,
              pos.materialArray.isEmpty,
              pos.geraeteArray.isEmpty else { return false }
        _ = bewerte(pos, in: ctx)
        return true
    }

    /// Eine Position bewerten. Trägt sie eine ungeprüfte KI-Schätzung, bleibt sie GELB und
    /// gesperrt — eine geratene Zahl darf nicht als „fertig" ins Angebot, bis ein Mensch sie
    /// bestätigt (Badge antippen → bestätigen, oder überschreiben).
    static func bewerte(_ pos: LVPosition, in ctx: NSManagedObjectContext) -> Ergebnis {
        let e = bewerteRoh(pos, in: ctx)
        guard hatKIWert(pos) else { return e }
        let hinweis = "🟣 KI geraten — Startwert ohne Quelle. Prüfen und bestätigen, bevor das Angebot rausgeht."
        return Ergebnis(position: pos, status: .gelb,
                        meldungen: [hinweis] + e.meldungen,
                        einheitspreisVK: e.einheitspreisVK, enthaeltKI: true)
    }

    /// Trägt die Position einen von der KI geratenen, noch nicht bestätigten Wert?
    private static func hatKIWert(_ pos: LVPosition) -> Bool {
        pos.materialArray.contains { Kostenquelle($0.quelle) == .ki }
            || pos.lohnArray.contains { Kostenquelle($0.quelle) == .ki }
            || pos.geraeteArray.contains { Kostenquelle($0.quelle) == .ki }
    }

    /// Die reine Bewertung aus dem Modell — keine Schätzung.
    private static func bewerteRoh(_ pos: LVPosition, in ctx: NSManagedObjectContext) -> Ergebnis {
        let bez = (pos.bezeichnung ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let einheit = (pos.einheit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // 0) Trägt die Position schon eigene Kosten (von Hand, KI-Schätzung, früher gefüllt)?
        //    Dann bewerten, WAS DA IST — nicht neu matchen: autoMatch/Richtwert würde den Lohn
        //    löschen bzw. den Hand-/KI-Preis ignorieren. Elemente rechnen über ihre Bausteine.
        let hatEigeneKosten = !(pos.materialArray.isEmpty && pos.lohnArray.isEmpty && pos.geraeteArray.isEmpty)
        if !pos.istElement, hatEigeneKosten {
            return bewerteVorhandenen(pos)
        }

        // 1) Rezept-Treffer? (schreibt bei Treffer Lohn/Material/Gerät auf die Position)
        guard LeistungskatalogService.autoMatch(position: pos, in: ctx) else {
            // Kein gelerntes Rezept. Weg über den STLB: Position → Baustein → aufwandswert_key
            // → deterministischer Richtwert (echte Kolonne + Quelle). GELB statt blind ROT.
            if let b = STLBKatalog.shared.finde(leistung: bez),
               let key = b.aufwandswertKey,
               let t = AufwandswerteKatalog.shared.eintrag(key: key) {
                return gelbAusRichtwert(t, baustein: b.id, maschinenKeys: b.maschinenKeys, pos: pos, in: ctx)
            }
            // Fallback: direkter Stichwort-Treffer im Aufwandswerte-Katalog.
            if let t = AufwandswerteKatalog.shared.finde(leistung: bez, langtext: pos.langtext) {
                return gelbAusRichtwert(t, baustein: nil, pos: pos, in: ctx)
            }
            // Stundenlohn-/Regie-Position (Einheit = Stunde, z. B. „Meister"/„Facharbeiter"):
            // direkt zum Satz des aktiven Firmenprofils bepreisen. Der EP IST der Stundensatz.
            if istStundenlohn(einheit) {
                let rolle = bez.isEmpty ? "Facharbeiter" : bez
                let satz = Firmenprofil.aktiv.satz(fuer: LeistungskatalogService.tarifgruppe(fuer: rolle), in: ctx)
                LeistungskatalogService.schreibeStundenlohn(qualifikation: rolle, satzProStunde: satz, auf: pos, in: ctx)
                let kalk = LVKalkulator.kalkuliere(position: pos)
                let msg = "🟡 Stundenlohn/Regie (\(Firmenprofil.aktiv.anzeige)): "
                        + "\(String(format: "%.2f €", satz))/h für \(rolle). Satz aus dem Firmenprofil — prüfen."
                return Ergebnis(position: pos, status: .gelb, meldungen: [msg],
                                einheitspreisVK: kalk.einheitspreisVK)
            }
            return Ergebnis(
                position: pos, status: .rot,
                meldungen: ["Kein gelerntes Rezept und kein Richtwert für „\(bez)“ (\(einheit.isEmpty ? "?" : einheit)). "
                          + "Aus dem Katalog wählen, eine Aufwandswert-Schätzung übernehmen oder Stammdaten ergänzen."],
                einheitspreisVK: 0)
        }

        // 2) Aus dem Rezept rechnen und auf Vollständigkeit prüfen.
        return bewerteVorhandenen(pos)
    }

    /// Bewertet die Position aus ihren VORHANDENEN Kosten (Rezept, Hand oder KI) — rechnet
    /// den Preis und prüft auf Lücken. Ändert nichts, matcht nicht neu.
    private static func bewerteVorhandenen(_ pos: LVPosition) -> Ergebnis {
        let einheit = (pos.einheit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let kalk = LVKalkulator.kalkuliere(position: pos)
        var meldungen: [String] = []

        // Material da, aber ohne Preis?
        let unbepreist = pos.materialArray.filter {
            ($0.materialName?.isEmpty == false) && $0.einzelpreis <= 0
        }
        for m in unbepreist {
            meldungen.append("Kein Materialpreis für „\(m.materialName ?? "")“ — in Stammdaten ergänzen.")
        }

        // Kein Preis herausgekommen → der Aufwandswert (Lohn) fehlt meist.
        if kalk.einheitspreisVK <= 0 {
            if kalk.lohnKosten <= 0 {
                meldungen.append("Kein Aufwandswert (Lohn) hinterlegt — Prof/KI-Schätzung übernehmen oder Erfahrungswert eintragen.")
            }
            return Ergebnis(position: pos, status: .gelb,
                            meldungen: meldungen.isEmpty ? ["Preis 0 — bitte prüfen."] : meldungen,
                            einheitspreisVK: kalk.einheitspreisVK)
        }

        // Preis da, aber Material-Lücke → GELB (bepreist, aber noch nicht sauber).
        if !unbepreist.isEmpty {
            return Ergebnis(position: pos, status: .gelb, meldungen: meldungen,
                            einheitspreisVK: kalk.einheitspreisVK)
        }

        // Vollständig gerechnet → GRÜN, mit transparenter Quelle.
        let quelle = "Kalkuliert: \(euro(kalk.einheitspreisVK))/\(einheit) "
                   + "(Lohn \(euro(kalk.lohnKosten)) · Material \(euro(kalk.materialKosten)) · Gerät \(euro(kalk.geraeteKosten)))"
        return Ergebnis(position: pos, status: .gruen, meldungen: [quelle],
                        einheitspreisVK: kalk.einheitspreisVK)
    }

    /// Schreibt den Richtwert als GELB-Schätzung auf die Position (echte Kolonne + Quelle).
    /// `baustein` = STLB-ID falls über den STLB gefunden (transparent in der Meldung).
    private static func gelbAusRichtwert(_ t: AufwandsTreffer, baustein: String?,
                                         maschinenKeys: [String] = [],
                                         pos: LVPosition, in ctx: NSManagedObjectContext) -> Ergebnis {
        let posEinheit = (pos.einheit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let stbQuelle = baustein.map { "STLB \($0) · " } ?? ""

        // Dichte einmal bestimmen — sie überbrückt Volumen↔Masse SOWOHL für den Lohn
        // (h/m³ → h/t) ALS AUCH für die Maschinen (m³/h-Leistung an einer t-Position).
        let dichte = DichteKatalog.dichte(fuer: pos.bezeichnung)

        // Der Aufwandswert steht je Katalog-Einheit (z. B. h/m³). Die Position rechnet in
        // IHRER Einheit (z. B. t). Erst umrechnen — sonst wäre der Lohn grob falsch
        // (t↔kg = Faktor 1000, der Bewehrungs-Ausreißer). Gleiche Größenart → direkt;
        // Volumen↔Masse (m³↔t) → über die Dichte (Schüttgut-Richtwert); sonst ehrlich flaggen.
        let faktor: Double
        var dichteHinweis = ""
        if let f = EinheitenUmrechnung.proFaktor(von: t.einheit, nach: posEinheit) {
            faktor = f
        } else if let d = dichte,
                  let f = EinheitenUmrechnung.proFaktorMitDichte(von: t.einheit, nach: posEinheit, dichteTproM3: d) {
            faktor = f
            dichteHinweis = " · über Dichte \(String(format: "%g", d)) t/m³ (Schüttgut-Richtwert, prüfen)"
        } else {
            let msg = "🟠 \(stbQuelle)Einheit prüfen: Aufwandswert in „\(t.einheit)“, Position in "
                    + "„\(posEinheit.isEmpty ? "?" : posEinheit)“ — nicht umrechenbar. Kein Lohnpreis "
                    + "gesetzt (er wäre sonst grob falsch). Einheit der Position anpassen oder von Hand bepreisen."
            return Ergebnis(position: pos, status: .gelb, meldungen: [msg], einheitspreisVK: 0)
        }

        let stundenProEinheit = t.mittel * faktor

        // Nach der ECHTEN Kolonne bepreisen: Baggerfahrer zum Maschinisten-Satz, Helfer zum
        // Helfer-Satz — nicht mehr alles als Maurer.
        LeistungskatalogService.schreibeAufwandAusKolonne(
            mittelStunden: stundenProEinheit, kolonne: t.kolonne, auf: pos, in: ctx,
            quelle: LeistungskatalogService.herkunft(ausQuelle: t.quelleKurz))

        // Die Maschinen der Kolonne dazu: der STLB-Baustein nennt sie (maschinen_keys),
        // der Maschinenkatalog kennt Leistung + Mietpreis. Eigener Park hat Vorrang.
        let geraeteHinweis = schreibeMaschinen(keys: maschinenKeys, pos: pos,
                                               posEinheit: posEinheit, dichte: dichte, in: ctx)

        let kalk = LVKalkulator.kalkuliere(position: pos)

        let g = String(format: "%g", t.mittel), lo = String(format: "%g", t.min), hi = String(format: "%g", t.max)
        // Wenn umgerechnet wurde, transparent zeigen (h/t → h/kg), sonst schlicht h/Einheit.
        let umHinweis = faktor == 1 ? ""
            : " → \(String(format: "%g", stundenProEinheit)) h/\(posEinheit) (umgerechnet)"
        let msg = "🟡 \(stbQuelle)Richtwert \(g) h/\(t.einheit)\(umHinweis)\(dichteHinweis) (Spanne \(lo)–\(hi)) · Mannschaft: "
                + "\(t.kolonne.isEmpty ? "—" : t.kolonne) · Quelle \(t.quelleKurz).\(geraeteHinweis) "
                + "Schätzung (Rollen + Geräte bepreist); Material fehlt noch."
        return Ergebnis(position: pos, status: .gelb, meldungen: [msg], einheitspreisVK: kalk.einheitspreisVK)
    }

    // MARK: - Maschinen-Brücke (Geräte aus dem Katalog an die Position)

    /// Hängt die Maschinen der Kolonne als Geräte-Zeilen an die Position — aus den
    /// `maschinen_keys` des STLB-Bausteins. Für jede Maschine:
    ///   1. eigener Park (Core-Data `Geraet`, Name passt)? → dein Abschreibungssatz, GRÜN „dein Wert".
    ///   2. sonst Katalog-Mietpreis (Tage-Modell) → BLAU „Richtwert" (leihen).
    /// Die Maschinen-Leistung steht in m³/h bzw. m²/h — die Position oft in t. Umgerechnet
    /// wird über die Dichte (t→m³) und, für flächenbezogene Maschinen, über die Schichtdicke
    /// (m³→m²). Klappt eine Umrechnung nicht, wird die Maschine ehrlich übersprungen.
    /// - Returns: Klartext-Zusatz für die Meldung (welche Geräte dran sind / was fehlt).
    private static func schreibeMaschinen(keys: [String], pos: LVPosition,
                                          posEinheit: String, dichte: Double?,
                                          in ctx: NSManagedObjectContext) -> String {
        guard !keys.isEmpty else { return "" }
        let maschinen = MaschinenKatalog.shared.maschinen(ids: keys)
        guard !maschinen.isEmpty, pos.menge > 0 else { return "" }

        let dickeM = schichtdickeMeter(aus: [pos.bezeichnung, pos.langtext])
        let eigene = eigeneGeraete(in: ctx)

        var dran: [String] = []
        var uebersprungen: [String] = []

        for m in maschinen {
            guard let hl = m.hauptLeistung,
                  let (mengeMasch, zielEinheit) = mengeFuerLeistung(
                    posMenge: pos.menge, posEinheit: posEinheit,
                    leistungEinheit: hl.einheit, dichte: dichte, dickeM: dickeM) else {
                uebersprungen.append(m.bezeichnung)
                continue
            }

            // 1) Eigener Park? Name-Treffer mit gesetztem Satz → dein Wert.
            if let g = passendesEigenes(m, in: eigene), g.kostenProStunde > 0, g.leistung > 0 {
                let stundenGesamt = mengeMasch / g.leistung
                schreibeGeraetStunden(name: "\(m.bezeichnung) (dein Park)",
                                      stundenJeEinheit: stundenGesamt / pos.menge,
                                      satzProStunde: g.kostenProStunde,
                                      quelle: "eigen", pos: pos, in: ctx)
                dran.append("\(m.bezeichnung) (Park)")
                continue
            }

            // 2) Katalog-Mietpreis, Tage-Modell (ein halber Tag Bagger kostet einen ganzen Miettag).
            guard let mk = m.mietkostenTageModell(menge: mengeMasch, einheit: zielEinheit) else {
                uebersprungen.append(m.bezeichnung)
                continue
            }
            guard let tag = m.mieteTag, tag > 0 else { uebersprungen.append(m.bezeichnung); continue }
            schreibeGeraetPauschal(name: "\(m.bezeichnung) (Miet-Richtwert)",
                                   tage: mk.tage, satzProTag: tag,
                                   quelle: "katalog", pos: pos, in: ctx)
            dran.append("\(m.bezeichnung) (\(mk.tage) Tag\(mk.tage == 1 ? "" : "e") leihen)")
        }

        var teile = ""
        if !dran.isEmpty { teile += " Geräte: \(dran.joined(separator: ", "))." }
        if !uebersprungen.isEmpty {
            teile += " Nicht umgerechnet (Einheit/Dicke unklar): \(uebersprungen.joined(separator: ", ")) — von Hand."
        }
        return teile
    }

    /// Position-Menge (in ihrer Einheit) in die Leistungs-Einheit der Maschine bringen.
    /// m³/h → m3 (ggf. über Dichte); m²/h → m2 (über Dichte in m³, dann ÷ Schichtdicke);
    /// m/h → m (direkt). nil, wenn kein Weg passt.
    private static func mengeFuerLeistung(posMenge: Double, posEinheit: String,
                                          leistungEinheit: String, dichte: Double?, dickeM: Double?)
        -> (menge: Double, einheit: String)? {
        let ziel: String
        switch leistungEinheit {
        case "m³/h": ziel = "m3"
        case "m²/h": ziel = "m2"
        case "m/h":  ziel = "m"
        default:     return nil
        }
        // Direkt (gleiche Größenart, oder Volumen↔Masse über Dichte).
        if let mm = EinheitenUmrechnung.mengeUmrechnen(posMenge, von: posEinheit, nach: ziel, dichteTproM3: dichte) {
            return (mm, ziel)
        }
        // Fläche aus Volumen ÷ Schichtdicke (die Position ist eine Schicht bekannter Dicke).
        if ziel == "m2", let dicke = dickeM, dicke > 0,
           let m3 = EinheitenUmrechnung.mengeUmrechnen(posMenge, von: posEinheit, nach: "m3", dichteTproM3: dichte) {
            return (m3 / dicke, "m2")
        }
        return nil
    }

    /// Schichtdicke in Metern aus einem Positionstext („d= 10cm", „d=0,10 m", „10 cm").
    static func schichtdickeMeter(aus texte: [String?]) -> Double? {
        let text = texte.compactMap { $0 }.joined(separator: " ").lowercased()
        // „d= 10cm" / „d=0,10m" bevorzugt, sonst erste „<zahl> cm"-Angabe.
        let muster = [#"d\s*=?\s*([0-9]+(?:[.,][0-9]+)?)\s*(cm|m)\b"#,
                      #"([0-9]+(?:[.,][0-9]+)?)\s*(cm)\b"#]
        for p in muster {
            guard let re = try? NSRegularExpression(pattern: p) else { continue }
            let r = NSRange(text.startIndex..., in: text)
            guard let m = re.firstMatch(in: text, range: r),
                  let zr = Range(m.range(at: 1), in: text),
                  let er = Range(m.range(at: 2), in: text) else { continue }
            let zahl = Double(text[zr].replacingOccurrences(of: ",", with: ".")) ?? 0
            guard zahl > 0 else { continue }
            return text[er] == "cm" ? zahl / 100.0 : zahl
        }
        return nil
    }

    /// Alle eigenen Geräte (Maschinenpark, Stammdaten) — für den Park-vor-Miete-Vorrang.
    private static func eigeneGeraete(in ctx: NSManagedObjectContext) -> [Geraet] {
        (try? ctx.fetch(Geraet.fetchRequest())) ?? []
    }

    /// Ein eigenes Gerät, dessen Name zur Katalog-Maschine passt (grobes Stichwort-Match:
    /// „bagger"/„walze"/… kommt in beiden vor). Konservativ — im Zweifel nichts, dann Miete.
    private static func passendesEigenes(_ m: Maschine, in eigene: [Geraet]) -> Geraet? {
        let kat = BauTextMatcher.tokenize(m.bezeichnung).filter { $0.count >= 5 }
        guard !kat.isEmpty else { return nil }
        return eigene.first { g in
            let namen = Set(BauTextMatcher.tokenize(g.name ?? ""))
            return kat.contains { namen.contains($0) }
        }
    }

    private static func schreibeGeraetStunden(name: String, stundenJeEinheit: Double,
                                              satzProStunde: Double, quelle: String,
                                              pos: LVPosition, in ctx: NSManagedObjectContext) {
        let pg = PositionGeraet(context: ctx)
        pg.id = UUID()
        pg.geraetName = name
        pg.pauschal = false
        pg.stunden = stundenJeEinheit          // h je Positions-Einheit (wie der Lohn)
        pg.kostenProStunde = satzProStunde
        pg.einheit = "h"
        pg.quelle = quelle
        pg.position = pos
    }

    private static func schreibeGeraetPauschal(name: String, tage: Int, satzProTag: Double,
                                               quelle: String, pos: LVPosition,
                                               in ctx: NSManagedObjectContext) {
        let pg = PositionGeraet(context: ctx)
        pg.id = UUID()
        pg.geraetName = name
        pg.pauschal = true
        pg.stunden = Double(tage)               // Anzahl Miettage
        pg.kostenProStunde = satzProTag         // €/Tag (pauschal: Preis je Zähl-Einheit)
        pg.einheit = "Tag"
        pg.quelle = quelle
        pg.position = pos
    }

    /// Regie-/Stundenlohn-Einheit? (Std, h, Stunde …) — dann ist der EP der Stundensatz.
    private static func istStundenlohn(_ einheit: String) -> Bool {
        let e = einheit.lowercased().replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
        return ["h", "std", "stunde", "stunden", "std", "akh", "mannstunde", "mannstunden"].contains(e)
    }

    private static func euro(_ d: Double) -> String { String(format: "%.2f €", d) }
}
