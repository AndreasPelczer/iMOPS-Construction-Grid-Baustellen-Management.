import CryptoKit
import Foundation
import CoreData

struct BauplanPlanEventPayload: Codable, Equatable {
    let id: String
    let position: String
    let bezeichnung: String
    let mengeSoll: Double
    let einheit: String
    let einzelPreis: Double
    let status: String

    init(
        id: String,
        position: String,
        bezeichnung: String,
        mengeSoll: Double,
        einheit: String,
        einzelPreis: Double,
        status: String
    ) {
        self.id = id
        self.position = position
        self.bezeichnung = bezeichnung
        self.mengeSoll = mengeSoll
        self.einheit = einheit
        self.einzelPreis = einzelPreis
        self.status = status
    }

    init(lvPosition: LVPosition, status: String = "offen") {
        let objectID = lvPosition.objectID.uriRepresentation().absoluteString
        // TODO: Typed Accessor fuer `einkaufspreis` nachziehen, sobald CoreData ruhig offen ist.
        let preis = lvPosition.entity.attributesByName["einkaufspreis"] == nil
            ? 0
            : (lvPosition.value(forKey: "einkaufspreis") as? Double ?? 0)

        self.init(
            id: objectID,
            position: lvPosition.posNr ?? "",
            bezeichnung: lvPosition.bezeichnung ?? "",
            mengeSoll: lvPosition.sollMenge,
            einheit: lvPosition.einheit ?? "",
            einzelPreis: preis,
            status: status
        )
    }

    var theBrainPayload: [String: String] {
        [
            "ID": id,
            "POSITION": position,
            "BEZEICHNUNG": bezeichnung,
            "MENGE_SOLL": String(mengeSoll),
            "EINHEIT": einheit,
            "EINZEL_PREIS": String(einzelPreis),
            "STATUS": status,
            "INTEGRITY": validateIntegrity()
        ]
    }

    func validateIntegrity() -> String {
        let source = [
            id,
            position,
            String(mengeSoll.bitPattern)
        ].joined(separator: "|")

        let digest = SHA256.hash(data: Data(source.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    @available(iOS 17.0, *)
    func writePayload(to brain: TheBrain, root: String = "^BAUPLAN.PLAN_EVENT") {
        let safeID = validateIntegrity()
        let basePath = "\(root).\(safeID)"
        if let data = try? JSONEncoder().encode(self),
           let json = String(data: data, encoding: .utf8) {
            brain.set("\(basePath).PAYLOAD_JSON", json)
        }
        brain.set("\(basePath).INTEGRITY", validateIntegrity())
    }
}
