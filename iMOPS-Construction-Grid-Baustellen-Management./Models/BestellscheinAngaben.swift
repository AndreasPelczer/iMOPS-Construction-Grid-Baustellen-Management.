import Foundation

/// Die Angaben, die auf dem T&C-Bestellschein anzukreuzen sind und **nicht** aus
/// der Baustelle kommen können.
///
/// Lieferart, Kran und Zeitfenster sind Entscheidungen je Bestellung, keine
/// Stammdaten — sie müssen vor jedem Versand gesetzt werden. Was aus der Baustelle
/// bekannt ist (Bauvorhaben, Nummer, Ort, Bauherr), füllt die App selbst.
struct BestellscheinAngaben: Equatable {

    enum Lieferart: String, CaseIterable, Identifiable {
        case zufuhr = "Zufuhr"
        case mitnahmestapler = "Mitnahmestapler"
        case abholung = "Abholung"
        var id: String { rawValue }
    }

    enum Zeitfenster: String, CaseIterable, Identifiable {
        case frueh = "früh (7–9 Uhr)"
        case mittags = "mittags (bis 12 Uhr)"
        case nachmittags = "nachmittags (bis 17 Uhr)"
        case egal = "im Laufe des Tages"
        var id: String { rawValue }
    }

    var lieferart: Lieferart = .zufuhr
    var mitKran: Bool = true
    var zeitfenster: Zeitfenster = .frueh
    var wunschtermin: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()

    /// Vergibt Xella, steht in keiner unserer Quellen.
    var objektNr: String = ""
    /// Straße der Baustelle — die Baustelle kennt nur den Ort.
    var strasse: String = ""
    var plzOrt: String = ""
    var baustoffhandel: String = ""
    var bemerkung: String = ""

    /// Der Schein schreibt drei Werktage Vorlauf vor.
    static let vorlaufWerktage = 3

    /// Liegt der Wunschtermin näher als der Vorlauf? Dann warnen, nicht blockieren —
    /// vielleicht ist es abgesprochen.
    var vorlaufKnapp: Bool {
        let tage = Calendar.current.dateComponents([.day], from: Date(), to: wunschtermin).day ?? 0
        return tage < Self.vorlaufWerktage
    }
}
