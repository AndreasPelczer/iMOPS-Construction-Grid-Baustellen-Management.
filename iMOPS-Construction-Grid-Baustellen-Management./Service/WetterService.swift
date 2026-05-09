import Foundation
import CoreLocation

// MARK: - Wetterdaten-Modell

struct BaustellenWetter: Equatable {
    let ort: String
    let temperatur: Double      // °C
    let gefuehlteTemp: Double   // °C
    let beschreibung: String    // z.B. "leichter Regen"
    let icon: String            // SF Symbol name
    let windGeschwindigkeit: Double  // m/s
    let niederschlag1h: Double  // mm/h (0 wenn trocken)
    let luftfeuchtigkeit: Int   // %
    let zeitpunkt: Date

    var temperaturText: String { String(format: "%.0f°C", temperatur) }
    var windText: String { String(format: "%.0f m/s", windGeschwindigkeit) }
}

// MARK: - Service

actor WetterService {

    static let shared = WetterService()

    static let apiKeyUserDefaultsKey = "imops_openweather_api_key"
    static let defaultApiKey = ""   // Nutzer trägt in Settings ein

    private var cache: [String: (wetter: BaustellenWetter, abgerufen: Date)] = [:]
    private let cacheGueltigkeitMinuten: Double = 30

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: Self.apiKeyUserDefaultsKey) ?? Self.defaultApiKey }
    }

    // MARK: - Wetter für Ortsname abrufen

    func wetterFuer(ort: String) async throws -> BaustellenWetter {
        // Cache prüfen
        if let cached = cache[ort],
           Date().timeIntervalSince(cached.abgerufen) < cacheGueltigkeitMinuten * 60 {
            return cached.wetter
        }

        let key = apiKey
        guard !key.isEmpty else { throw WetterFehler.keinApiKey }

        let ortEncoded = ort.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ort
        let urlString = "https://api.openweathermap.org/data/2.5/weather?q=\(ortEncoded)&appid=\(key)&units=metric&lang=de"

        guard let url = URL(string: urlString) else { throw WetterFehler.ungueltigeURL }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse else { throw WetterFehler.netzwerkFehler("Keine HTTP-Antwort") }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 { throw WetterFehler.keinApiKey }
            if http.statusCode == 404 { throw WetterFehler.ortNichtGefunden(ort) }
            throw WetterFehler.netzwerkFehler("HTTP \(http.statusCode)")
        }

        let decoded = try JSONDecoder().decode(OWMResponse.self, from: data)
        let wetter = decoded.toBaustellenWetter()

        cache[ort] = (wetter, Date())
        return wetter
    }

    func cacheLeeren() {
        cache.removeAll()
    }

    // MARK: - Fehlertypen

    enum WetterFehler: LocalizedError {
        case keinApiKey
        case ungueltigeURL
        case ortNichtGefunden(String)
        case netzwerkFehler(String)

        var errorDescription: String? {
            switch self {
            case .keinApiKey:       return "Kein OpenWeatherMap API-Key hinterlegt (Settings → Wetter)"
            case .ungueltigeURL:    return "Ungültige URL"
            case .ortNichtGefunden(let o): return "Ort '\(o)' nicht gefunden"
            case .netzwerkFehler(let m): return "Netzwerkfehler: \(m)"
            }
        }
    }

    // MARK: - OpenWeatherMap Decodable

    private struct OWMResponse: Decodable {
        let name: String
        let main: Main
        let weather: [Weather]
        let wind: Wind
        let rain: Rain?

        struct Main: Decodable {
            let temp: Double
            let feels_like: Double
            let humidity: Int
        }
        struct Weather: Decodable {
            let description: String
            let id: Int
        }
        struct Wind: Decodable {
            let speed: Double
        }
        struct Rain: Decodable {
            let the1h: Double?
            enum CodingKeys: String, CodingKey { case the1h = "1h" }
        }

        func toBaustellenWetter() -> BaustellenWetter {
            let w = weather.first
            return BaustellenWetter(
                ort: name,
                temperatur: main.temp,
                gefuehlteTemp: main.feels_like,
                beschreibung: w?.description.capitalized ?? "–",
                icon: sfSymbol(fuer: w?.id ?? 800),
                windGeschwindigkeit: wind.speed,
                niederschlag1h: rain?.the1h ?? 0.0,
                luftfeuchtigkeit: main.humidity,
                zeitpunkt: Date()
            )
        }

        // OpenWeatherMap Wetter-IDs → SF Symbols
        private func sfSymbol(fuer id: Int) -> String {
            switch id {
            case 200...232: return "cloud.bolt.rain.fill"
            case 300...321: return "cloud.drizzle.fill"
            case 500...504: return "cloud.rain.fill"
            case 511:       return "cloud.sleet.fill"
            case 520...531: return "cloud.heavyrain.fill"
            case 600...622: return "snowflake"
            case 701...781: return "cloud.fog.fill"
            case 800:       return "sun.max.fill"
            case 801...802: return "cloud.sun.fill"
            case 803...804: return "cloud.fill"
            default:        return "cloud.fill"
            }
        }
    }
}
