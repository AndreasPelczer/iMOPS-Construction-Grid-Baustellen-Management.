import Foundation

struct LVBausteinTitel: Identifiable, Hashable {
    let nummer: String
    let bezeichnung: String
    let positionen: [LVBausteinPosition]

    var id: String { nummer }
    var anzeige: String { "\(nummer) \(bezeichnung)" }
}

struct LVBausteinPosition: Identifiable, Hashable {
    let posNr: String
    let bezeichnung: String
    let menge: Double
    let einheit: String
    let einzelPreis: Double
    let kostenGruppeNummer: String

    var id: String { posNr }
}

enum LVBausteinKatalog {
    static let titel: [LVBausteinTitel] = [
        LVBausteinTitel(
            nummer: "01",
            bezeichnung: "Baustelleneinrichtung",
            positionen: [
                LVBausteinPosition(
                    posNr: "01.0010",
                    bezeichnung: "An-/Abfuhr, sowie Vorhaltung aller benötigten Werkzeuge/Maschinen etc.",
                    menge: 1,
                    einheit: "Pau",
                    einzelPreis: 751.30,
                    kostenGruppeNummer: "390"
                ),
                LVBausteinPosition(
                    posNr: "01.0020",
                    bezeichnung: "Chemische Toilette (Mindestmietzeit 4 Wochen)",
                    menge: 4,
                    einheit: "Wo",
                    einzelPreis: 41.18,
                    kostenGruppeNummer: "390"
                ),
                LVBausteinPosition(
                    posNr: "01.0030",
                    bezeichnung: "Bauzaun, Stahlrahmen (mobil), h=2,00 m aufstellen und später wieder abbauen",
                    menge: 9,
                    einheit: "m",
                    einzelPreis: 10.44,
                    kostenGruppeNummer: "390"
                ),
                LVBausteinPosition(
                    posNr: "01.0040",
                    bezeichnung: "Bauzaun Verlängerung je Woche und Meter",
                    menge: 36,
                    einheit: "m*W",
                    einzelPreis: 0.63,
                    kostenGruppeNummer: "390"
                )
            ]
        ),
        LVBausteinTitel(
            nummer: "02",
            bezeichnung: "Allgemein",
            positionen: [
                LVBausteinPosition(
                    posNr: "02.0010",
                    bezeichnung: "Mutterboden abtragen und seitlich lagern",
                    menge: 60,
                    einheit: "m3",
                    einzelPreis: 15.75,
                    kostenGruppeNummer: "310"
                ),
                LVBausteinPosition(
                    posNr: "02.0020",
                    bezeichnung: "Mutterboden abtragen und seitlich lagern, im Vertrag enthalten",
                    menge: -44.917,
                    einheit: "m3",
                    einzelPreis: 15.75,
                    kostenGruppeNummer: "310"
                ),
                LVBausteinPosition(
                    posNr: "02.0030",
                    bezeichnung: "Schnurgerüst Konstruktion erstellen, ohne Vermessung",
                    menge: 1,
                    einheit: "Pau",
                    einzelPreis: 781.26,
                    kostenGruppeNummer: "390"
                ),
                LVBausteinPosition(
                    posNr: "02.0040",
                    bezeichnung: "Bauwasseranschluss - durch Bauherrschaft",
                    menge: 1,
                    einheit: "Pau",
                    einzelPreis: 0,
                    kostenGruppeNummer: "390"
                ),
                LVBausteinPosition(
                    posNr: "02.0050",
                    bezeichnung: "Baustromanschluss - durch Bauherrschaft",
                    menge: 1,
                    einheit: "Pau",
                    einzelPreis: 0,
                    kostenGruppeNummer: "390"
                )
            ]
        ),
        LVBausteinTitel(
            nummer: "03",
            bezeichnung: "Erdarbeiten",
            positionen: []
        ),
        LVBausteinTitel(
            nummer: "04",
            bezeichnung: "Entwässerung und Grundleitungen",
            positionen: []
        ),
        LVBausteinTitel(
            nummer: "05",
            bezeichnung: "Fundamente und Bodenplatte",
            positionen: []
        ),
        LVBausteinTitel(
            nummer: "06",
            bezeichnung: "Mauerarbeiten",
            positionen: []
        ),
        LVBausteinTitel(
            nummer: "07",
            bezeichnung: "Beton- und Stahlbetonarbeiten",
            positionen: []
        ),
        LVBausteinTitel(
            nummer: "08",
            bezeichnung: "Dach- und Zimmererarbeiten",
            positionen: []
        ),
        LVBausteinTitel(
            nummer: "09",
            bezeichnung: "Abdichtung und Dämmung",
            positionen: []
        ),
        LVBausteinTitel(
            nummer: "10",
            bezeichnung: "Fenster, Türen und Öffnungen",
            positionen: []
        ),
        LVBausteinTitel(
            nummer: "11",
            bezeichnung: "Innenausbau",
            positionen: []
        ),
        LVBausteinTitel(
            nummer: "12",
            bezeichnung: "Putz, Estrich und Oberflächen",
            positionen: []
        ),
        LVBausteinTitel(
            nummer: "13",
            bezeichnung: "Technische Anlagen",
            positionen: []
        ),
        LVBausteinTitel(
            nummer: "14",
            bezeichnung: "Außenanlagen",
            positionen: []
        ),
        LVBausteinTitel(
            nummer: "99",
            bezeichnung: "Sonstiges",
            positionen: []
        )
    ]
}
