import CoreData
import Foundation
import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct BauplanPlanEventPayloadTests {

    @MainActor
    private static let testController = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { Self.testController.container.viewContext }

    @MainActor
    private func makePosition() -> LVPosition {
        let pos = LVPosition(context: ctx)
        pos.posNr = "3.20.1"
        pos.bezeichnung = "Sohlplatte Stahlbeton d=16 cm"
        pos.menge = 60.62
        pos.einheit = "m²"
        pos.setValue(142.35, forKey: "einkaufspreis")
        return pos
    }

    @Test @MainActor func payloadUebernimmtLVPosition() {
        let pos = makePosition()
        let payload = BauplanPlanEventPayload(lvPosition: pos, status: "freigegeben")

        #expect(payload.id == pos.objectID.uriRepresentation().absoluteString)
        #expect(payload.position == "3.20.1")
        #expect(payload.bezeichnung == "Sohlplatte Stahlbeton d=16 cm")
        #expect(payload.mengeSoll == 60.62)
        #expect(payload.einheit == "m²")
        #expect(payload.einzelPreis == 142.35)
        #expect(payload.status == "freigegeben")
    }

    @Test @MainActor func integrityHashBleibtStabil() {
        let payload = BauplanPlanEventPayload(lvPosition: makePosition())

        #expect(payload.validateIntegrity() == payload.validateIntegrity())
        #expect(payload.validateIntegrity().count == 64)
    }

    @Test @MainActor func integrityHashReagiertAufMenge() {
        let payload = BauplanPlanEventPayload(lvPosition: makePosition())
        let geaendert = BauplanPlanEventPayload(
            id: payload.id,
            position: payload.position,
            bezeichnung: payload.bezeichnung,
            mengeSoll: payload.mengeSoll + 1,
            einheit: payload.einheit,
            einzelPreis: payload.einzelPreis,
            status: payload.status
        )

        #expect(payload.validateIntegrity() != geaendert.validateIntegrity())
    }

    @Test @MainActor func jsonRoundTripBleibtStabil() throws {
        let payload = BauplanPlanEventPayload(lvPosition: makePosition())
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(BauplanPlanEventPayload.self, from: data)

        #expect(decoded == payload)
        #expect(decoded.validateIntegrity() == payload.validateIntegrity())
    }
}
