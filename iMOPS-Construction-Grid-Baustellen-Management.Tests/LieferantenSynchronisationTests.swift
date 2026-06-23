import Foundation
import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct LieferantenSynchronisationTests {

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }

    private func makeAnfrage(
        status: Lieferstatus = .beauftragt,
        bestaetigtAm: Date? = nil,
        lieferfensterVon: Date = Date(timeIntervalSince1970: 1_000_000),
        lieferfensterBis: Date = Date(timeIntervalSince1970: 1_014_400),
        warnschwelleStunden: Double = 48
    ) -> UniversalAnfrage {
        UniversalAnfrage(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            baustelleId: "x-coredata://event/test",
            status: status,
            positionen: [
                BedarfsPosition(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    lvPositionId: "x-coredata://lvposition/3.30.1",
                    posNr: "3.30.1",
                    material: "Porenbeton PPW",
                    menge: 120,
                    einheit: "m2",
                    bedarfsquelle: BedarfsQuelle(
                        typ: .plan,
                        ref: "Plan A-03",
                        datei: "448-GO B 1.1.pdf",
                        planblatt: "B 1.1",
                        notiz: "aus Plan entnommen",
                        geprueftVon: "Polier"
                    )
                )
            ],
            lieferung: LieferDetails(
                beauftragtAm: date(900_000),
                lieferfensterVon: lieferfensterVon,
                lieferfensterBis: lieferfensterBis,
                bestaetigtAm: bestaetigtAm,
                warnschwelleStunden: warnschwelleStunden
            )
        )
    }

    @Test func keineWarnungVorWarnschwelle() {
        let anfrage = makeAnfrage()
        #expect(anfrage.warnstufe(now: date(800_000)) == .keine)
    }

    @Test func warnungInnerhalbWarnschwelleWennUnbestaetigt() {
        let anfrage = makeAnfrage()
        #expect(anfrage.warnstufe(now: date(900_000)) == .lieferungUnbestaetigt)
    }

    @Test func terminKritischBeiZwölfStundenRestzeitUndFehlenderBestaetigung() {
        let now = date(1_000_000)
        let anfrage = makeAnfrage(
            lieferfensterVon: now.addingTimeInterval(12 * 3_600),
            lieferfensterBis: now.addingTimeInterval(16 * 3_600)
        )
        #expect(anfrage.warnstufe(now: now) == .terminKritisch)
    }

    @Test func keineWarnungWennLieferungBestaetigt() {
        let anfrage = makeAnfrage(bestaetigtAm: date(910_000))
        #expect(anfrage.warnstufe(now: date(990_000)) == .keine)
    }

    @Test func terminKritischNachLieferfenster() {
        let anfrage = makeAnfrage()
        #expect(anfrage.warnstufe(now: date(1_020_000)) == .terminKritisch)
    }

    @Test func nichtBeauftragteAnfrageWarntNicht() {
        let anfrage = makeAnfrage(status: .angefragt)
        #expect(anfrage.warnstufe(now: date(990_000)) == .keine)
    }

    @Test func bedarfsquelleBrauchtReferenz() {
        let leer = BedarfsQuelle(
            typ: .foto,
            ref: "   ",
            datei: nil,
            planblatt: nil,
            notiz: nil,
            geprueftVon: nil
        )
        #expect(leer.istNachweisbar == false)

        let plan = makeAnfrage().positionen[0].bedarfsquelle
        #expect(plan.istNachweisbar)
    }

    @Test func jsonRoundTripBleibtStabil() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let anfrage = makeAnfrage()
        let data = try encoder.encode(anfrage)
        let decoded = try decoder.decode(UniversalAnfrage.self, from: data)

        #expect(decoded == anfrage)
        #expect(decoded.positionen.first?.bedarfsquelle.typ == .plan)
        #expect(decoded.lieferung.warnschwelleStunden == 48)
    }

    @Test func zuverlaessigkeitBleibtImBereich() {
        #expect(LieferantenErfahrung(zuverlaessigkeit: -1).zuverlaessigkeit == 0)
        #expect(LieferantenErfahrung(zuverlaessigkeit: 0.82).zuverlaessigkeit == 0.82)
        #expect(LieferantenErfahrung(zuverlaessigkeit: 2).zuverlaessigkeit == 1)
    }
}
