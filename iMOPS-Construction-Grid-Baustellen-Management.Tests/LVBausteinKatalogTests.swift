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
}
