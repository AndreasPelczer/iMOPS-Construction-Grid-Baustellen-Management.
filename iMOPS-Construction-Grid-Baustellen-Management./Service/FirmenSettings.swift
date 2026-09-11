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
        // Briefpapier — was auf jedem Dokument steht, das das Haus verlaesst.
        static let steuernummer     = "firma_steuernummer"
        static let iban             = "firma_iban"
        static let bic              = "firma_bic"
        static let bank             = "firma_bank"
        static let iban2            = "firma_iban2"
        static let bic2             = "firma_bic2"
        static let bank2            = "firma_bank2"
        static let handelsregister  = "firma_handelsregister"
        static let geschaeftsfuehrer = "firma_geschaeftsfuehrer"
        static let telefon          = "firma_telefon"
        static let fax              = "firma_fax"
        static let email            = "firma_email"
        static let web              = "firma_web"
        static let rechtstextFuss   = "firma_rechtstext_fuss"
        static let zahlungszielTage = "firma_zahlungsziel_tage"
        /// Dateiname des Logos im App-Support — **nicht** die Bilddaten selbst.
        static let logoDatei        = "firma_logo_datei"
        // Kalkulations-Zuschlaege — Firmenwerte, gelten fuer jede Position, die
        // nicht ausdruecklich abweicht (LVPosition.zuschlagEigen).
        static let zuschlagJeKostenart = "firma_zuschlag_je_kostenart"
        static let zuschlagLohn        = "firma_zuschlag_lohn"
        static let zuschlagMaterial    = "firma_zuschlag_material"
        static let zuschlagGeraet      = "firma_zuschlag_geraet"
        static let bgk                 = "firma_bgk"
        static let wagnisGewinn        = "firma_wagnis_gewinn"
        // Kennwerte je m² Wohnflaeche fuer die Grobkostenschaetzung im Planer.
        static let kennwertEinfach     = "firma_kennwert_einfach"
        static let kennwertMittel      = "firma_kennwert_mittel"
        static let kennwertGehoben     = "firma_kennwert_gehoben"
    }

    // ⚠️ **Kein Default-Firmenname mehr.** Hier stand „iMOPS Bauleitung" — der Name
    // der Software auf der Rechnung eines Bauunternehmens. Wer nichts eintraegt,
    // bekommt jetzt nichts: ein leerer Briefkopf faellt auf, ein falscher nicht.
    static var name:    String { UserDefaults.standard.string(forKey: Keys.name)    ?? "" }
    static var strasse: String { UserDefaults.standard.string(forKey: Keys.strasse) ?? "" }
    static var plz:     String { UserDefaults.standard.string(forKey: Keys.plz)     ?? "" }
    static var ort:     String { UserDefaults.standard.string(forKey: Keys.ort)     ?? "" }
    static var ustIdNr: String { UserDefaults.standard.string(forKey: Keys.ustIdNr) ?? "" }
    // Default 19 %; stored as Double
    static var mwstSatz: Double {
        let v = UserDefaults.standard.double(forKey: Keys.mwstSatz)
        return v == 0 ? 19.0 : v
    }
    // MARK: - Briefpapier
    //
    // Alles leer voreingestellt und optional. Der Grundsatz fuer jedes Dokument:
    // **eine fehlende Angabe wird weggelassen, nie als Platzhalter gedruckt.**
    // „[fehlt]" auf einem Kundendokument ist schlimmer als eine Zeile weniger.

    static var steuernummer:      String { txt(Keys.steuernummer) }
    static var iban:              String { txt(Keys.iban) }
    static var bic:               String { txt(Keys.bic) }
    static var bank:              String { txt(Keys.bank) }
    static var iban2:             String { txt(Keys.iban2) }
    static var bic2:              String { txt(Keys.bic2) }
    static var bank2:             String { txt(Keys.bank2) }
    static var handelsregister:   String { txt(Keys.handelsregister) }
    static var geschaeftsfuehrer: String { txt(Keys.geschaeftsfuehrer) }
    static var telefon:           String { txt(Keys.telefon) }
    static var fax:               String { txt(Keys.fax) }
    static var email:             String { txt(Keys.email) }
    static var web:               String { txt(Keys.web) }
    static var rechtstextFuss:    String { txt(Keys.rechtstextFuss) }

    /// Zahlungsziel in Tagen. 0 = keine Angabe → im Dokument steht dann nichts.
    static var zahlungszielTage: Int {
        UserDefaults.standard.integer(forKey: Keys.zahlungszielTage)
    }

    private static func txt(_ key: String) -> String {
        (UserDefaults.standard.string(forKey: key) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Anschrift der Firma als Block, leere Zeilen fallen weg.
    static var anschrift: [String] {
        [name, strasse, [plz, ort].filter { !$0.isEmpty }.joined(separator: " ")]
            .filter { !$0.isEmpty }
    }

    /// Steht genug da, damit ein Dokument aus dem Haus darf?
    /// **Keine Rechtsberatung** — nur die Felder, die § 14 UStG ausdruecklich nennt.
    /// Die Werte selbst kann kein Programm pruefen; das geht nur gegen die
    /// Firmenpapiere.
    static var briefkopfIstVollstaendig: Bool {
        !name.isEmpty && !strasse.isEmpty && !ort.isEmpty
            && !(ustIdNr.isEmpty && steuernummer.isEmpty)   // eines von beiden reicht
    }

    // MARK: - Logo
    //
    // **Die Datei liegt im App-Support, in den UserDefaults steht nur ihr Name.**
    // UserDefaults wird bei jedem Start vollstaendig in den Speicher gelesen — ein
    // PNG gehoert da nicht hinein. Apple nennt als Richtwert wenige Kilobyte.

    static var logoOrdner: URL {
        let fm = FileManager.default
        let ordner = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                  appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        return ordner
    }

    static var logoURL: URL? {
        let datei = txt(Keys.logoDatei)
        guard !datei.isEmpty else { return nil }
        let url = logoOrdner.appendingPathComponent(datei)
        // Die Datei kann fehlen, obwohl der Name gesetzt ist (Geraetewechsel,
        // geloeschte Daten). Dann lieber kein Logo als ein leerer Kasten.
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static var logoDaten: Data? { logoURL.flatMap { try? Data(contentsOf: $0) } }

    /// Legt das Logo ab und merkt sich den Dateinamen. `nil` entfernt es.
    @discardableResult
    static func setzeLogo(_ daten: Data?, endung: String = "png") -> Bool {
        let fm = FileManager.default
        if let alt = logoURL { try? fm.removeItem(at: alt) }
        guard let daten else {
            UserDefaults.standard.removeObject(forKey: Keys.logoDatei)
            return true
        }
        let name = "firmenlogo.\(endung)"
        do {
            try daten.write(to: logoOrdner.appendingPathComponent(name), options: .atomic)
            UserDefaults.standard.set(name, forKey: Keys.logoDatei)
            return true
        } catch {
            return false
        }
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

    // MARK: - Kennwerte je m² Wohnflaeche (Grobkostenschaetzung)
    //
    // ⚠️ Das sind EURE Erfahrungswerte, KEINE lizenzierten BKI-Daten. Echte
    // BKI-Kennwerte kommen vom Baukosteninformationszentrum und sind kostenpflichtig;
    // sie duerfen hier nicht eincodiert werden. Darum heisst es in der App „Kennwert"
    // und nicht „BKI" — die App soll keine Quelle behaupten, die sie nicht hat.
    //
    // Vorgaben entsprechen den Werten, die vorher in `HouseProject.Ausstattung` hart
    // im Code standen (2000/2500/3200). Solange sie niemand aendert, rechnet der
    // Planer exakt wie vorher.

    static var kennwertEinfach: Double { kennwert(Keys.kennwertEinfach, vorgabe: 2000) }
    static var kennwertMittel:  Double { kennwert(Keys.kennwertMittel,  vorgabe: 2500) }
    static var kennwertGehoben: Double { kennwert(Keys.kennwertGehoben, vorgabe: 3200) }

    /// Ein Kennwert aus den UserDefaults.
    ///
    /// Anders als bei den Zuschlaegen ist 0 hier KEINE sinnvolle Einstellung — ein Haus
    /// fuer 0 €/m² gibt es nicht. Ein versehentlich geleertes Feld faellt darum auf die
    /// Vorgabe zurueck, statt die ganze Schaetzung auf 0 zu ziehen.
    private static func kennwert(_ key: String, vorgabe: Double) -> Double {
        let v = UserDefaults.standard.double(forKey: key)
        return v > 0 ? v : vorgabe
    }
}
