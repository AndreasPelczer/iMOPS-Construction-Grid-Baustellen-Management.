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
                return gelbAusRichtwert(t, baustein: b.id, maschinenKeys: b.maschinenKeys,
                                        material: b.material, vorhaltung: b.vorhaltung,
                                        richtHoeheM: b.hoeheM, richtDickeM: b.dickeM,
                                        pos: pos, in: ctx)
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
                                         material: STLBBaustein.MaterialLink? = nil,
                                         vorhaltung: STLBBaustein.VorhaltungLink? = nil,
                                         richtHoeheM: Double? = nil, richtDickeM: Double? = nil,
                                         pos: LVPosition, in ctx: NSManagedObjectContext) -> Ergebnis {
        let posEinheit = (pos.einheit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let stbQuelle = baustein.map { "STLB \($0) · " } ?? ""

        // Die Brückenmaße EINMAL sammeln — sie verbinden die Größenarten für Lohn, Maschine
        // UND Material über denselben `MopsUmrechner` (die Leiter Länge→Fläche→Volumen→Masse):
        // Dichte (Volumen↔Masse), Schichtdicke (Fläche↔Volumen), Höhe (Länge↔Fläche).
        // Der Text der Position gewinnt; nennt er nichts, füllt das Bauteil-Richtmaß des
        // Bausteins die Lücke (z. B. Fundamentschalung ~0,5 m Höhe — Richtwert, prüfen).
        var bruecke = brueckeFuer(pos)
        if bruecke.hoeheOderBreite == nil { bruecke.hoeheOderBreite = richtHoeheM }
        if bruecke.dicke == nil { bruecke.dicke = richtDickeM }

        // Der Aufwandswert steht je Katalog-Einheit (z. B. h/m³). Die Position rechnet in
        // IHRER Einheit (z. B. t). Erst umrechnen — sonst wäre der Lohn grob falsch
        // (t↔kg = Faktor 1000, der Bewehrungs-Ausreißer). Gleiche Größenart → direkt; über
        // Größenarten hinweg → über die Brückenmaße; fehlt eine Sprosse → ehrlich flaggen.
        guard let um = MopsUmrechner.umrechnung(von: t.einheit, nach: posEinheit, bruecke: bruecke) else {
            let msg = "🟠 \(stbQuelle)Einheit prüfen: Aufwandswert in „\(t.einheit)“, Position in "
                    + "„\(posEinheit.isEmpty ? "?" : posEinheit)“ — nicht umrechenbar (Brückenmaß fehlt, "
                    + "z. B. Höhe/Dichte). Kein Lohnpreis gesetzt. Einheit anpassen oder von Hand bepreisen."
            return Ergebnis(position: pos, status: .gelb, meldungen: [msg], einheitspreisVK: 0)
        }
        let dichteHinweis = um.hinweis.isEmpty ? "" : " · \(um.hinweis) (Richtwert, prüfen)"
        let stundenProEinheit = t.mittel * um.proFaktor

        // Nach der ECHTEN Kolonne bepreisen: Baggerfahrer zum Maschinisten-Satz, Helfer zum
        // Helfer-Satz — nicht mehr alles als Maurer.
        LeistungskatalogService.schreibeAufwandAusKolonne(
            mittelStunden: stundenProEinheit, kolonne: t.kolonne, auf: pos, in: ctx,
            quelle: LeistungskatalogService.herkunft(ausQuelle: t.quelleKurz))

        // Die Maschinen der Kolonne dazu: der STLB-Baustein nennt sie (maschinen_keys),
        // der Maschinenkatalog kennt Leistung + Mietpreis. Eigener Park hat Vorrang.
        let geraeteHinweis = schreibeMaschinen(keys: maschinenKeys, pos: pos,
                                               posEinheit: posEinheit, bruecke: bruecke, in: ctx)

        // Das Material (bei Schüttgütern der GRÖSSTE Posten) dazu: der Baustein nennt es,
        // Preis aus den Stammdaten oder als Katalog-Richtwert, plus Lager-Stand.
        let materialHinweis = schreibeMaterial(material, pos: pos,
                                               posEinheit: posEinheit, bruecke: bruecke, in: ctx)

        // Vorhaltung (Schalung): das wiederverwendbare Betriebsmittel als Geräte-Zeile —
        // €/m² Schalfläche je Einsatz. Der Hauptkostenblock der Schalung neben dem Lohn.
        let vorhaltungHinweis = schreibeVorhaltung(vorhaltung, pos: pos,
                                                   posEinheit: posEinheit, bruecke: bruecke, in: ctx)

        let kalk = LVKalkulator.kalkuliere(position: pos)

        let g = String(format: "%g", t.mittel), lo = String(format: "%g", t.min), hi = String(format: "%g", t.max)
        // Wenn umgerechnet wurde, transparent zeigen (h/t → h/kg), sonst schlicht h/Einheit.
        let umHinweis = um.proFaktor == 1 ? ""
            : " → \(String(format: "%g", stundenProEinheit)) h/\(posEinheit) (umgerechnet)"
        let materialOffen = (material == nil && vorhaltung == nil) ? " Material fehlt noch." : ""
        let msg = "🟡 \(stbQuelle)Richtwert \(g) h/\(t.einheit)\(umHinweis)\(dichteHinweis) (Spanne \(lo)–\(hi)) · Mannschaft: "
                + "\(t.kolonne.isEmpty ? "—" : t.kolonne) · Quelle \(t.quelleKurz).\(geraeteHinweis)\(vorhaltungHinweis)\(materialHinweis)"
                + " Schätzung (Rollen + Geräte bepreist).\(materialOffen)"
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
                                          posEinheit: String, bruecke: MopsUmrechner.Bruecke,
                                          in ctx: NSManagedObjectContext) -> String {
        guard !keys.isEmpty else { return "" }
        let maschinen = MaschinenKatalog.shared.maschinen(ids: keys)
        guard !maschinen.isEmpty, pos.menge > 0 else { return "" }

        let eigene = eigeneGeraete(in: ctx)

        var dran: [String] = []
        var uebersprungen: [String] = []

        for m in maschinen {
            // Die Positionsmenge in die Leistungs-Einheit der Maschine bringen (m³/h → m³ …) —
            // über denselben Umrechner (t→m³ Dichte, m³→m² Dicke, m→m² Höhe, alles auf der Leiter).
            guard let hl = m.hauptLeistung,
                  let zielEinheit = leistungsBasisEinheit(hl.einheit),
                  let mengeMasch = MopsUmrechner.mengeUmrechnen(pos.menge, von: posEinheit,
                                                                nach: zielEinheit, bruecke: bruecke) else {
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
                                   anzahl: Double(mk.tage), zaehlEinheit: "Tag", satzProEinheit: tag,
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

    // MARK: - Material-Brücke (das Schüttgut an die Position + Lager-Stand)

    /// Hängt das Material des Bausteins als Material-Zeile an die Position.
    /// Menge: die Positionsmenge in die Handelseinheit des Materials umgerechnet (t↔m³ über
    /// die Dichte) — bei Schüttgut ist das die gelieferte Tonnage. Preis in dieser Reihenfolge:
    ///   1. Stammdaten (KalkMaterial, dein Einkaufspreis) → GRÜN „dein Wert".
    ///   2. Katalog-Richtpreis (Praxis) → BLAU „Richtwert".
    ///   3. keiner → 0 €, Zeile bleibt sichtbar (GELB „Materialpreis ergänzen") — ehrlich,
    ///      damit du siehst, DASS Material gebraucht wird.
    /// Dazu der Lager-Stand: auf Lager, teils, oder muss bestellt werden.
    /// - Returns: Klartext-Zusatz für die Meldung (Material + Lager).
    private static func schreibeMaterial(_ link: STLBBaustein.MaterialLink?, pos: LVPosition,
                                         posEinheit: String, bruecke: MopsUmrechner.Bruecke,
                                         in ctx: NSManagedObjectContext) -> String {
        guard let link = link, pos.menge > 0 else { return "" }
        let matEinheit = link.einheit.isEmpty ? posEinheit : link.einheit

        // Menge des Materials in seiner Handelseinheit (z. B. 70 t Schotter für 70 t Position;
        // bei einer m³-Position über die Dichte in t). Das Material bringt seine EIGENE Dichte
        // mit (falls gesetzt) — die überschreibt die aus dem Positionstext, denn „Bettungsmaterial"
        // verrät keine Dichte, „Edelsplitt 2/5" ist aber 1,5 t/m³. Klappt nicht → Menge = 1:1.
        var matBruecke = bruecke
        if let d = link.dichte, d > 0 { matBruecke.dichteTproM3 = d }
        let matMenge = MopsUmrechner.mengeUmrechnen(pos.menge, von: posEinheit, nach: matEinheit,
                                                    bruecke: matBruecke) ?? pos.menge
        let mengeProEinheit = matMenge / pos.menge   // Material je Positions-Einheit

        // Preis: Stammdaten vor Richtwert.
        let preis: Double
        let quelle: String
        if let p = LeistungskatalogService.materialPreis(fuer: link.text, in: ctx), p > 0 {
            preis = p; quelle = "eigen"
        } else if let r = link.richtpreis, r > 0 {
            preis = r; quelle = "praxis"
        } else {
            preis = 0; quelle = "startwert"
        }

        let pm = PositionMaterial(context: ctx)
        pm.id = UUID()
        pm.materialName = link.text
        pm.einheit = matEinheit
        pm.mengeProEinheit = mengeProEinheit
        pm.einzelpreis = preis
        pm.verschnittProzent = link.verschnitt
        pm.quelle = quelle
        pm.position = pos

        // Lager: auf Lager / teils / bestellen.
        let mengeText = "\(String(format: "%g", matMenge)) \(matEinheit)"
        let lager: String
        if let bestand = LeistungskatalogService.lagerBestand(fuer: link.text, in: ctx) {
            if bestand >= matMenge {
                lager = "auf Lager (\(String(format: "%g", bestand)) \(matEinheit) da, gebraucht \(mengeText))"
            } else if bestand > 0 {
                lager = "teils auf Lager (\(String(format: "%g", bestand)) \(matEinheit) da, Rest bestellen)"
            } else {
                lager = "Bestand 0 → bestellen"
            }
        } else {
            lager = "nicht im Lager erfasst → bestellen"
        }

        let preisText = preis > 0
            ? "\(String(format: "%.2f €", preis))/\(matEinheit)\(quelle == "eigen" ? " (dein Preis)" : " (Richtwert)")"
            : "Preis fehlt — in Stammdaten ergänzen"
        return " Material: \(link.text) \(mengeText) · \(preisText) · \(lager)."
    }

    // MARK: - Vorhaltung (Schalung als wiederverwendbares Gerät)

    /// Hängt die Schalungs-Vorhaltung als Geräte-Zeile an: €/m² Schalfläche × Einsätze, pauschal.
    /// Die Schalfläche kommt aus der Positionsmenge über den Umrechner (m lfm → m² über die Höhe,
    /// m³ → m² über die Dicke …). So steht der Hauptkostenblock der Schalung neben dem Lohn.
    /// - Returns: Klartext-Zusatz für die Meldung.
    private static func schreibeVorhaltung(_ link: STLBBaustein.VorhaltungLink?, pos: LVPosition,
                                           posEinheit: String, bruecke: MopsUmrechner.Bruecke,
                                           in ctx: NSManagedObjectContext) -> String {
        guard let link = link, pos.menge > 0, link.proM2 > 0 else { return "" }
        // Schalfläche in m². Ist die Position schon in m², direkt; sonst über die Leiter.
        guard let flaeche = MopsUmrechner.mengeUmrechnen(pos.menge, von: posEinheit, nach: "m2", bruecke: bruecke),
              flaeche > 0 else {
            return " Vorhaltung: Fläche unklar (Höhe/Dicke fehlt) — von Hand."
        }
        let einsaetze = max(1, link.einsaetze)
        schreibeGeraetPauschal(name: link.bezeichnung,
                               anzahl: flaeche, zaehlEinheit: "m²",
                               satzProEinheit: link.proM2 * einsaetze,
                               quelle: "katalog", pos: pos, in: ctx)
        let e = einsaetze == 1 ? "" : " × \(String(format: "%g", einsaetze)) Einsätze"
        return " Vorhaltung: \(link.bezeichnung) \(String(format: "%g", flaeche)) m² × "
             + "\(String(format: "%.2f €", link.proM2))/m²\(e) (Richtwert)."
    }

    /// Die Basis-Einheit hinter einer Maschinen-Leistung (m³/h → „m3" …) — für den Umrechner.
    private static func leistungsBasisEinheit(_ leistungEinheit: String) -> String? {
        switch leistungEinheit {
        case "m³/h": return "m3"
        case "m²/h": return "m2"
        case "m/h":  return "m"
        default:     return nil
        }
    }

    // MARK: - Brückenmaße für den Umrechner (aus Text/Katalog)

    /// Sammelt die Brückenmaße einer Position für den `MopsUmrechner`: Dichte (Schüttgut),
    /// Schichtdicke und Höhe (aus dem Positionstext). Was nicht gefunden wird, bleibt nil —
    /// dann sperrt die Leiter die zugehörige Sprosse, statt grob falsch zu rechnen.
    private static func brueckeFuer(_ pos: LVPosition) -> MopsUmrechner.Bruecke {
        let texte = [pos.bezeichnung, pos.langtext]
        return MopsUmrechner.Bruecke(
            hoeheOderBreite: hoeheMeter(aus: texte),
            dicke: schichtdickeMeter(aus: texte),
            dichteTproM3: DichteKatalog.dichte(fuer: pos.bezeichnung))
    }

    /// Rechnet einen „pro Einheit"-Preis (z. B. BKI-Marktpreis €/m³) in die Einheit der
    /// Position um — über dieselben Brückenmaße wie die Kalkulation (die Leiter). Für einen
    /// fairen EP-Vergleich. nil, wenn nicht überbrückbar (dann in der BKI-Einheit vergleichen).
    static func preisInPositionsEinheit(_ preis: Double, vonEinheit: String, pos: LVPosition) -> Double? {
        let posEinheit = (pos.einheit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let f = MopsUmrechner.proFaktor(von: vonEinheit, nach: posEinheit, bruecke: brueckeFuer(pos)) else {
            return nil
        }
        return preis * f
    }

    /// Schichtdicke in Metern aus einem Positionstext („d= 10cm", „d=0,10 m", „10 cm").
    static func schichtdickeMeter(aus texte: [String?]) -> Double? {
        masszahlMeter(aus: texte, praefix: "d", mitBlankerCm: true)
    }

    /// Höhe/Breite in Metern aus einem Positionstext („h= 0,50 m", „höhe 0,5 m", „h=50cm").
    /// Ohne blanke „<zahl> cm"-Rückfall — eine nackte cm-Angabe ist eher die Dicke.
    static func hoeheMeter(aus texte: [String?]) -> Double? {
        masszahlMeter(aus: texte, praefix: "h", mitBlankerCm: false)
            ?? masszahlMeter(aus: texte, praefix: "höhe", mitBlankerCm: false)
            ?? masszahlMeter(aus: texte, praefix: "hoehe", mitBlankerCm: false)
    }

    /// Ein Maß in Metern aus dem Text: „<präfix>= 0,50 m" / „<präfix> 50cm". Optional ein
    /// Rückfall auf die erste blanke „<zahl> cm"-Angabe (nur für die Dicke sinnvoll).
    private static func masszahlMeter(aus texte: [String?], praefix: String, mitBlankerCm: Bool) -> Double? {
        let text = texte.compactMap { $0 }.joined(separator: " ").lowercased()
        // \b vor dem Präfix: „h" nur als eigenes Wort/Maßkürzel, nicht mitten in „durch 5".
        var muster = [#"\b\#(praefix)\s*=?\s*(?:ca\.?\s*)?([0-9]+(?:[.,][0-9]+)?)\s*(cm|m)\b"#]
        if mitBlankerCm { muster.append(#"([0-9]+(?:[.,][0-9]+)?)\s*(cm)\b"#) }
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

    /// Pauschaler Geräte-Posten: Anzahl × Preis je Zähl-Einheit (Tage-Miete, m²-Vorhaltung …).
    /// `stunden` trägt bei pauschal die ABSOLUTE Anzahl, `kostenProStunde` den Preis je Zähl-Einheit.
    private static func schreibeGeraetPauschal(name: String, anzahl: Double, zaehlEinheit: String,
                                               satzProEinheit: Double, quelle: String,
                                               pos: LVPosition, in ctx: NSManagedObjectContext) {
        let pg = PositionGeraet(context: ctx)
        pg.id = UUID()
        pg.geraetName = name
        pg.pauschal = true
        pg.stunden = anzahl
        pg.kostenProStunde = satzProEinheit
        pg.einheit = zaehlEinheit
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
