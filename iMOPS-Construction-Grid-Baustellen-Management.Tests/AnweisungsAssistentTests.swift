//
//  AnweisungsAssistentTests.swift
//
//  Der wichtigste Test ist `werteWerdenErkannt`. Andreas hat am 21.09. die Trennlinie
//  gezogen, die dieses ganze Stück trägt:
//
//    Reihenfolge und Logik kann er abnehmen — Schalung vor Beton, Bewehrung vor dem
//    Verschließen. Das erkennt man mit Verstand.
//    ZAHLEN nicht. „95 % Ev2", „Fugenbreite 3–5 mm", „nach 28 Tagen" sehen IMMER
//    plausibel aus. Genau dort lag der Wurm in den 91 erfundenen Schritten.
//
//  Wenn diese Erkennung danebenliegt, wandert ein Normwert ungeprüft auf den
//  Bildschirm eines Lehrlings. Deshalb steht sie hier mit echten Beispielen aus der
//  vorhandenen Vorlagen-Datei.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct AnweisungsAssistentTests {

    /// 🔴 Echte Zeilen aus `AuftragTemplate.swift` — die mit Wert müssen rot werden.
    @Test func werteWerdenErkannt() {
        let mitWert = [
            "Verdichten bis 95 % (Ev2 / Plattendruck pruefen)",
            "Fugenbreite 3-5 mm einhalten",
            "Abdichtung nach DIN 18533 aufbringen",
            "Aushaertezeit 28 Tage einhalten",
            "Kerntemperatur 75 °C halten",
            "Mineralgemisch 0/32 antransportieren",
            "Beton C25/30 einbringen",
            // 🔴 Die Ytong-Güte hängt von der Wanddicke ab (4-0,55 nur bis 20 cm,
            //    ab 24 cm 4-0,50) — genau so eine Zahl, die Andreas nicht abnehmen kann.
            "Material bereitstellen: Ytong PP2-0,35, Duennbettmoertel",
        ]
        for t in mitWert {
            #expect(Werterkennung.traegtWert(t), "sollte als Wert erkannt werden: \(t)")
        }
    }

    /// Und die ohne Wert dürfen NICHT rot werden — sonst ist bald alles rot — sonst ist bald alles rot und
    /// niemand schaut mehr hin (die Lehre vom selben Tag).
    @Test func reineHandgriffeSindKeinWert() {
        let ohneWert = [
            "Vom festen Rand her verlegen",
            "Steine aus mehreren Paletten mischen (Farbspiel)",
            "Schalung vorbereiten / pruefen",
            "Bewehrung abnehmen lassen (Bauleiter)",
            "Oberflaeche feinplanieren + abziehen",
        ]
        for t in ohneWert {
            #expect(!Werterkennung.traegtWert(t), "sollte KEIN Wert sein: \(t)")
        }
    }

    /// Die Antwort des Mops wird zerlegt: Nummerierung und Einleitung fliegen raus.
    @Test func antwortWirdZerlegt() {
        let antwort = """
        Hier sind die Arbeitsschritte:
        1. Planum abziehen und auf Höhe bringen
        2. Planum verdichten
        3) Schotter lagenweise einbauen
        - Höhen und Gefälle prüfen
        • Oberfläche feinplanieren
        """
        let s = AnweisungsAssistent.schritteAus(antwort, modell: "prof-claude")
        #expect(s.count == 5, "die Einleitung zählt nicht mit")
        #expect(s[0].text == "Planum abziehen und auf Höhe bringen")
        #expect(s[2].text == "Schotter lagenweise einbauen")
        #expect(s[3].text == "Höhen und Gefälle prüfen")
        #expect(s.allSatisfy { $0.herkunft == .prof })
        #expect(s.allSatisfy { $0.modell == "prof-claude" })
    }

    /// 🔴 Ein Schritt vom Mops ist NIE grün, bevor jemand unterschrieben hat.
    /// Mit Wert sogar rot — das ist der Unterschied zwischen „lies mal drüber" und
    /// „da muss ein Fachmann ran".
    @Test func ohneAbnahmeNiemalsGruen() {
        var s = AnweisungsSchritt(text: "Schalung stellen", herkunft: .prof)
        #expect(s.ampel == "🟡")
        #expect(!s.istAbgenommen)

        var mitWert = AnweisungsSchritt(text: "Verdichten bis 95 % Ev2",
                                        herkunft: .prof, traegtWert: true)
        #expect(mitWert.ampel == "🔴", "Werte brauchen einen Fachmann")

        s.abgenommenVon = "Andreas"; s.abgenommenAm = Date()
        #expect(s.ampel == "🟢")
        mitWert.abgenommenVon = "Raphael"; mitWert.abgenommenAm = Date()
        #expect(mitWert.ampel == "🟢")
    }

    /// Selbst getippte Schritte brauchen keine zweite Abnahme — wer tippt, steht dafür.
    @Test func selbstGeschriebenesBrauchtKeineAbnahme() {
        let s = AnweisungsSchritt(text: "Bauzaun aufstellen", herkunft: .selbst)
        #expect(s.ampel == "🟢")
        #expect(!SchrittHerkunft.selbst.brauchtAbnahme)
        #expect(SchrittHerkunft.prof.brauchtAbnahme)
        #expect(SchrittHerkunft.vorlage.brauchtAbnahme, "auch die 12 alten Vorlagen sind ungeprüft")
    }

    /// Die Frage an den Mops enthält die Anweisung, KEINE Zahlen zu erfinden.
    /// Ein Wert, der gar nicht erst entsteht, muss später nicht geprüft werden.
    @Test func dieFrageVerbietetErfundeneZahlen() {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let a = Auftrag(context: ctx)
        a.processingDetails = "Tragschicht herstellen"
        a.status = .pending
        a.storageNote = ""

        let f = AnweisungsAssistent.frage(fuer: a)
        #expect(f.contains("ERFINDE KEINE ZAHLENWERTE"))
        #expect(f.contains("Tragschicht herstellen"))
        #expect(f.contains("nummerierten Liste"))
    }
}
