//
//  RuleViolation.swift
//  iMOPS-Construction-Grid-Baustellen-Management
//
//  Portiert aus iMOPS-Gastro-Grid/Kernel/RuleViolation.swift.
//  Kein "silent fail" ohne nachvollziehbaren Grund.
//  Validierungsfunktionen liefern Result<Void, RuleViolation> statt Bool.
//
//  Regel-ID Format:
//    BAU-Rxx   — allgemeine Auftrag-/Datenregeln
//    BAU-W-xx  — Wetter-Stopps (abgeleitet aus BauWetterRegeln)
//    BAU-SHE-xx — Sicherheit / Arbeitsschutz (ArbSchG, DGUV)
//    BAU-DIN-xx — DIN 276 / VOB Konformität
//

import Foundation

// MARK: - RuleViolation

/// Ein strukturierter Validierungsfehler mit nachverfolgbarer Regel-ID.
struct RuleViolation: Error {
    let ruleId: String          // z.B. "BAU-R01", "BAU-W-02"
    let reason: String          // Max. 120 Zeichen, lesbar
    let fields: [String]?       // Betroffene Felder (optional)

    init(ruleId: String, reason: String, fields: [String]? = nil) {
        self.ruleId = ruleId
        self.reason = String(reason.prefix(120))
        self.fields = fields
    }
}

// MARK: - Validation Result

typealias ValidationResult = Result<Void, RuleViolation>

// MARK: - BauValidator

/// Validiert Bau-Operationen vor der Ausführung.
/// Liefert RuleViolation mit ruleId + reason statt stummem Bool.
struct BauValidator {

    // MARK: - Auftrag-Validierung

    /// Auftrag-Basisdaten prüfen vor dem Anlegen.
    static func validateAuftrag(id: String, titel: String, baustelle: String) -> ValidationResult {
        guard !id.isEmpty else {
            return .failure(RuleViolation(
                ruleId: "BAU-R01",
                reason: "Auftrags-ID darf nicht leer sein",
                fields: ["id"]
            ))
        }
        guard !titel.isEmpty else {
            return .failure(RuleViolation(
                ruleId: "BAU-R01",
                reason: "Auftrags-Titel darf nicht leer sein",
                fields: ["titel"]
            ))
        }
        guard !baustelle.isEmpty else {
            return .failure(RuleViolation(
                ruleId: "BAU-R01",
                reason: "Auftrag muss einer Baustelle zugeordnet sein",
                fields: ["baustelle"]
            ))
        }
        return .success(())
    }

    /// Prüft ob ein Auftrag abgeschlossen werden darf.
    static func validateAuftragAbschluss(id: String, status: String, offeneMaengel: Int) -> ValidationResult {
        guard status == "OFFEN" || status == "IN_ARBEIT" else {
            return .failure(RuleViolation(
                ruleId: "BAU-R02",
                reason: "Auftrag \(id) hat ungültigen Status für Abschluss: \(status)",
                fields: ["status"]
            ))
        }
        guard offeneMaengel == 0 else {
            return .failure(RuleViolation(
                ruleId: "BAU-R02",
                reason: "Auftrag \(id) hat \(offeneMaengel) offene Mängel — Abschluss blockiert",
                fields: ["maengel"]
            ))
        }
        return .success(())
    }

    // MARK: - Mangel-Validierung

    /// Mangel-Eintrag vor dem Speichern prüfen.
    static func validateMangel(titel: String, kgNummer: String) -> ValidationResult {
        guard !titel.isEmpty else {
            return .failure(RuleViolation(
                ruleId: "BAU-R03",
                reason: "Mangel muss einen Titel haben",
                fields: ["titel"]
            ))
        }
        guard !kgNummer.isEmpty else {
            return .failure(RuleViolation(
                ruleId: "BAU-DIN-01",
                reason: "Mangel muss einer DIN-276-Kostengruppe zugeordnet sein",
                fields: ["kgNummer"]
            ))
        }
        return .success(())
    }

    // MARK: - Wetter-Validierung (abgeleitet aus BauWetterRegeln)

    /// Prüft ob Außenbetonage bei aktueller Temperatur erlaubt ist (DIN 1045).
    static func validateBetonage(temperatur: Double) -> ValidationResult {
        guard temperatur > 0 else {
            return .failure(RuleViolation(
                ruleId: "BAU-W-01",
                reason: "Frost (\(String(format: "%.1f", temperatur))°C): Betonieren verboten. DIN 1045/VOB Teil C.",
                fields: ["temperatur"]
            ))
        }
        guard temperatur < 35 else {
            return .failure(RuleViolation(
                ruleId: "BAU-W-02",
                reason: "Hitze (\(String(format: "%.1f", temperatur))°C): Pflichtpausen. ArbSchG §3.",
                fields: ["temperatur"]
            ))
        }
        return .success(())
    }

    /// Prüft ob Kran-/Gerüstarbeiten bei aktuellem Wind erlaubt sind (DGUV 201-056).
    static func validateWindsicherheit(windGeschwindigkeit: Double) -> ValidationResult {
        guard windGeschwindigkeit < 17.2 else {
            return .failure(RuleViolation(
                ruleId: "BAU-SHE-01",
                reason: "Sturm (\(String(format: "%.1f", windGeschwindigkeit)) m/s): Kran- und Gerüstarbeiten sofort einstellen. DGUV 201-056.",
                fields: ["windGeschwindigkeit"]
            ))
        }
        guard windGeschwindigkeit < 10.8 else {
            return .failure(RuleViolation(
                ruleId: "BAU-SHE-01",
                reason: "Starker Wind (\(String(format: "%.1f", windGeschwindigkeit)) m/s): Kranführer informieren, freistehende Elemente sichern.",
                fields: ["windGeschwindigkeit"]
            ))
        }
        return .success(())
    }

    // MARK: - DIN 276 Validierung

    /// Prüft ob eine KG-Nummer dem DIN-276-Format entspricht (3 Stellen, 100–799).
    static func validateKostengruppe(_ kg: String) -> ValidationResult {
        let pattern = #"^[1-7]\d{2}$"#
        guard kg.range(of: pattern, options: .regularExpression) != nil else {
            return .failure(RuleViolation(
                ruleId: "BAU-DIN-01",
                reason: "Ungültige Kostengruppe '\(kg)' — muss 3-stellig nach DIN 276 sein (100–799)",
                fields: ["kostengruppe"]
            ))
        }
        return .success(())
    }

    // MARK: - Regel-ID Format-Check

    /// Prüft dass eine ruleId dem erwarteten Format entspricht.
    static func isValidRuleIdFormat(_ ruleId: String) -> Bool {
        let pattern = #"^BAU-(R\d{2}|W-\d{2}|SHE-\d{2}|DIN-\d{2})$"#
        return ruleId.range(of: pattern, options: .regularExpression) != nil
    }
}
