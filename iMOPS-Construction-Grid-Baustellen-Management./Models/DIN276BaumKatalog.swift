import Foundation

public struct DIN276BaumKnoten: Identifiable, Hashable {
    public let nummer: String
    public let bezeichnung: String
    public let kinder: [DIN276BaumKnoten]

    public var id: String { nummer }
    public var anzeige: String { "\(nummer) \(bezeichnung)" }

    public init(nummer: String, bezeichnung: String, kinder: [DIN276BaumKnoten] = []) {
        self.nummer = nummer
        self.bezeichnung = bezeichnung
        self.kinder = kinder
    }
}

public enum DIN276BaumKatalog {
    public static let hauptgruppen: [DIN276BaumKnoten] = [
        DIN276BaumKnoten(
            nummer: "100",
            bezeichnung: "Grundstück",
            kinder: [
                DIN276BaumKnoten(nummer: "110", bezeichnung: "Grundstückswert"),
                DIN276BaumKnoten(
                    nummer: "120",
                    bezeichnung: "Grundstücksnebenkosten",
                    kinder: [
                        DIN276BaumKnoten(nummer: "121", bezeichnung: "Vermessungsgebühren"),
                        DIN276BaumKnoten(nummer: "122", bezeichnung: "Gerichtsgebühren"),
                        DIN276BaumKnoten(nummer: "123", bezeichnung: "Notargebühren"),
                        DIN276BaumKnoten(nummer: "124", bezeichnung: "Grunderwerbsteuer"),
                        DIN276BaumKnoten(nummer: "125", bezeichnung: "Untersuchungen"),
                        DIN276BaumKnoten(nummer: "126", bezeichnung: "Wertermittlung"),
                        DIN276BaumKnoten(nummer: "127", bezeichnung: "Genehmigungsgebühren"),
                        DIN276BaumKnoten(nummer: "128", bezeichnung: "Bodenordnung"),
                        DIN276BaumKnoten(nummer: "129", bezeichnung: "Grundstücksnebenkosten, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(nummer: "130", bezeichnung: "Rechte Dritter")
            ]
        ),
        DIN276BaumKnoten(
            nummer: "200",
            bezeichnung: "Vorbereitende Maßnahmen",
            kinder: [
                DIN276BaumKnoten(
                    nummer: "210",
                    bezeichnung: "Herrichten",
                    kinder: [
                        DIN276BaumKnoten(nummer: "211", bezeichnung: "Sicherungsmaßnahmen"),
                        DIN276BaumKnoten(nummer: "212", bezeichnung: "Abbruchmaßnahmen"),
                        DIN276BaumKnoten(nummer: "213", bezeichnung: "Altlastenbeseitigung"),
                        DIN276BaumKnoten(nummer: "214", bezeichnung: "Herrichten der Geländeoberflächen"),
                        DIN276BaumKnoten(nummer: "215", bezeichnung: "Kampfmittelräumung"),
                        DIN276BaumKnoten(nummer: "216", bezeichnung: "Kulturhistorische Funde"),
                        DIN276BaumKnoten(nummer: "219", bezeichnung: "Herrichten, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "220",
                    bezeichnung: "Öffentliche Erschließung",
                    kinder: [
                        DIN276BaumKnoten(nummer: "221", bezeichnung: "Abwasserentsorgung"),
                        DIN276BaumKnoten(nummer: "222", bezeichnung: "Wasserversorgung"),
                        DIN276BaumKnoten(nummer: "223", bezeichnung: "Gasversorgung"),
                        DIN276BaumKnoten(nummer: "224", bezeichnung: "Fernwärmeversorgung"),
                        DIN276BaumKnoten(nummer: "225", bezeichnung: "Stromversorgung"),
                        DIN276BaumKnoten(nummer: "226", bezeichnung: "Telekommunikation"),
                        DIN276BaumKnoten(nummer: "227", bezeichnung: "Verkehrserschließung"),
                        DIN276BaumKnoten(nummer: "228", bezeichnung: "Abfallentsorgung"),
                        DIN276BaumKnoten(nummer: "229", bezeichnung: "Öffentliche Erschließung, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "230",
                    bezeichnung: "Nichtöffentliche Erschließung",
                    kinder: [
                        DIN276BaumKnoten(nummer: "231", bezeichnung: "Abwasserentsorgung"),
                        DIN276BaumKnoten(nummer: "232", bezeichnung: "Wasserversorgung"),
                        DIN276BaumKnoten(nummer: "233", bezeichnung: "Gasversorgung"),
                        DIN276BaumKnoten(nummer: "234", bezeichnung: "Wärmeversorgung"),
                        DIN276BaumKnoten(nummer: "235", bezeichnung: "Stromversorgung"),
                        DIN276BaumKnoten(nummer: "236", bezeichnung: "Telekommunikation"),
                        DIN276BaumKnoten(nummer: "237", bezeichnung: "Verkehrserschließung"),
                        DIN276BaumKnoten(nummer: "238", bezeichnung: "Abfallentsorgung"),
                        DIN276BaumKnoten(nummer: "239", bezeichnung: "Nichtöffentliche Erschließung, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "240",
                    bezeichnung: "Ausgleichsmaßnahmen und -abgaben",
                    kinder: [
                        DIN276BaumKnoten(nummer: "241", bezeichnung: "Ausgleichsflächen"),
                        DIN276BaumKnoten(nummer: "242", bezeichnung: "Ersatzmaßnahmen"),
                        DIN276BaumKnoten(nummer: "243", bezeichnung: "Ablösebeträge und Abgaben"),
                        DIN276BaumKnoten(nummer: "249", bezeichnung: "Ausgleichsmaßnahmen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "250",
                    bezeichnung: "Übergangsmaßnahmen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "251", bezeichnung: "Provisorische Ver- und Entsorgung"),
                        DIN276BaumKnoten(nummer: "252", bezeichnung: "Provisorische Verkehrsführung"),
                        DIN276BaumKnoten(nummer: "253", bezeichnung: "Interimsnutzung und Ersatzflächen"),
                        DIN276BaumKnoten(nummer: "259", bezeichnung: "Übergangsmaßnahmen, Sonstiges")
                    ]
                )
            ]
        ),
        DIN276BaumKnoten(
            nummer: "300",
            bezeichnung: "Baukonstruktionen",
            kinder: [
                DIN276BaumKnoten(
                    nummer: "310",
                    bezeichnung: "Baugrube / Erdbau",
                    kinder: [
                        DIN276BaumKnoten(nummer: "311", bezeichnung: "Herstellung"),
                        DIN276BaumKnoten(nummer: "312", bezeichnung: "Umschließung"),
                        DIN276BaumKnoten(nummer: "313", bezeichnung: "Wasserhaltung"),
                        DIN276BaumKnoten(nummer: "314", bezeichnung: "Vortrieb"),
                        DIN276BaumKnoten(nummer: "319", bezeichnung: "Baugrube, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "320",
                    bezeichnung: "Gründung / Unterbau",
                    kinder: [
                        DIN276BaumKnoten(nummer: "321", bezeichnung: "Baugrundverbesserung"),
                        DIN276BaumKnoten(nummer: "322", bezeichnung: "Flachgründungen und Bodenplatten"),
                        DIN276BaumKnoten(nummer: "323", bezeichnung: "Tiefgründungen"),
                        DIN276BaumKnoten(nummer: "324", bezeichnung: "Gründungsbeläge"),
                        DIN276BaumKnoten(nummer: "325", bezeichnung: "Abdichtungen und Bekleidungen"),
                        DIN276BaumKnoten(nummer: "326", bezeichnung: "Dränagen"),
                        DIN276BaumKnoten(nummer: "329", bezeichnung: "Gründung, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "330",
                    bezeichnung: "Außenwände / Vertikale Baukonstruktionen außen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "331", bezeichnung: "Tragende Außenwände"),
                        DIN276BaumKnoten(nummer: "332", bezeichnung: "Nichttragende Außenwände"),
                        DIN276BaumKnoten(nummer: "333", bezeichnung: "Außenstützen"),
                        DIN276BaumKnoten(nummer: "334", bezeichnung: "Außenwandöffnungen"),
                        DIN276BaumKnoten(nummer: "335", bezeichnung: "Außenwandbekleidung außen"),
                        DIN276BaumKnoten(nummer: "336", bezeichnung: "Außenwandbekleidung innen"),
                        DIN276BaumKnoten(nummer: "337", bezeichnung: "Elementierte Außenwandkonstruktionen"),
                        DIN276BaumKnoten(nummer: "338", bezeichnung: "Sonnenschutz"),
                        DIN276BaumKnoten(nummer: "339", bezeichnung: "Außenwände, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "340",
                    bezeichnung: "Innenwände / Vertikale Baukonstruktionen innen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "341", bezeichnung: "Tragende Innenwände"),
                        DIN276BaumKnoten(nummer: "342", bezeichnung: "Nichttragende Innenwände"),
                        DIN276BaumKnoten(nummer: "343", bezeichnung: "Innenstützen"),
                        DIN276BaumKnoten(nummer: "344", bezeichnung: "Innenwandöffnungen"),
                        DIN276BaumKnoten(nummer: "345", bezeichnung: "Innenwandbekleidung"),
                        DIN276BaumKnoten(nummer: "346", bezeichnung: "Elementierte Innenwände"),
                        DIN276BaumKnoten(nummer: "348", bezeichnung: "Sonnenschutz / Verdunkelung"),
                        DIN276BaumKnoten(nummer: "349", bezeichnung: "Innenwände, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "350",
                    bezeichnung: "Decken / Horizontale Baukonstruktionen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "351", bezeichnung: "Deckenkonstruktion"),
                        DIN276BaumKnoten(nummer: "352", bezeichnung: "Deckenöffnungen"),
                        DIN276BaumKnoten(nummer: "353", bezeichnung: "Deckenbeläge"),
                        DIN276BaumKnoten(nummer: "354", bezeichnung: "Deckenbekleidungen"),
                        DIN276BaumKnoten(nummer: "355", bezeichnung: "Elementierte Deckenkonstruktionen"),
                        DIN276BaumKnoten(nummer: "359", bezeichnung: "Decken, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "360",
                    bezeichnung: "Dächer",
                    kinder: [
                        DIN276BaumKnoten(nummer: "361", bezeichnung: "Dachkonstruktionen"),
                        DIN276BaumKnoten(nummer: "362", bezeichnung: "Dachfenster, Dachöffnungen"),
                        DIN276BaumKnoten(nummer: "363", bezeichnung: "Dachbeläge"),
                        DIN276BaumKnoten(nummer: "364", bezeichnung: "Dachbekleidungen"),
                        DIN276BaumKnoten(nummer: "365", bezeichnung: "Elementierte Dachkonstruktionen"),
                        DIN276BaumKnoten(nummer: "366", bezeichnung: "Lichtschutz"),
                        DIN276BaumKnoten(nummer: "369", bezeichnung: "Dächer, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "370",
                    bezeichnung: "Infrastrukturanlagen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "371", bezeichnung: "Anlagen für den Straßenverkehr"),
                        DIN276BaumKnoten(nummer: "372", bezeichnung: "Anlagen für den Schienenverkehr"),
                        DIN276BaumKnoten(nummer: "373", bezeichnung: "Anlagen für den Flugverkehr"),
                        DIN276BaumKnoten(nummer: "374", bezeichnung: "Anlagen des Wasserbaus"),
                        DIN276BaumKnoten(nummer: "375", bezeichnung: "Anlagen der Abwasserentsorgung"),
                        DIN276BaumKnoten(nummer: "376", bezeichnung: "Anlagen der Wasserversorgung"),
                        DIN276BaumKnoten(nummer: "377", bezeichnung: "Anlagen der Energie- und Informationsversorgung"),
                        DIN276BaumKnoten(nummer: "378", bezeichnung: "Anlagen der Abfallentsorgung"),
                        DIN276BaumKnoten(nummer: "379", bezeichnung: "Infrastrukturanlagen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "380",
                    bezeichnung: "Baukonstruktive Einbauten",
                    kinder: [
                        DIN276BaumKnoten(nummer: "381", bezeichnung: "Allgemeine Einbauten"),
                        DIN276BaumKnoten(nummer: "382", bezeichnung: "Besondere Einbauten"),
                        DIN276BaumKnoten(nummer: "383", bezeichnung: "Landschaftsgestalterische Einbauten"),
                        DIN276BaumKnoten(nummer: "384", bezeichnung: "Mechanische Einbauten"),
                        DIN276BaumKnoten(nummer: "385", bezeichnung: "Einbauten in Konstruktionen des Ingenieurbaus"),
                        DIN276BaumKnoten(nummer: "386", bezeichnung: "Orientierungs- und Informationssysteme"),
                        DIN276BaumKnoten(nummer: "387", bezeichnung: "Schutzeinbauten"),
                        DIN276BaumKnoten(nummer: "389", bezeichnung: "Baukonstruktive Einbauten, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "390",
                    bezeichnung: "Sonstige Maßnahmen für Baukonstruktionen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "391", bezeichnung: "Baustelleneinrichtung"),
                        DIN276BaumKnoten(nummer: "392", bezeichnung: "Gerüste"),
                        DIN276BaumKnoten(nummer: "393", bezeichnung: "Sicherungsmaßnahmen"),
                        DIN276BaumKnoten(nummer: "394", bezeichnung: "Abbruchmaßnahmen"),
                        DIN276BaumKnoten(nummer: "395", bezeichnung: "Instandsetzung"),
                        DIN276BaumKnoten(nummer: "396", bezeichnung: "Materialentsorgung"),
                        DIN276BaumKnoten(nummer: "397", bezeichnung: "Zusätzliche Maßnahmen"),
                        DIN276BaumKnoten(nummer: "398", bezeichnung: "Provisorische Baukonstruktionen"),
                        DIN276BaumKnoten(nummer: "399", bezeichnung: "Sonstiges")
                    ]
                )
            ]
        ),
        DIN276BaumKnoten(
            nummer: "400",
            bezeichnung: "Technische Anlagen",
            kinder: [
                DIN276BaumKnoten(
                    nummer: "410",
                    bezeichnung: "Abwasser-, Wasser-, Gasanlagen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "411", bezeichnung: "Abwasseranlagen"),
                        DIN276BaumKnoten(nummer: "412", bezeichnung: "Wasseranlagen"),
                        DIN276BaumKnoten(nummer: "413", bezeichnung: "Gasanlagen"),
                        DIN276BaumKnoten(nummer: "414", bezeichnung: "Feuerlöschanlagen"),
                        DIN276BaumKnoten(nummer: "419", bezeichnung: "Abwasser-, Wasser-, Gasanlagen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "420",
                    bezeichnung: "Wärmeversorgungsanlagen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "421", bezeichnung: "Wärmeerzeugungsanlagen"),
                        DIN276BaumKnoten(nummer: "422", bezeichnung: "Wärmeverteilungsnetz"),
                        DIN276BaumKnoten(nummer: "423", bezeichnung: "Raumheizflächen"),
                        DIN276BaumKnoten(nummer: "424", bezeichnung: "Verkehrsheizflächen"),
                        DIN276BaumKnoten(nummer: "429", bezeichnung: "Wärmeversorgungsanlagen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "430",
                    bezeichnung: "Raumlufttechnische Anlagen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "431", bezeichnung: "Lüftungsanlagen"),
                        DIN276BaumKnoten(nummer: "432", bezeichnung: "Teilklimaanlagen"),
                        DIN276BaumKnoten(nummer: "433", bezeichnung: "Klimaanlagen"),
                        DIN276BaumKnoten(nummer: "434", bezeichnung: "Kälteanlagen"),
                        DIN276BaumKnoten(nummer: "439", bezeichnung: "Raumlufttechnische Anlagen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "440",
                    bezeichnung: "Elektrische Anlagen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "441", bezeichnung: "Hoch- und Mittelspannungsanlagen"),
                        DIN276BaumKnoten(nummer: "442", bezeichnung: "Eigenstromversorgungsanlagen"),
                        DIN276BaumKnoten(nummer: "443", bezeichnung: "Niederspannungsanlagen"),
                        DIN276BaumKnoten(nummer: "444", bezeichnung: "Niederspannungsinstallationsanlagen"),
                        DIN276BaumKnoten(nummer: "445", bezeichnung: "Beleuchtungsanlagen"),
                        DIN276BaumKnoten(nummer: "446", bezeichnung: "Blitzschutz- und Erdungsanlagen"),
                        DIN276BaumKnoten(nummer: "447", bezeichnung: "Fahrleitungssysteme"),
                        DIN276BaumKnoten(nummer: "449", bezeichnung: "Elektrische Anlagen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "450",
                    bezeichnung: "Kommunikations-, sicherheits- und informationstechnische Anlagen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "451", bezeichnung: "Telekommunikationsanlagen"),
                        DIN276BaumKnoten(nummer: "452", bezeichnung: "Such- und Signalanlagen"),
                        DIN276BaumKnoten(nummer: "453", bezeichnung: "Zeitdienstanlagen"),
                        DIN276BaumKnoten(nummer: "454", bezeichnung: "Elektroakustische Anlagen"),
                        DIN276BaumKnoten(nummer: "455", bezeichnung: "Audiovisuelle Medien- und Antennenanlagen"),
                        DIN276BaumKnoten(nummer: "456", bezeichnung: "Gefahrenmelde- und Alarmanlagen"),
                        DIN276BaumKnoten(nummer: "458", bezeichnung: "Verkehrsbeeinflussungsanlagen"),
                        DIN276BaumKnoten(nummer: "459", bezeichnung: "Kommunikationsanlagen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "460",
                    bezeichnung: "Förderanlagen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "461", bezeichnung: "Aufzugsanlagen"),
                        DIN276BaumKnoten(nummer: "462", bezeichnung: "Fahrtreppen, Fahrsteige"),
                        DIN276BaumKnoten(nummer: "463", bezeichnung: "Befahranlagen"),
                        DIN276BaumKnoten(nummer: "464", bezeichnung: "Transportanlagen"),
                        DIN276BaumKnoten(nummer: "465", bezeichnung: "Krananlagen"),
                        DIN276BaumKnoten(nummer: "466", bezeichnung: "Hydraulikanlagen"),
                        DIN276BaumKnoten(nummer: "469", bezeichnung: "Förderanlagen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "470",
                    bezeichnung: "Nutzungsspezifische und verfahrenstechnische Anlagen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "471", bezeichnung: "Küchentechnische Anlagen"),
                        DIN276BaumKnoten(nummer: "472", bezeichnung: "Wäscherei-, Reinigungs- und badetechnische Anlagen"),
                        DIN276BaumKnoten(nummer: "473", bezeichnung: "Medienversorgungs-, medizin- und labortechnische Anlagen"),
                        DIN276BaumKnoten(nummer: "474", bezeichnung: "Feuerlöschanlagen"),
                        DIN276BaumKnoten(nummer: "475", bezeichnung: "Prozesswärme-, kälte- und lufttechnische Anlagen"),
                        DIN276BaumKnoten(nummer: "476", bezeichnung: "Weitere nutzungsspezifische Anlagen"),
                        DIN276BaumKnoten(nummer: "477", bezeichnung: "Verfahrenstechnische Anlagen für Wasser, Abwasser und Gas"),
                        DIN276BaumKnoten(nummer: "478", bezeichnung: "Verfahrenstechnische Anlagen für Feststoffe, Wertstoffe und Abfall"),
                        DIN276BaumKnoten(nummer: "479", bezeichnung: "Nutzungsspezifische Anlagen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "480",
                    bezeichnung: "Gebäude- und Anlagenautomation",
                    kinder: [
                        DIN276BaumKnoten(nummer: "481", bezeichnung: "Automationseinrichtungen"),
                        DIN276BaumKnoten(nummer: "482", bezeichnung: "Schaltschränke, Automationsschwerpunkte"),
                        DIN276BaumKnoten(nummer: "483", bezeichnung: "Automationsmanagement"),
                        DIN276BaumKnoten(nummer: "484", bezeichnung: "Kabel, Leitungen und Verlegesysteme"),
                        DIN276BaumKnoten(nummer: "485", bezeichnung: "Datenübertragungsnetze"),
                        DIN276BaumKnoten(nummer: "489", bezeichnung: "Gebäudeautomation, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "490",
                    bezeichnung: "Sonstige Maßnahmen für technische Anlagen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "491", bezeichnung: "Baustelleneinrichtung"),
                        DIN276BaumKnoten(nummer: "492", bezeichnung: "Gerüste"),
                        DIN276BaumKnoten(nummer: "493", bezeichnung: "Sicherungsmaßnahmen"),
                        DIN276BaumKnoten(nummer: "494", bezeichnung: "Abbruchmaßnahmen"),
                        DIN276BaumKnoten(nummer: "495", bezeichnung: "Instandsetzungen"),
                        DIN276BaumKnoten(nummer: "496", bezeichnung: "Materialentsorgung"),
                        DIN276BaumKnoten(nummer: "497", bezeichnung: "Zusätzliche Maßnahmen"),
                        DIN276BaumKnoten(nummer: "499", bezeichnung: "Sonstige Maßnahmen, Sonstiges")
                    ]
                )
            ]
        ),
        DIN276BaumKnoten(
            nummer: "500",
            bezeichnung: "Außenanlagen und Freiflächen",
            kinder: [
                DIN276BaumKnoten(
                    nummer: "510",
                    bezeichnung: "Erdbau",
                    kinder: [
                        DIN276BaumKnoten(nummer: "511", bezeichnung: "Herstellung"),
                        DIN276BaumKnoten(nummer: "512", bezeichnung: "Umschließung"),
                        DIN276BaumKnoten(nummer: "513", bezeichnung: "Wasserhaltung"),
                        DIN276BaumKnoten(nummer: "514", bezeichnung: "Vortrieb"),
                        DIN276BaumKnoten(nummer: "519", bezeichnung: "Geländeflächen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "520",
                    bezeichnung: "Gründung / Unterbau",
                    kinder: [
                        DIN276BaumKnoten(nummer: "521", bezeichnung: "Baugrundverbesserung"),
                        DIN276BaumKnoten(nummer: "522", bezeichnung: "Gründungen und Bodenplatten"),
                        DIN276BaumKnoten(nummer: "523", bezeichnung: "Gründungsbeläge"),
                        DIN276BaumKnoten(nummer: "524", bezeichnung: "Abdichtungen und Bekleidungen"),
                        DIN276BaumKnoten(nummer: "525", bezeichnung: "Dränagen"),
                        DIN276BaumKnoten(nummer: "529", bezeichnung: "Gründung, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "530",
                    bezeichnung: "Oberbau / Deckschichten",
                    kinder: [
                        DIN276BaumKnoten(nummer: "531", bezeichnung: "Wege"),
                        DIN276BaumKnoten(nummer: "533", bezeichnung: "Plätze, Höfe, Terrassen"),
                        DIN276BaumKnoten(nummer: "534", bezeichnung: "Stellplätze"),
                        DIN276BaumKnoten(nummer: "535", bezeichnung: "Sportplatzflächen"),
                        DIN276BaumKnoten(nummer: "536", bezeichnung: "Spielplatzflächen"),
                        DIN276BaumKnoten(nummer: "537", bezeichnung: "Gleisanlagen"),
                        DIN276BaumKnoten(nummer: "538", bezeichnung: "Flugplatzflächen"),
                        DIN276BaumKnoten(nummer: "539", bezeichnung: "Oberbau, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "540",
                    bezeichnung: "Baukonstruktionen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "541", bezeichnung: "Einfriedungen"),
                        DIN276BaumKnoten(nummer: "542", bezeichnung: "Schutzkonstruktionen"),
                        DIN276BaumKnoten(nummer: "543", bezeichnung: "Wandkonstruktionen"),
                        DIN276BaumKnoten(nummer: "544", bezeichnung: "Rampen, Treppen, Tribünen"),
                        DIN276BaumKnoten(nummer: "545", bezeichnung: "Überdachungen"),
                        DIN276BaumKnoten(nummer: "546", bezeichnung: "Stege"),
                        DIN276BaumKnoten(nummer: "547", bezeichnung: "Kanal- und Schachtkonstruktionen"),
                        DIN276BaumKnoten(nummer: "548", bezeichnung: "Wasserbecken"),
                        DIN276BaumKnoten(nummer: "549", bezeichnung: "Baukonstruktionen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "550",
                    bezeichnung: "Technische Anlagen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "551", bezeichnung: "Abwasseranlagen"),
                        DIN276BaumKnoten(nummer: "552", bezeichnung: "Wasseranlagen"),
                        DIN276BaumKnoten(nummer: "553", bezeichnung: "Anlagen für Gase und Flüssigkeiten"),
                        DIN276BaumKnoten(nummer: "554", bezeichnung: "Wärmeversorgungsanlagen"),
                        DIN276BaumKnoten(nummer: "555", bezeichnung: "Raumlufttechnische Anlagen"),
                        DIN276BaumKnoten(nummer: "556", bezeichnung: "Elektrische Anlagen"),
                        DIN276BaumKnoten(nummer: "557", bezeichnung: "Kommunikations-, Sicherheits-, Informationstechnik und Automation"),
                        DIN276BaumKnoten(nummer: "558", bezeichnung: "Nutzungsspezifische Anlagen"),
                        DIN276BaumKnoten(nummer: "559", bezeichnung: "Technische Anlagen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "560",
                    bezeichnung: "Einbauten in Außenanlagen und Freiflächen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "561", bezeichnung: "Allgemeine Einbauten"),
                        DIN276BaumKnoten(nummer: "562", bezeichnung: "Besondere Einbauten"),
                        DIN276BaumKnoten(nummer: "563", bezeichnung: "Ausstattung von Freiflächen"),
                        DIN276BaumKnoten(nummer: "564", bezeichnung: "Spiel- und Sportgeräte"),
                        DIN276BaumKnoten(nummer: "565", bezeichnung: "Orientierungs- und Informationssysteme"),
                        DIN276BaumKnoten(nummer: "569", bezeichnung: "Einbauten in Außenanlagen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "570",
                    bezeichnung: "Vegetationsflächen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "571", bezeichnung: "Oberboden und Pflanzflächen"),
                        DIN276BaumKnoten(nummer: "572", bezeichnung: "Rasen- und Wiesenflächen"),
                        DIN276BaumKnoten(nummer: "573", bezeichnung: "Pflanzungen"),
                        DIN276BaumKnoten(nummer: "574", bezeichnung: "Vegetationstechnische Arbeiten"),
                        DIN276BaumKnoten(nummer: "579", bezeichnung: "Vegetationsflächen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "580",
                    bezeichnung: "Wasserflächen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "581", bezeichnung: "Teiche und Wasserbecken"),
                        DIN276BaumKnoten(nummer: "582", bezeichnung: "Wasserläufe"),
                        DIN276BaumKnoten(nummer: "583", bezeichnung: "Wassertechnische Ausstattung"),
                        DIN276BaumKnoten(nummer: "589", bezeichnung: "Wasserflächen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "590",
                    bezeichnung: "Sonstige Maßnahmen für Außenanlagen und Freiflächen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "591", bezeichnung: "Baustelleneinrichtung"),
                        DIN276BaumKnoten(nummer: "592", bezeichnung: "Gerüste"),
                        DIN276BaumKnoten(nummer: "593", bezeichnung: "Sicherungsmaßnahmen"),
                        DIN276BaumKnoten(nummer: "594", bezeichnung: "Abbruchmaßnahmen"),
                        DIN276BaumKnoten(nummer: "595", bezeichnung: "Instandsetzung"),
                        DIN276BaumKnoten(nummer: "596", bezeichnung: "Materialentsorgung"),
                        DIN276BaumKnoten(nummer: "597", bezeichnung: "Schlechtwetterbau"),
                        DIN276BaumKnoten(nummer: "598", bezeichnung: "Provisorische Außenanlagen und Freiflächen"),
                        DIN276BaumKnoten(nummer: "599", bezeichnung: "Sonstiges")
                    ]
                )
            ]
        ),
        DIN276BaumKnoten(
            nummer: "600",
            bezeichnung: "Ausstattung und Kunstwerke",
            kinder: [
                DIN276BaumKnoten(nummer: "610", bezeichnung: "Allgemeine Ausstattung"),
                DIN276BaumKnoten(nummer: "620", bezeichnung: "Besondere Ausstattung"),
                DIN276BaumKnoten(nummer: "630", bezeichnung: "Informationstechnische Ausstattung"),
                DIN276BaumKnoten(
                    nummer: "640",
                    bezeichnung: "Künstlerische Ausstattung",
                    kinder: [
                        DIN276BaumKnoten(nummer: "641", bezeichnung: "Kunstobjekte"),
                        DIN276BaumKnoten(nummer: "642", bezeichnung: "Künstlerische Gestaltung des Bauwerks"),
                        DIN276BaumKnoten(nummer: "643", bezeichnung: "Künstlerische Gestaltung der Außenanlagen und Freiflächen"),
                        DIN276BaumKnoten(nummer: "644", bezeichnung: "Künstlerische Ausstattung, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(nummer: "690", bezeichnung: "Sonstige Ausstattung")
            ]
        ),
        DIN276BaumKnoten(
            nummer: "700",
            bezeichnung: "Baunebenkosten",
            kinder: [
                DIN276BaumKnoten(
                    nummer: "710",
                    bezeichnung: "Bauherrenaufgaben",
                    kinder: [
                        DIN276BaumKnoten(nummer: "711", bezeichnung: "Projektleitung"),
                        DIN276BaumKnoten(nummer: "712", bezeichnung: "Bedarfsplanung"),
                        DIN276BaumKnoten(nummer: "713", bezeichnung: "Projektsteuerung"),
                        DIN276BaumKnoten(nummer: "714", bezeichnung: "Sicherheits- und Gesundheitsschutzkoordination"),
                        DIN276BaumKnoten(nummer: "715", bezeichnung: "Vergabeverfahren"),
                        DIN276BaumKnoten(nummer: "719", bezeichnung: "Bauherrenaufgaben, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "720",
                    bezeichnung: "Vorbereitung der Objektplanung",
                    kinder: [
                        DIN276BaumKnoten(nummer: "721", bezeichnung: "Untersuchungen"),
                        DIN276BaumKnoten(nummer: "722", bezeichnung: "Wertermittlung"),
                        DIN276BaumKnoten(nummer: "723", bezeichnung: "Städtebauliche Leistungen"),
                        DIN276BaumKnoten(nummer: "724", bezeichnung: "Landschaftsplanerische Leistungen"),
                        DIN276BaumKnoten(nummer: "725", bezeichnung: "Wettbewerbe"),
                        DIN276BaumKnoten(nummer: "729", bezeichnung: "Vorbereitung der Objektplanung, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "730",
                    bezeichnung: "Objektplanung",
                    kinder: [
                        DIN276BaumKnoten(nummer: "731", bezeichnung: "Gebäude und Innenräume"),
                        DIN276BaumKnoten(nummer: "732", bezeichnung: "Freianlagen"),
                        DIN276BaumKnoten(nummer: "733", bezeichnung: "Ingenieurbauwerke"),
                        DIN276BaumKnoten(nummer: "734", bezeichnung: "Verkehrsanlagen"),
                        DIN276BaumKnoten(nummer: "739", bezeichnung: "Objektplanung, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "740",
                    bezeichnung: "Fachplanung",
                    kinder: [
                        DIN276BaumKnoten(nummer: "741", bezeichnung: "Tragwerksplanung"),
                        DIN276BaumKnoten(nummer: "742", bezeichnung: "Technische Ausrüstung"),
                        DIN276BaumKnoten(nummer: "743", bezeichnung: "Bauphysik"),
                        DIN276BaumKnoten(nummer: "744", bezeichnung: "Geotechnik"),
                        DIN276BaumKnoten(nummer: "745", bezeichnung: "Ingenieurvermessung"),
                        DIN276BaumKnoten(nummer: "746", bezeichnung: "Lichttechnik, Tageslichttechnik"),
                        DIN276BaumKnoten(nummer: "747", bezeichnung: "Brandschutz"),
                        DIN276BaumKnoten(nummer: "748", bezeichnung: "Altlasten, Kampfmittel, kulturhistorische Funde"),
                        DIN276BaumKnoten(nummer: "749", bezeichnung: "Fachplanung, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "750",
                    bezeichnung: "Künstlerische Leistungen",
                    kinder: [
                        DIN276BaumKnoten(nummer: "751", bezeichnung: "Kunstwettbewerbe"),
                        DIN276BaumKnoten(nummer: "752", bezeichnung: "Honorare"),
                        DIN276BaumKnoten(nummer: "759", bezeichnung: "Künstlerische Leistungen, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "760",
                    bezeichnung: "Allgemeine Baunebenkosten",
                    kinder: [
                        DIN276BaumKnoten(nummer: "761", bezeichnung: "Gutachten und Beratung"),
                        DIN276BaumKnoten(nummer: "762", bezeichnung: "Prüfungen, Genehmigungen, Abnahmen"),
                        DIN276BaumKnoten(nummer: "763", bezeichnung: "Bewirtschaftungskosten"),
                        DIN276BaumKnoten(nummer: "764", bezeichnung: "Bemusterungskosten"),
                        DIN276BaumKnoten(nummer: "765", bezeichnung: "Betriebskosten nach der Abnahme"),
                        DIN276BaumKnoten(nummer: "766", bezeichnung: "Versicherungen"),
                        DIN276BaumKnoten(nummer: "769", bezeichnung: "Allgemeine Baunebenkosten, Sonstiges")
                    ]
                ),
                DIN276BaumKnoten(
                    nummer: "790",
                    bezeichnung: "Sonstige Baunebenkosten",
                    kinder: [
                        DIN276BaumKnoten(nummer: "791", bezeichnung: "Bestandsdokumentation"),
                        DIN276BaumKnoten(nummer: "799", bezeichnung: "Sonstige Baunebenkosten")
                    ]
                )
            ]
        ),
        DIN276BaumKnoten(
            nummer: "800",
            bezeichnung: "Finanzierung",
            kinder: [
                DIN276BaumKnoten(nummer: "810", bezeichnung: "Finanzierungsnebenkosten"),
                DIN276BaumKnoten(nummer: "820", bezeichnung: "Fremdkapitalzinsen"),
                DIN276BaumKnoten(nummer: "830", bezeichnung: "Eigenkapitalzinsen"),
                DIN276BaumKnoten(nummer: "840", bezeichnung: "Bürgschaften"),
                DIN276BaumKnoten(nummer: "890", bezeichnung: "Sonstige Finanzierungskosten")
            ]
        )
    ]

    public static func knoten(mitNummer nummer: String) -> DIN276BaumKnoten? {
        func find(in knoten: [DIN276BaumKnoten]) -> DIN276BaumKnoten? {
            for eintrag in knoten {
                if eintrag.nummer == nummer {
                    return eintrag
                }
                if let treffer = find(in: eintrag.kinder) {
                    return treffer
                }
            }
            return nil
        }

        return find(in: hauptgruppen)
    }
}
