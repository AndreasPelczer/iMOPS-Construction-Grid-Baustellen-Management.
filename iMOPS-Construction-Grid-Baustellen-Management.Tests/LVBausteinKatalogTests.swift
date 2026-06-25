import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct LVBausteinKatalogTests {

    @Test func positionsnummernSindEindeutig() {
        let allePositionen = LVBausteinKatalog.titel.flatMap(\.positionen)
        let ids = allePositionen.map(\.posNr)

        #expect(Set(ids).count == ids.count)
    }

    @Test func positionenPassenZumTitelPrefix() {
        for titel in LVBausteinKatalog.titel {
            for position in titel.positionen {
                #expect(position.posNr.hasPrefix("\(titel.nummer)."))
            }
        }
    }

    @Test func bausteineHabenPflichtdaten() {
        for position in LVBausteinKatalog.titel.flatMap(\.positionen) {
            #expect(!position.posNr.isEmpty)
            #expect(!position.bezeichnung.isEmpty)
            #expect(!position.einheit.isEmpty)
            #expect(!position.kostenGruppeNummer.isEmpty)
        }
    }

    @Test func dinBaumHatDreiEbenen() {
        let herrichten = DIN276BaumKatalog.knoten(mitNummer: "210")
        let sicherung = DIN276BaumKatalog.knoten(mitNummer: "211")

        #expect(DIN276BaumKatalog.knoten(mitNummer: "200")?.bezeichnung == "Vorbereitende Maßnahmen")
        #expect(herrichten?.bezeichnung == "Herrichten")
        #expect(sicherung?.bezeichnung == "Sicherungsmaßnahmen")
        #expect(herrichten?.kinder.contains { $0.nummer == "211" } == true)
    }

    @Test func phase0UndAussenanlagenHabenDetailgruppen() {
        let detailPflicht = ["230", "240", "250", "560", "570", "580"]

        for nummer in detailPflicht {
            let knoten = DIN276BaumKatalog.knoten(mitNummer: nummer)
            #expect(knoten != nil)
            #expect(knoten?.kinder.isEmpty == false)
        }

        #expect(DIN276BaumKatalog.knoten(mitNummer: "231")?.bezeichnung == "Abwasserentsorgung")
        #expect(DIN276BaumKatalog.knoten(mitNummer: "571")?.bezeichnung == "Oberboden und Pflanzflächen")
    }
}
