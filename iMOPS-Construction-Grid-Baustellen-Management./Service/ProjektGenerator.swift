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
}

// MARK: - Hofeinfahrt (erste firm-typische Kleinvorlage)

enum HofeinfahrtVorlage {

    /// Baut Massen, Material, Kosten und einen kleinen Bauphasen-Plan aus der
    /// Pflasterfläche (m²). Titel folgen Goldschmitts echten Angeboten
    /// (Baustelleneinrichtung · Erdarbeiten · Unterbau · Randeinfassung · Pflaster).
    static func generiere(flaeche: Double) -> HouseProjectResult {
        let f = max(flaeche, 1)
        let randlaenge = (4 * f.squareRoot()).rounded()   // Umfang eines quadratischen Feldes
        let mutterbodenM3 = (f * 0.30).rounded()          // ~30 cm abtragen
        let aushubM3 = (f * 0.35).rounded()               // Planum für Unterbau
        let schotterM3 = (f * 0.12).rounded()             // ~10 cm Tragschicht + Verdichtung

        let massen: [MassenPosition] = [
            MassenPosition(bezeichnung: "Baustelleneinrichtung (An-/Abfuhr, Bauzaun)",
                           menge: 1, einheit: "Pau", gewerk: "Baustelleneinrichtung",
                           details: "Vorhaltung Werkzeug/Maschinen"),
            MassenPosition(bezeichnung: "Mutterboden abtragen und lagern",
                           menge: mutterbodenM3, einheit: "m³", gewerk: "Erdarbeiten"),
            MassenPosition(bezeichnung: "Aushub Planum herstellen",
                           menge: aushubM3, einheit: "m³", gewerk: "Erdarbeiten"),
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
            MaterialPosition(titel: "Pflastersplitt 0/5", menge: (f * 0.05).rounded(), einheit: "m³",
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
                     dauerWochen: 1, startWoche: 1, beschreibung: "Mutterboden, Aushub, Schottertragschicht"),
            Bauphase(name: "Randeinfassung setzen", gewerk: "Randeinfassung",
                     dauerWochen: 1, startWoche: 2, beschreibung: "Tiefbord in Beton"),
            Bauphase(name: "Pflastern & abrütteln", gewerk: "Pflaster",
                     dauerWochen: 1, startWoche: 3, beschreibung: "Verlegen, verfugen, abrütteln"),
        ]

        var project = HouseProject()
        project.projektName = "Hofeinfahrt pflastern"

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
