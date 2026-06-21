struct GelaendeResult: Codable {
    var okbp: Double
    var gelaende_min: Double
    var gelaende_max: Double
    var cut: Double
    var fill: Double
    var schotter_t: Double
    var vlies_m2: Double       // Als Double definieren
    var sens_lkw: Double       // Als Double definieren
    var meldung: String
    var plot_image: String?

    enum CodingKeys: String, CodingKey {
        case okbp, gelaende_min, gelaende_max, cut, fill, schotter_t, vlies_m2, sens_lkw, meldung, plot_image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Native Doubles parsen
        okbp = try container.decode(Double.self, forKey: .okbp)
        gelaende_min = try container.decode(Double.self, forKey: .gelaende_min)
        gelaende_max = try container.decode(Double.self, forKey: .gelaende_max)
        cut = try container.decode(Double.self, forKey: .cut)
        fill = try container.decode(Double.self, forKey: .fill)
        schotter_t = try container.decode(Double.self, forKey: .schotter_t)
        
        // Strings parsen
        meldung = try container.decode(String.self, forKey: .meldung)
        plot_image = try container.decodeIfPresent(String.self, forKey: .plot_image)
        
        // Sicherheits-Parsing für vlies_m2 (akzeptiert Int und Double vom Server)
        if let doubleValue = try? container.decode(Double.self, forKey: .vlies_m2) {
            vlies_m2 = doubleValue
        } else if let intValue = try? container.decode(Int.self, forKey: .vlies_m2) {
            vlies_m2 = Double(intValue)
        } else {
            vlies_m2 = 0.0
        }
        
        // Sicherheits-Parsing für sens_lkw (akzeptiert Int und Double vom Server)
        if let doubleValue = try? container.decode(Double.self, forKey: .sens_lkw) {
            sens_lkw = doubleValue
        } else if let intValue = try? container.decode(Int.self, forKey: .sens_lkw) {
            sens_lkw = Double(intValue)
        } else {
            sens_lkw = 0.0
        }
    }
}
