//
//  ProjektGenerator.swift
//  Ein Dach über den Generatoren: gibt einen `HouseProjectResult` zurück — egal ob
//  Haus oder kleine Vorlage. Dadurch laufen die vier Reiter (Kosten · Material · Massen ·
//  Zeitplan) und der Bauphasen-Plan UNVERÄNDERT für beide; nur der Inhalt skaliert
//  (Haus = viele Positionen, Hofeinfahrt = wenige).
//
//  Kein Umbau am Haus: für Haus-Typen wird schlicht der bestehende `HouseProjectGenerator`
//  gerufen. Die kleine Vorlage kommt DANEBEN.
//
//  Bewusst NICHT hier (nächste Bögen, damit sie später leicht andocken):
//   - die Vorlage als Bündel echter `Leistungsbaustein` (Katalog-Integration),
//   - Auto-Menge (Maß-Herkunft je Leistung: Fläche→m², Umfang→lfm),
//   - wachsende Vorlagen (aus echten Baustellen geerntet).
//  Die Zahlen unten sind Richtwerte aus Goldschmitts Titeln — Schätzung, kein Aufmaß.

import Foundation

enum ProjektGenerator {

    /// Erzeugt das Ergebnis für einen Projekt-Typ.
    /// - Haus-Typen: der vorhandene `HouseProjectGenerator` (Logik unverändert).
    /// - Hofeinfahrt: die kleine Vorlage, aus der Pflasterfläche skaliert.
    static func generate(typ: ProjektTyp, haus: HouseProject, flaeche: Double) -> HouseProjectResult {
        if let hausTyp = typ.hausTyp {
            var p = haus
            p.haustyp = hausTyp
            p.projektTyp = typ.rawValue
            return HouseProjectGenerator.generate(from: p)
        }
        switch typ {
        case .hofeinfahrt:
            return HofeinfahrtVorlage.generiere(flaeche: max(flaeche, 0))
        default:
            // Kann bei korrektem `istHaus` nicht eintreten; defensiv das Haus nehmen.
            return HouseProjectGenerator.generate(from: haus)
        }
    }

    /// Welcher Typ eine GESPEICHERTE Planung ist. Altbestand (vor 10.10.2026) hat kein
    /// `projektTyp` – die Hofeinfahrt-Vorlage setzt aber immer den Namen „Hofeinfahrt pflastern“.
    static func typ(von p: HouseProject) -> ProjektTyp {
        if let t = p.projektTyp.flatMap(ProjektTyp.init(rawValue:)) { return t }
        if p.projektName == HofeinfahrtVorlage.projektName { return .hofeinfahrt }
        return ProjektTyp.allCases.first { $0.hausTyp == p.haustyp } ?? .einfamilienhaus
    }

    /// Eine gespeicherte Planung neu rechnen – mit dem Rechner IHRES Typs. Die EINE Stelle dafür
    /// (Grundplanung, Planer beim Öffnen, Kennwert-Vergleich).
    static func neuBerechnen(_ p: HouseProject) -> HouseProjectResult {
        switch typ(von: p) {
        case .hofeinfahrt:
            return HofeinfahrtVorlage.generiere(flaeche: p.wohnflaeche)
        case let t:
            return generate(typ: t, haus: p, flaeche: p.wohnflaeche)
        }
    }
}

// MARK: - Hofeinfahrt (erste firm-typische Kleinvorlage)

enum HofeinfahrtVorlage {

    /// Der Name, den die Vorlage ihrer Planung gibt – auch das Erkennungszeichen für Altbestand.
    static let projektName = "Hofeinfahrt pflastern"

    /// Die Pflasterfläche, die der Planer annimmt, wenn keiner eine nennt. EINE Stelle –
    /// der Planer und die Jarvis-Schrittliste zeigen dieselbe Zahl.
    static let standardFlaeche: Double = 100

    /// Baut Massen, Material, Kosten und einen kleinen Bauphasen-Plan aus der
    /// Pflasterfläche (m²). Titel folgen Goldschmitts echten Angeboten
    /// (Baustelleneinrichtung · Erdarbeiten · Unterbau · Randeinfassung · Pflaster).
    /// Der Aufbau von oben nach unten (m). EINE Stelle: daraus folgen Aushub UND Material.
    /// 🔴 Die Schotterdicke ist offen – 12 cm wirken für eine befahrene Einfahrt dünn (üblich
    /// eher 20–30 cm), der Mops hat dazu keine Quelle. Raphi entscheidet (11.10.2026).
    static let pflasterDicke = 0.08
    static let bettungDicke = 0.05      // Pflastersplitt
    static let schotterDicke = 0.12
    static let mutterbodenDicke = 0.30
    /// Mutterboden trägt nicht – er muss GANZ raus, auch wenn er tiefer reicht als der Aufbau.
    /// Dann wird mit Schotter aufgefüllt: die Schotterlage ist mindestens so dick wie nötig.
    static var schotterEinbau: Double { max(schotterDicke, mutterbodenDicke - pflasterDicke - bettungDicke) }
    static var aufbauTiefe: Double { pflasterDicke + bettungDicke + schotterEinbau }

