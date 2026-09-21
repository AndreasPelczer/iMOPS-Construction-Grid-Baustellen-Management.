//
//  Uebergehung.swift
//
//  „Wer ein Nein übergeht, unterschreibt."
//
//  Der Mops sagt: der Estrich muss noch trocknen. Der Polier steht davor und sagt: ist
//  trocken. Er hat wahrscheinlich recht — er misst, er fasst an, er macht das seit
//  zwanzig Jahren. Sperrt man ihn einfach, macht er es trotzdem, nur eben OHNE den
//  Mops. Dann weiß in zehn Jahren niemand mehr, dass überhaupt jemand entschieden hat.
//
//  Also: er darf weiter. Aber er schreibt einen Satz.
//
//  🔴 Der Satz ist der eigentliche Knopf. Ein Häkchen ist zu billig, ein Formular zu
//  teuer — dann geht man drumherum. Ein Satz kostet fünf Sekunden Nachdenken und ist in
//  zehn Jahren das Einzige, was ein Gutachter lesen will. Er ist kein Geständnis: er ist
//  ein Nachweis, und er schützt den, der ihn geschrieben hat.
//
//  Die Übernahme gehört zum BAUTEIL, nicht zum Menschen — sie hängt am Auftrag und
//  wandert mit ihm, nicht am Mitarbeiter. Nicht „Paolo hat übergangen", sondern: dieser
//  Auftrag wurde am 14.03. um 14:20 gegen eine offene Voraussetzung freigegeben.
//
//  Vorher (21.09.2026 gemessen): `Auftrag.istStartbar` hatte 26 Zusicherungen in den
//  Tests und NULL Aufrufer. Der einzige Weg an einer Voraussetzung vorbei war, sie zu
//  LÖSCHEN — spurlos, ohne Grund, ohne Namen. Das genaue Gegenteil hiervon.
//

import Foundation

/// Eine bewusst übergangene Voraussetzung. Optional im Payload → alte Blobs bleiben
/// lesbar (die Codable-Falle, siehe `lagersystem-und-codable-falle`).
struct Uebergehung: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString

    /// Worauf der Auftrag gewartet hätte — der Name der Voraussetzung bzw. des
    /// Vorgängers. Als Text festgehalten, nicht als Verweis: die Kante darf später
    /// gelöst werden, der Nachweis muss bleiben.
    var woraufGewartet: String

    /// Der Satz. Ohne ihn gibt es keine Übernahme.
    var begruendung: String

    /// Wer die Verantwortung übernommen hat, und wann.
    /// 🔴 Heute die Rolle aus `AppSession`, nicht der Mensch — so gut wie die Anmeldung.
    var von: String
    var am: Date

    /// Wie weit die Kette zum Zeitpunkt der Übernahme offen war (Beleg gegen späteres
    /// „das war doch nur eine Kleinigkeit").
    var offeneVoraussetzungenGesamt: Int
}

extension Uebergehung {
    /// Eine Zeile für Berichte und PDF — bewusst ohne Wertung formuliert.
    var protokollzeile: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM.yyyy HH:mm"
        return "\(f.string(from: am)) · \(woraufGewartet) übergangen, verantwortet von \(von) · \(begruendung)"
    }
}
