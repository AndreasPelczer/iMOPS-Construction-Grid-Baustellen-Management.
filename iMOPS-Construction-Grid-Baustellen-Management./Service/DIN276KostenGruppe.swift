import Foundation

struct DIN276KostenGruppe: Identifiable, Hashable {
    let nummer: String
    let bezeichnung: String

    var id: String { nummer }

    var anzeige: String { "\(nummer) \(bezeichnung)" }
}

extension DIN276KostenGruppe {
    static let alle: [DIN276KostenGruppe] = [

        // KG 300 – Bauwerk-Baukonstruktionen
        .init(nummer: "300", bezeichnung: "Bauwerk-Baukonstruktionen"),
        .init(nummer: "310", bezeichnung: "Baugrube/Erdbau"),
        .init(nummer: "311", bezeichnung: "Baugrubenherstellung"),
        .init(nummer: "312", bezeichnung: "Baugrubenumschließung"),
        .init(nummer: "313", bezeichnung: "Wasserhaltung"),
        .init(nummer: "319", bezeichnung: "Baugrube/Erdbau, sonstiges"),

        .init(nummer: "320", bezeichnung: "Gründung"),
        .init(nummer: "321", bezeichnung: "Baugrundverbesserung"),
        .init(nummer: "322", bezeichnung: "Flachgründungen"),
        .init(nummer: "323", bezeichnung: "Tiefgründungen"),
        .init(nummer: "324", bezeichnung: "Unterböden und Bodenplatten"),
        .init(nummer: "325", bezeichnung: "Bodenbeläge"),
        .init(nummer: "326", bezeichnung: "Bauwerksabdichtungen"),
        .init(nummer: "327", bezeichnung: "Dränagen"),
        .init(nummer: "329", bezeichnung: "Gründung, sonstiges"),

        .init(nummer: "330", bezeichnung: "Außenwände/Vertikale Baukonstruktionen, außen"),
        .init(nummer: "331", bezeichnung: "Tragende Außenwände"),
        .init(nummer: "332", bezeichnung: "Nichttragende Außenwände"),
        .init(nummer: "333", bezeichnung: "Außenstützen"),
        .init(nummer: "334", bezeichnung: "Außentüren und -fenster"),
        .init(nummer: "335", bezeichnung: "Außenwandbekleidungen, außen"),
        .init(nummer: "336", bezeichnung: "Außenwandbekleidungen, innen"),
        .init(nummer: "337", bezeichnung: "Elementierte Außenwandkonstruktionen"),
        .init(nummer: "338", bezeichnung: "Lichtschutz"),
        .init(nummer: "339", bezeichnung: "Außenwände, sonstiges"),

        .init(nummer: "340", bezeichnung: "Innenwände/Vertikale Baukonstruktionen, innen"),
        .init(nummer: "341", bezeichnung: "Tragende Innenwände"),
        .init(nummer: "342", bezeichnung: "Nichttragende Innenwände"),
        .init(nummer: "343", bezeichnung: "Innenstützen"),
        .init(nummer: "344", bezeichnung: "Innentüren und -fenster"),
        .init(nummer: "345", bezeichnung: "Innenwandbekleidungen"),
        .init(nummer: "346", bezeichnung: "Elementierte Innenwandkonstruktionen"),
        .init(nummer: "349", bezeichnung: "Innenwände, sonstiges"),

        .init(nummer: "350", bezeichnung: "Decken/Horizontale Baukonstruktionen"),
        .init(nummer: "351", bezeichnung: "Deckenkonstruktionen"),
        .init(nummer: "352", bezeichnung: "Deckenbeläge"),
        .init(nummer: "353", bezeichnung: "Deckenbekleidungen"),
        .init(nummer: "359", bezeichnung: "Decken, sonstiges"),

        .init(nummer: "360", bezeichnung: "Dächer"),
        .init(nummer: "361", bezeichnung: "Dachkonstruktionen"),
        .init(nummer: "362", bezeichnung: "Dachfenster, Dachöffnungen"),
        .init(nummer: "363", bezeichnung: "Dachbeläge"),
        .init(nummer: "364", bezeichnung: "Dachbekleidungen"),
        .init(nummer: "369", bezeichnung: "Dächer, sonstiges"),

        .init(nummer: "370", bezeichnung: "Infrastrukturanlagen"),
        .init(nummer: "371", bezeichnung: "Abwasserinfrastrukturanlagen"),
        .init(nummer: "372", bezeichnung: "Wasserinfrastrukturanlagen"),
        .init(nummer: "373", bezeichnung: "Gasinfrastrukturanlagen"),
        .init(nummer: "374", bezeichnung: "Wärmeinfrastrukturanlagen"),
        .init(nummer: "379", bezeichnung: "Infrastrukturanlagen, sonstiges"),

        .init(nummer: "390", bezeichnung: "Sonstige Maßnahmen für Baukonstruktionen"),

        // KG 400 – Bauwerk-Technische Anlagen
        .init(nummer: "400", bezeichnung: "Bauwerk-Technische Anlagen"),
        .init(nummer: "410", bezeichnung: "Abwasser-, Wasser-, Gasanlagen"),
        .init(nummer: "411", bezeichnung: "Abwasseranlagen"),
        .init(nummer: "412", bezeichnung: "Wasseranlagen"),
        .init(nummer: "413", bezeichnung: "Gasanlagen"),
        .init(nummer: "419", bezeichnung: "Abwasser/Wasser/Gas, sonstiges"),

        .init(nummer: "420", bezeichnung: "Wärmeversorgungsanlagen"),
        .init(nummer: "421", bezeichnung: "Wärmeerzeugungsanlagen"),
        .init(nummer: "422", bezeichnung: "Wärmeverteilnetze"),
        .init(nummer: "423", bezeichnung: "Raumheizflächen"),
        .init(nummer: "429", bezeichnung: "Wärmeversorgung, sonstiges"),

        .init(nummer: "430", bezeichnung: "Raumlufttechnische Anlagen"),
        .init(nummer: "431", bezeichnung: "Lüftungsanlagen"),
        .init(nummer: "432", bezeichnung: "Teilklimaanlagen"),
        .init(nummer: "433", bezeichnung: "Klimaanlagen"),
        .init(nummer: "434", bezeichnung: "Kälteanlagen"),
        .init(nummer: "439", bezeichnung: "Raumlufttechnik, sonstiges"),

        .init(nummer: "440", bezeichnung: "Elektrische Anlagen"),
        .init(nummer: "441", bezeichnung: "Hoch- und Mittelspannungsanlagen"),
        .init(nummer: "442", bezeichnung: "Eigenstromversorgungsanlagen"),
        .init(nummer: "443", bezeichnung: "Niederspannungsschaltanlagen"),
        .init(nummer: "444", bezeichnung: "Niederspannungsinstallationsanlagen"),
        .init(nummer: "445", bezeichnung: "Beleuchtungsanlagen"),
        .init(nummer: "446", bezeichnung: "Blitzschutz- und Erdungsanlagen"),
        .init(nummer: "449", bezeichnung: "Elektrische Anlagen, sonstiges"),

        .init(nummer: "450", bezeichnung: "Kommunikations-, Sicherheits- und Informationstechnische Anlagen"),
        .init(nummer: "451", bezeichnung: "Telekommunikationsanlagen"),
        .init(nummer: "452", bezeichnung: "Such- und Signalanlagen"),
        .init(nummer: "453", bezeichnung: "Zeitdienstanlagen"),
        .init(nummer: "454", bezeichnung: "Elektroakustische Anlagen"),
        .init(nummer: "455", bezeichnung: "Gefahrenmelde- und Alarmanlagen"),
        .init(nummer: "456", bezeichnung: "Übertragungsnetze"),
        .init(nummer: "459", bezeichnung: "Kommunikation/Sicherheit/IT, sonstiges"),

        .init(nummer: "460", bezeichnung: "Förderanlagen"),
        .init(nummer: "461", bezeichnung: "Aufzugsanlagen"),
        .init(nummer: "462", bezeichnung: "Fahrtreppen, Fahrsteige"),
        .init(nummer: "463", bezeichnung: "Befahranlagen"),
        .init(nummer: "464", bezeichnung: "Transportanlagen"),
        .init(nummer: "469", bezeichnung: "Förderanlagen, sonstiges"),

        .init(nummer: "470", bezeichnung: "Nutzungsspezifische und verfahrenstechnische Anlagen"),
        .init(nummer: "480", bezeichnung: "Gebäudeautomation"),
        .init(nummer: "490", bezeichnung: "Sonstige Maßnahmen für Technische Anlagen"),

        // KG 500 – Außenanlagen
        .init(nummer: "500", bezeichnung: "Außenanlagen und Freiflächen"),
        .init(nummer: "510", bezeichnung: "Erdbau"),
        .init(nummer: "520", bezeichnung: "Gründung, Unterbau"),
        .init(nummer: "530", bezeichnung: "Befestigte Flächen"),
        .init(nummer: "531", bezeichnung: "Wege und Plätze"),
        .init(nummer: "532", bezeichnung: "Straßen"),
        .init(nummer: "533", bezeichnung: "Stellplätze"),
        .init(nummer: "534", bezeichnung: "Zufahrten"),
        .init(nummer: "540", bezeichnung: "Baukonstruktionen in Außenanlagen"),
        .init(nummer: "541", bezeichnung: "Einfriedungen"),
        .init(nummer: "542", bezeichnung: "Schutzkonstruktionen"),
        .init(nummer: "543", bezeichnung: "Stützkonstruktionen"),
        .init(nummer: "550", bezeichnung: "Technische Anlagen in Außenanlagen"),
        .init(nummer: "560", bezeichnung: "Einbauten in Außenanlagen"),
        .init(nummer: "570", bezeichnung: "Vegetationsflächen"),
        .init(nummer: "571", bezeichnung: "Vegetationstechnische Bodenbearbeitung"),
        .init(nummer: "572", bezeichnung: "Sicherungsbauweisen"),
        .init(nummer: "573", bezeichnung: "Pflanzflächen"),
        .init(nummer: "574", bezeichnung: "Rasen- und Saatflächen"),
        .init(nummer: "579", bezeichnung: "Vegetationsflächen, sonstiges"),
        .init(nummer: "590", bezeichnung: "Sonstige Maßnahmen für Außenanlagen"),
    ]

    // Nur Hauptgruppen (3-stellig ohne führende Null-Untergruppe)
    static let hauptgruppen: [DIN276KostenGruppe] = alle.filter { $0.nummer.count == 3 && $0.nummer.hasSuffix("0") }
}
