import Foundation

extension LVPosition {
    /// Beschreibt, was beim Löschen dieser Position MITGELÖSCHT wird (Aufmaße,
    /// Kalkulations-Posten = Material/Lohn/Geräte, die per Cascade hängen).
    /// `nil`, wenn die Position leer ist → dann reicht ein knapper Dialog.
    /// Buch Kap 9: benennen, was verloren geht — nicht stillschweigend wegräumen.
    var loeschFolgen: String? {
        var teile: [String] = []
        if hatAufmass {
            let n = aufmassArray.count
            let summe = istMengeSumme.formatted(.number.precision(.fractionLength(0...2)))
            teile.append("\(n) Aufmaß-\(n == 1 ? "Eintrag" : "Einträge") (insgesamt \(summe) \(einheit ?? ""))")
        }
        let kalk = materialArray.count + lohnArray.count + geraeteArray.count
        if kalk > 0 {
            teile.append("\(kalk) Kalkulations-Posten")
        }
        return teile.isEmpty ? nil : teile.joined(separator: " und ")
    }
}