    static func generiere(flaeche: Double) -> HouseProjectResult {
        let f = max(flaeche, 1)
        let randlaenge = (4 * f.squareRoot()).rounded()   // Umfang eines quadratischen Feldes
        // Ausgehoben wird genau so tief, wie wieder eingebaut wird (Befund 11.10.2026: vorher
        // 30 cm Mutterboden + 35 cm Aushub = 65 cm raus, nur ~25 cm Aufbau rein → 40 cm Loch).
        // Der Mutterboden kommt ganz raus; nur was der Aufbau darunter noch braucht, ist Aushub.
        let mutterbodenM3 = (f * mutterbodenDicke).rounded()
        let aushubM3 = (f * max(aufbauTiefe - mutterbodenDicke, 0)).rounded()
        let schotterM3 = (f * schotterEinbau).rounded()

        let massen: [MassenPosition] = [
            MassenPosition(bezeichnung: "Baustelleneinrichtung (An-/Abfuhr, Bauzaun)",
                           menge: 1, einheit: "Pau", gewerk: "Baustelleneinrichtung",
                           details: "Vorhaltung Werkzeug/Maschinen"),
            MassenPosition(bezeichnung: "Mutterboden abtragen und lagern",
                           menge: mutterbodenM3, einheit: "m³", gewerk: "Erdarbeiten"),
        ] + (aushubM3 > 0 ? [
            MassenPosition(bezeichnung: "Aushub bis Planum (unter dem Mutterboden)",
                           menge: aushubM3, einheit: "m³", gewerk: "Erdarbeiten"),
        ] : []) + [
            MassenPosition(bezeichnung: "Schottertragschicht 0/32 liefern, einbauen, verdichten",
                           menge: f, einheit: "m²", gewerk: "Unterbau"),
            MassenPosition(bezeichnung: "Randeinfassung (Tiefbord in Beton)",
                           menge: randlaenge, einheit: "lfm", gewerk: "Randeinfassung"),
            MassenPosition(bezeichnung: "Betonpflaster verlegen, abrütteln, abfegen",
                           menge: f, einheit: "m²", gewerk: "Pflaster"),
        ]

        let materialien: [MaterialPosition] = [
            MaterialPosition(titel: "Schotter 0/32", menge: schotterM3, einheit: "m³",
                             einzelpreis: 28, gewerk: "Unterbau"),
            MaterialPosition(titel: "Betonpflaster", menge: (f * 1.05).rounded(), einheit: "m²",
                             einzelpreis: 22, gewerk: "Pflaster", notiz: "inkl. Verschnitt"),
            MaterialPosition(titel: "Pflastersplitt 0/5", menge: (f * bettungDicke).rounded(), einheit: "m³",
                             einzelpreis: 45, gewerk: "Pflaster"),
            MaterialPosition(titel: "Tiefbord Betonstein", menge: randlaenge, einheit: "lfm",
                             einzelpreis: 9, gewerk: "Randeinfassung"),
        ]

        // Kleine Baustelle: alles unter Außenanlagen, keine Baunebenkosten (kein Architekt).
        var kosten = Kostenaufstellung()
        kosten.aussenanlagen = (f * 95).rounded()   // Richtwert €/m² inkl. Unterbau/Rand
        let nebenkosten: [Nebenkostenposition] = []

        let phasen: [Bauphase] = [
            Bauphase(name: "Baustelle einrichten", gewerk: "Baustelleneinrichtung",
                     dauerWochen: 1, startWoche: 0, beschreibung: "Bauzaun, Anfuhr Gerät"),
            Bauphase(name: "Erdarbeiten & Unterbau", gewerk: "Erdarbeiten",
                     dauerWochen: 1, startWoche: 1, beschreibung: "Mutterboden abtragen, Planum, Schottertragschicht"),
            Bauphase(name: "Randeinfassung setzen", gewerk: "Randeinfassung",
                     dauerWochen: 1, startWoche: 2, beschreibung: "Tiefbord in Beton"),
            Bauphase(name: "Pflastern & abrütteln", gewerk: "Pflaster",
                     dauerWochen: 1, startWoche: 3, beschreibung: "Verlegen, verfugen, abrütteln"),
        ]

        var project = HouseProject()
        project.projektName = projektName
        project.projektTyp = ProjektTyp.hofeinfahrt.rawValue
        // Die „Fläche" der Hofeinfahrt ist die Pflasterfläche (kein Wohnhaus). Ohne das
        // bliebe `wohnflaeche = 0` → Header „0 m²" und EUR/m² = Kosten ÷ 0 (NaN). Die
        // vier Reiter teilen sich das Feld mit dem Haus-Weg, darum hier belegen.
        project.wohnflaeche = f

        return HouseProjectResult(
            project: project,
            massen: massen,
            materialien: materialien,
            baukosten: kosten,
            baunebenkosten: nebenkosten,
            phasen: phasen
        )
    }
}
