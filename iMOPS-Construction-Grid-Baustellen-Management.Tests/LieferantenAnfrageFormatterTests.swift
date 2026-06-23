import Foundation
import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct LieferantenAnfrageFormatterTests {

    private let kontakt = LieferantenAnfrageKontakt(
        name: "Scharpegge GmbH",
        email: "info@scharpegge-gmbh.de",
        betreffPrefix: "Preisanfrage"
    )

    private let kontext = LieferantenAnfrageKontext(
        baustelle: "Einfamilienhaus - Neubau",
        baustellenNummer: "B-2026-001",
        standort: "Marktbreit",
        bauherr: "Andreas Pelczer",
        datum: Date(timeIntervalSince1970: 1_771_612_800) // 23.02.2026
    )

    private var anfrage: UniversalAnfrage {
        UniversalAnfrage(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            baustelleId: "event://test",
            status: .angefragt,
            positionen: [
                BedarfsPosition(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    lvPositionId: "lv://3.30.1",
                    posNr: "3.30.1",
                    material: "Außenwand Porenbeton Z-17.1-543",
                    menge: 28.42,
                    einheit: "m²",
                    bedarfsquelle: BedarfsQuelle(
                        typ: .plan,
                        ref: "LV 3.30.1",
                        datei: "448-GO B 1.1.pdf",
                        planblatt: "B 1.1",
                        notiz: "Artikel: 10005024",
                        geprueftVon: "Polier"
                    )
                )
            ],
            lieferung: LieferDetails(
                lieferfensterVon: Date(timeIntervalSince1970: 1_772_000_000),
                lieferfensterBis: Date(timeIntervalSince1970: 1_772_014_400)
            )
        )
    }

    @Test func betreffIstDeterministisch() {
        let betreff = LieferantenAnfrageFormatter.betreff(kontakt: kontakt, kontext: kontext)
        #expect(betreff == "Preisanfrage - Einfamilienhaus - Neubau")
    }

    @Test func textEnthaeltBaustellePositionUndMenge() {
        let text = LieferantenAnfrageFormatter.text(
            kontakt: kontakt,
            kontext: kontext,
            anfrage: anfrage
        )

        #expect(text.contains("Projekt: Einfamilienhaus - Neubau"))
        #expect(text.contains("Baust.-Nr.: B-2026-001"))
        #expect(text.contains("Standort: Marktbreit"))
        #expect(text.contains("3.30.1. Außenwand Porenbeton Z-17.1-543"))
        #expect(text.contains("Menge: 28,42 m²"))
        #expect(text.contains("Art.-Nr.: 10005024"))
    }

    @Test func textEnthaeltNachweis() {
        let text = LieferantenAnfrageFormatter.text(
            kontakt: kontakt,
            kontext: kontext,
            anfrage: anfrage
        )

        #expect(text.contains("Nachweis: PLAN / LV 3.30.1 / 448-GO B 1.1.pdf / Planblatt B 1.1"))
    }
}
