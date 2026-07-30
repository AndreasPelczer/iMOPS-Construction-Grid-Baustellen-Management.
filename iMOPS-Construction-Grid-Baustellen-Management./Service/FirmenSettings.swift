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
        // Kalkulations-Zuschlaege — Firmenwerte, gelten fuer jede Position, die
        // nicht ausdruecklich abweicht (LVPosition.zuschlagEigen).
        static let zuschlagJeKostenart = "firma_zuschlag_je_kostenart"
        static let zuschlagLohn        = "firma_zuschlag_lohn"
        static let zuschlagMaterial    = "firma_zuschlag_material"
        static let zuschlagGeraet      = "firma_zuschlag_geraet"
        static let bgk                 = "firma_bgk"
        static let wagnisGewinn        = "firma_wagnis_gewinn"
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

    // MARK: - Kalkulations-Zuschlaege (Firmenwerte)
    //
    // Die Vorgaben sind absichtlich identisch mit den bisherigen Core-Data-Defaults
    // (BGK 12 %, W&G 8 %, je Kostenart 20 %). Solange hier niemand etwas aendert,
    // rechnet jede bestehende Position also auf die Kommastelle genau wie vorher.
    // Wer die Firmenwerte anfasst, aendert damit bewusst ALLE Positionen, die nicht
    // ausdruecklich abweichen — genau dafuer sind sie da.

    /// Rechnet die Firma mit getrennten Saetzen je Kostenart?
    static var zuschlagJeKostenart: Bool {
        UserDefaults.standard.bool(forKey: Keys.zuschlagJeKostenart)
    }

    static var zuschlagLohn:     Double { satz(Keys.zuschlagLohn,     vorgabe: 0.20) }
    static var zuschlagMaterial: Double { satz(Keys.zuschlagMaterial, vorgabe: 0.20) }
    static var zuschlagGeraet:   Double { satz(Keys.zuschlagGeraet,   vorgabe: 0.20) }
    static var bgk:              Double { satz(Keys.bgk,              vorgabe: 0.12) }
    static var wagnisGewinn:     Double { satz(Keys.wagnisGewinn,     vorgabe: 0.08) }

    /// Ein Zuschlagssatz aus den UserDefaults.
    ///
    /// Bewusst ueber `object(forKey:) == nil` statt ueber „Wert == 0": ein Satz von
    /// 0 % ist eine legitime Einstellung (bei Material durchaus ueblich) und darf
    /// nicht als „nie gesetzt" durchrutschen. Verhaelt sich damit genau wie
    /// `@AppStorage` in den Einstellungen, das denselben Schluessel schreibt.
    private static func satz(_ key: String, vorgabe: Double) -> Double {
        guard UserDefaults.standard.object(forKey: key) != nil else { return vorgabe }
        return UserDefaults.standard.double(forKey: key)
    }
}
