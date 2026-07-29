import Foundation

/// Ordnet Materialnamen/Bauteilbezeichnungen automatisch einer DIN-276-Kostengruppe zu.
/// Grundlage: Keyword-Tabelle; längster/spezifischster Treffer gewinnt.
struct KGZuordnungsService {

    static let shared = KGZuordnungsService()

    // MARK: - Keyword → KG-Nummer Tabelle

    private let regeln: [(keywords: [String], kg: String)] = [

        // KG 311 – Baugrubenherstellung
        (["bagger", "aushub", "erdaushub", "graben", "baugrube"], "311"),

        // KG 320 – Gründung
        (["fundament", "bodenplatte", "streifenfundament", "sauberkeitsschicht", "magerbeton"], "322"),
        (["tiefgründung", "pfahlgründung", "pfahl", "bohrpfahl"], "323"),

        // KG 324 – Gründungsbeläge (Schüttung/Unterboden im Bodenaufbau über der Gründung)
        (["unterboden", "schüttung", "kiesschüttung"], "324"),

        // KG 325 – Abdichtungen und Bekleidungen
        // (war 326: das hieß in der alten Fassung „Bauwerksabdichtungen", heute „Dränagen")
        (["abdichtung", "bitumenbahn", "folie", "dampfsperre", "dichtschlämme", "perimeterdämmung"], "325"),

        // KG 331 – Tragende Außenwände
        (["ytong", "poroton", "kalksandstein", "klinker", "außenwand", "aussenwand",
          "mauerwerk außen", "mauerwerk aussen", "ziegelwand"], "331"),

        // KG 332 – Nichttragende Außenwände
        (["vorhangfassade", "fassadenelement", "sandwich", "pfosten-riegel"], "332"),

        // KG 333 – Außenstützen
        (["außenstütze", "aussenstütze", "betonstütze außen"], "333"),

        // KG 334 – Außentüren und -fenster
        (["fenster", "außentür", "aussentür", "haustür", "haustuere", "glasfassade",
          "verglasung", "schaufenster", "rolltor", "sektionaltor"], "334"),

        // KG 335 – Außenwandbekleidung außen
        (["fassadenputz", "wärmedämmverbundsystem", "wdvs", "dämmplatten außen",
          "außenputz", "aussenputz", "fassadenfarbe"], "335"),

        // KG 336 – Außenwandbekleidung innen
        (["innenputz außenwand", "innenschale"], "336"),

        // KG 341 – Tragende Innenwände
        (["tragende innenwand", "tragendes mauerwerk", "stahlbetonwand", "betonwand",
          "mauermörtel", "mörtelbett"], "341"),

        // KG 342 – Nichttragende Innenwände
        (["trennwand", "gipskarton", "gkb", "gkbi", "rigips", "knauf", "fermacell",
          "trockenbau", "ständerwerk", "metallständer", "cw-profil", "uw-profil"], "342"),

        // KG 344 – Innentüren
        (["innentür", "innentüre", "zimmertür", "schiebetür", "glastür innen"], "344"),

        // KG 345 – Innenwandbekleidungen
        (["fliesen wand", "wandfliesen", "wandbelag", "wandputz", "innenputz",
          "tapete", "wandfarbe", "kachel"], "345"),

        // KG 351 – Deckenkonstruktionen
        (["decke", "stahlbetondecke", "hohlkörperdecke", "filigrandecke",
          "holzbalkendecke", "brettstapeldecke"], "351"),

        // KG 353 – Deckenbeläge (Fußbodenaufbau)
        // (war 352: das hieß in der alten Fassung „Deckenbeläge", heute „Deckenöffnungen")
        (["estrich", "calciumsulfatestrich", "zementestrich", "heizestrich",
          "fußboden", "bodenbelag", "parkett", "laminat", "vinyl", "fliesen boden",
          "bodenfliesen", "teppich", "korkboden"], "353"),

        // KG 354 – Deckenbekleidungen (von unten: Unterdecke, Deckenputz)
        // (war 353: das heißt heute „Deckenbeläge" — also der Fußboden darüber)
        (["abgehängte decke", "abgehaengte decke", "unterdecke", "akustikdecke",
          "deckenpaneel", "deckenputz"], "354"),

        // KG 361 – Dachkonstruktion
        (["dachstuhl", "sparren", "pfette", "dachbalken", "kehlbalken",
          "dachkonstruktion", "holzdach"], "361"),

        // KG 362 – Dachfenster
        (["dachfenster", "lichtkuppel", "rooflite", "velux"], "362"),

        // KG 363 – Dachbelag
        (["dachziegel", "dachdeckung", "dachpfanne", "falzziegel", "bitumenschindel",
          "dachpappe", "trapezblech", "dachblech", "metalldach", "flachdach",
          "dachfolie", "gründach", "extensivbegrünung"], "363"),

        // KG 364 – Dachbekleidung
        (["dämmung dach", "zwischensparrendämmung", "aufsparrendämmung",
          "dampfbremse dach", "untersparrendämmung"], "364"),

        // KG 411 – Abwasser
        (["abwasser", "kanalrohr", "schmutzwasser", "regenwasser", "kanalisation",
          "abflussrohr", "dn110", "dn150", "dn200", "revisionsschacht"], "411"),

        // KG 412 – Wasser
        (["wasserleitung", "trinkwasser", "kaltwasser", "warmwasser", "kupferrohr",
          "verbundrohr", "mehrschichtverbundrohr", "pex-rohr", "armaturen",
          "absperrventil", "wasserzähler", "druckerhöhung"], "412"),

        // KG 413 – Gas
        (["gasleitung", "gasleitungen", "gasrohr", "gasanschluss", "gashahn"], "413"),

        // KG 421 – Heizung
        (["heizung", "heizkörper", "heizkessel", "brenner", "wärmepumpe",
          "fußbodenheizung", "flächenheizung", "pelletheizung", "gasheizung",
          "ölheizung", "fernwärme", "pufferspeicher", "ausdehnungsgefäß"], "421"),

        // KG 431 – Lüftung
        (["lüftung", "lüftungsanlage", "zuluft", "abluft", "wärmerückgewinnung",
          "lüftungskanal", "lüftungsrohr", "ventilator", "gebläse"], "431"),

        // KG 433 – Klimaanlage
        (["klima", "klimaanlage", "split-klimaanlage", "kühlung", "vrf"], "433"),

        // KG 443 – Niederspannungsanlagen (Hausanschluss, Zählerplatz, Hauptverteilung)
        // War 441 „Hoch- und Mittelspannungsanlagen" — das ist Trafostation/Mittelspannung,
        // nicht der Hausanschluss. Kein Editions-Thema: 441 heißt in beiden DIN-276-Fassungen
        // gleich, nur der Kommentar behauptete „Elektrounterverteilung".
        // „zähler" trifft auch „wasserzähler" — dort gewinnt der längere Treffer (→ 412),
        // die Regel bleibt also unberührt.
        (["hauptverteiler", "zähler", "hak", "zählerkasten", "netzanschluss"], "443"),

        // KG 444 – Elektroinstallation
        (["elektro", "elektroinstallation", "kabel", "leitung", "nyl",
          "unterputzdose", "aufputzdose", "schalterdose", "leerrohre", "kabelkanal",
          "netzwerkdose", "datenkabel", "cat6", "cat7", "steckdose", "lichtschalter",
          "sicherungskasten", "unterverteiler", "leitungsschutzschalter", "fi-schutzschalter"], "444"),

        // KG 445 – Beleuchtung
        (["leuchte", "beleuchtung", "led", "lampe", "downlight", "strahler",
          "außenleuchte", "notbeleuchtung", "flutlicht"], "445"),

        // KG 446 – Blitzschutz
        (["blitzschutz", "erdung", "potentialausgleich", "erdungsleitung"], "446"),

        // KG 461 – Aufzug
        (["aufzug", "lift", "fahrstuhl", "aufzugsschacht", "hebeanlage"], "461"),

        // KG 531 – Wege
        // (die alte Fassung nannte 531 „Wege und Plätze"; heute sind Plätze/Höfe/
        //  Terrassen eigenständig auf 533 — Terrassen daher unten abgetrennt)
        (["pflaster", "pflasterstein", "gehweg", "gehwegplatten", "betonpflaster",
          "natursteinpflaster"], "531"),

        // KG 532 – Straßen
        (["asphalt", "teerdecke", "fahrbahnbelag", "zufahrtsstraße", "schotter"], "532"),

        // KG 533 – Plätze, Höfe, Terrassen
        // Längster Treffer gewinnt: „terrassenpflaster" schlägt „pflaster" → 533, nicht 531.
        (["terrassenplatten", "terrassenpflaster", "hoffläche", "platzfläche"], "533"),

        // KG 534 – Stellplätze
        // (war 533: das hieß in der alten Fassung „Stellplätze", heute „Plätze, Höfe, Terrassen")
        (["parkplatz", "stellplatz", "carport", "garage", "tiefgarage"], "534"),

        // KG 541 – Einfriedungen
        (["zaun", "tor", "einfriedung", "maschendraht", "staketenzaun", "sichtschutzzaun"], "541"),

        // KG 543 – Wandkonstruktionen (Stützmauern). Der Kommentar sagte vorher 542,
        // der Wert war schon immer 543 — nur die Beschriftung war falsch.
        (["stützmauer", "gabione", "böschungssicherung", "hang"], "543"),

        // KG 573 – Pflanzungen
        (["bepflanzung", "baum", "strauch", "hecke", "beet", "pflanzen"], "573"),

        // KG 572 – Rasen- und Wiesenflächen
        // (war 574: das hieß „Rasen- und Saatflächen", heute „Vegetationstechnische Arbeiten")
        (["rasen", "rollrasen", "ansaat", "rasenansaat"], "572"),
    ]

    // MARK: - Zuordnung

    /// Gibt die KG-Nummer zurück, die am besten zum Materialnamen passt.
    /// Priorität: längster Keyword-Treffer (spezifischster Match) gewinnt.
    func ordneZu(materialName: String) -> String? {
        let lower = materialName.lowercased()

        var besterTreffer: (kg: String, keywordLength: Int)?

        for regel in regeln {
            for keyword in regel.keywords {
                if lower.contains(keyword) {
                    let len = keyword.count
                    if besterTreffer == nil || len > besterTreffer!.keywordLength {
                        besterTreffer = (regel.kg, len)
                    }
                }
            }
        }

        return besterTreffer?.kg
    }

    /// Gibt die vollständige KostenGruppe zurück (Nummer + Bezeichnung).
    func kostenGruppeZu(materialName: String) -> DIN276KostenGruppe? {
        guard let nummer = ordneZu(materialName: materialName) else { return nil }
        return DIN276KostenGruppe.alle.first { $0.nummer == nummer }
    }
}
