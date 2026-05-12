import Foundation

// Centralised access to firm-level UserDefaults used across XRechnung, PDF exports, etc.
enum FirmenSettings {
    enum Keys {
        static let name     = "firma_name"
        static let strasse  = "firma_strasse"
        static let plz      = "firma_plz"
        static let ort      = "firma_ort"
        static let ustIdNr  = "firma_ust_id_nr"
        static let mwstSatz = "firma_mwst_satz"
    }

    static var name:    String { UserDefaults.standard.string(forKey: Keys.name)    ?? "iMOPS Bauleitung" }
    static var strasse: String { UserDefaults.standard.string(forKey: Keys.strasse) ?? "" }
    static var plz:     String { UserDefaults.standard.string(forKey: Keys.plz)     ?? "" }
    static var ort:     String { UserDefaults.standard.string(forKey: Keys.ort)     ?? "" }
    static var ustIdNr: String { UserDefaults.standard.string(forKey: Keys.ustIdNr) ?? "" }
    // Default 19 %; stored as Double
    static var mwstSatz: Double {
        let v = UserDefaults.standard.double(forKey: Keys.mwstSatz)
        return v == 0 ? 19.0 : v
    }
    // EN 16931 VAT category code
    static var vatCategory: String { mwstSatz == 0 ? "Z" : "S" }
}
