//
//  Baufragen.swift
//  Ein kleiner, handkuratierter Fragen-Seed für das Bau-Quiz (1. Lehrjahr, Tiefbau/
//  Baustelle) — das Bau-Gegenstück zum Kochquiz aus dem Ausbildungsspiel. Bewusst
//  knapp und ehrlich: nur Fragen mit klarer, belegbarer Antwort und kurzer Erklärung.
//
//  Kein DIN-Norm-Wortlaut kopiert — nur Sachverhalte/Werte (dieselbe Lizenz-Regel wie
//  in der Wissensbasis).
//

import Foundation

struct Baufrage: Identifiable, Codable, Equatable {
    let id: Int
    let thema: String
    let frage: String
    let antworten: [String]     // genau 4
    let richtige: Int           // Index 0…3
    let erklaerung: String

    var richtigeAntwort: String { antworten[richtige] }
}

enum Baufragen {

    /// Der Seed. Handkuratiert, 1. Lehrjahr Tiefbau/Baustelle.
    static let alle: [Baufrage] = [
        Baufrage(id: 1, thema: "Arbeitsschutz",
                 frage: "Ab welcher Grabentiefe muss ein Graben ohne Verbau in der Regel geböscht oder gesichert werden?",
                 antworten: ["ab 0,50 m", "ab 1,25 m", "ab 2,50 m", "erst ab 3,00 m"],
                 richtige: 1,
                 erklaerung: "Ab etwa 1,25 m Tiefe ist ein senkrechter Grabenverbau oder eine Böschung nötig — sonst droht Verschütten."),
        Baufrage(id: 2, thema: "Gründung",
                 frage: "Wie tief gründet man in Deutschland üblicherweise mindestens frostfrei?",
                 antworten: ["ca. 20 cm", "ca. 50 cm", "ca. 80 cm", "ca. 150 cm"],
                 richtige: 2,
                 erklaerung: "Rund 80 cm gelten als frostfreie Gründungstiefe — darüber kann Frost den Boden heben."),
        Baufrage(id: 3, thema: "Beton",
                 frage: "Was bedeutet die Bezeichnung C25/30 bei Beton?",
                 antworten: ["Zement/Sand-Verhältnis", "Druckfestigkeit Zylinder/Würfel in N/mm²",
                             "Alter in Tagen", "Körnung in mm"],
                 richtige: 1,
                 erklaerung: "C25/30: 25 N/mm² am Zylinder, 30 N/mm² am Würfel — die charakteristische Druckfestigkeit."),
        Baufrage(id: 4, thema: "Entwässerung",
                 frage: "Welches Regelgefälle plant man grob für eine gepflasterte Hofeinfahrt, damit Wasser abläuft?",
                 antworten: ["0 % (eben)", "ca. 2 %", "ca. 10 %", "ca. 25 %"],
                 richtige: 1,
                 erklaerung: "Rund 2 % (2 cm je Meter) reichen, damit Wasser sicher abläuft, ohne dass es unangenehm steil wird."),
        Baufrage(id: 5, thema: "Material",
                 frage: "Was sagt die Bezeichnung „Splitt 8/16“ aus?",
                 antworten: ["8 bis 16 Tonnen je Fuhre", "Körnung 8 bis 16 mm",
                             "8 % in 16 Lagen", "Festigkeit 8/16"],
                 richtige: 1,
                 erklaerung: "Die Zahlen sind die Korngrößen: Körner zwischen 8 und 16 mm."),
        Baufrage(id: 6, thema: "Material",
                 frage: "Wofür wird ein Trennvlies (Geotextil) im Wegebau eingebaut?",
                 antworten: ["als Dämmung gegen Kälte", "damit Unterbau und Boden sich nicht vermischen",
                             "als Wurzelsperre gegen Bäume", "als Dampfbremse"],
                 richtige: 1,
                 erklaerung: "Das Vlies trennt den Schotter vom Untergrund (Trenn-/Filterfunktion), damit der Unterbau tragfähig bleibt."),
        Baufrage(id: 7, thema: "Verdichtung",
                 frage: "Womit weist man auf der Baustelle die Tragfähigkeit einer verdichteten Schicht nach?",
                 antworten: ["mit der Wasserwaage", "mit dem Plattendruckversuch (Ev2)",
                             "mit dem Gliedermaßstab", "mit der Richtschnur"],
                 richtige: 1,
                 erklaerung: "Der Plattendruckversuch liefert den Ev2-Wert — ein Maß dafür, wie tragfähig die Schicht verdichtet ist."),
        Baufrage(id: 8, thema: "Erdbau",
                 frage: "Was ist der „Mutterboden“ (Oberboden), der zuerst abgetragen wird?",
                 antworten: ["der tragfähige Baugrund", "die oberste, humusreiche Bodenschicht",
                             "verdichteter Schotter", "Beton-Unterbau"],
                 richtige: 1,
                 erklaerung: "Oberboden ist die humusreiche oberste Schicht — sie ist nicht tragfähig und wird abgetragen und gelagert."),
        Baufrage(id: 9, thema: "Baustelle",
                 frage: "Was gehört zur persönlichen Schutzausrüstung (PSA) auf fast jeder Baustelle?",
                 antworten: ["nur Handschuhe", "Sicherheitsschuhe und Helm",
                             "eine Warnweste reicht immer", "Gehörschutz nur im Büro"],
                 richtige: 1,
                 erklaerung: "Sicherheitsschuhe und Kopfschutz sind Standard; je nach Tätigkeit kommen Gehör-, Augen- und Handschutz dazu."),
        Baufrage(id: 10, thema: "Vermessung",
                 frage: "Wozu dient die „Schnurgerüst“-Absteckung vor dem Aushub?",
                 antworten: ["zum Verdichten", "um Lage und Höhe des Bauwerks zu markieren",
                             "als Absturzsicherung", "zum Betonieren"],
                 richtige: 1,
                 erklaerung: "Das Schnurgerüst hält Fluchten und Höhen fest, damit nach dem Aushub Lage und Maße stimmen."),
        Baufrage(id: 11, thema: "Reihenfolge",
                 frage: "Welche Reihenfolge stimmt beim Pflastern einer Hofeinfahrt?",
                 antworten: ["Pflaster → Schotter → Aushub", "Aushub → Schotter/Unterbau → Pflaster",
                             "Schotter → Aushub → Pflaster", "Pflaster → Aushub → Schotter"],
                 richtige: 1,
                 erklaerung: "Erst der Aushub, dann der tragfähige Unterbau (Schotter, verdichtet), zuletzt die Pflasterdecke — von unten nach oben."),
        Baufrage(id: 12, thema: "Böschung",
                 frage: "Warum böscht man die Wände einer tiefen Baugrube ab, statt sie senkrecht zu lassen?",
                 antworten: ["damit es schöner aussieht", "damit die Erdwände nicht einstürzen",
                             "um Material zu sparen", "wegen des Frosts"],
                 richtige: 1,
                 erklaerung: "Eine Böschung im standsicheren Winkel verhindert, dass die Erdwände nachrutschen und jemanden verschütten."),
    ]

    /// Eine zufällige Runde von `anzahl` Fragen (gemischt, Antworten je Frage gemischt
    /// überlässt die View).
    static func runde(anzahl: Int = 5) -> [Baufrage] {
        Array(alle.shuffled().prefix(min(anzahl, alle.count)))
    }
}
