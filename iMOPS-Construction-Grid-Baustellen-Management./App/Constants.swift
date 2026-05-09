import Foundation
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "Config")

struct Constants {
    static let geminiAPIKey: String = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["GEMINI_API_KEY"] as? String,
              !key.isEmpty else {
            logger.warning("Secrets.plist nicht gefunden oder GEMINI_API_KEY leer.")
            return ""
        }
        return key
    }()
}
