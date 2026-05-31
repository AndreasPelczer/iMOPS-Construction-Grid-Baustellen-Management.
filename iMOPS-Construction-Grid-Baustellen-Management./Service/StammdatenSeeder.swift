import Foundation
import CoreData

// MARK: - StammdatenSeeder
// Legt Standard-Lohnsaetze und haeufig gebrauchte Materialien an,
// wenn die Datenbank noch leer ist. Wird einmalig beim ersten Start gerufen.
enum StammdatenSeeder {

    static func seedIfNeeded(context: NSManagedObjectContext) {
        seedLohnsaetze(context: context)
        seedMaterialien(context: context)
        seedGeraete(context: context)
    }

    // MARK: - Lohnsaetze (Bau-Tarif Orientierung)

    private static func seedLohnsaetze(context: NSManagedObjectContext) {
        let req: NSFetchRequest<Lohnsatz> = Lohnsatz.fetchRequest()
        let count = (try? context.count(for: req)) ?? 0
        guard count == 0 else { return }

        let daten: [(String, Double, Double)] = [
            ("Polier",       32.00, 1.75),
            ("Maurer",       28.50, 1.65),
            ("Zimmerer",     29.00, 1.65),
            ("Betonbauer",   28.00, 1.65),
            ("Helfer",       18.50, 1.55),
            ("Maschinenf.",  30.00, 1.70),
        ]

        for (quali, lohn, faktor) in daten {
            let ls = Lohnsatz(context: context)
            ls.id = UUID()
            ls.qualifikation = quali
            ls.stundenlohn = lohn
            ls.zuschlagFaktor = faktor
        }

        try? context.save()
    }

    // MARK: - Standard-Materialien

    private static func seedMaterialien(context: NSManagedObjectContext) {
        let req: NSFetchRequest<KalkMaterial> = KalkMaterial.fetchRequest()
        let count = (try? context.count(for: req)) ?? 0
        guard count == 0 else { return }

        let daten: [(String, String, Double, Double, Double)] = [
            // (Name, Einheit, Preis/E, Verbrauch/m², Verschnitt%)
            ("HLZ 12 NF",           "Stk",  0.65, 32.0,  0.05),
            ("Planstein 36,5cm",    "Stk",  3.20, 16.0,  0.03),
            ("Porenbeton PP2 30cm", "Stk",  4.50, 8.0,   0.03),
            ("Mauermörtel M5",      "kg",   0.12, 25.0,  0.10),
            ("Dünnbettmörtel",      "kg",   0.45, 3.5,   0.08),
            ("Beton C25/30",        "m³", 95.00,  0.0,   0.05),
            ("Bewehrungsstahl",     "kg",   1.20, 0.0,   0.08),
            ("Schalungsplatte",     "m²",   8.50, 0.0,   0.15),
            ("Dachziegel Braas",    "Stk",  1.40, 12.0,  0.05),
            ("Dachlatte 30×50",     "lfm",  1.80, 3.3,   0.10),
            ("KVH 60×120",          "lfm",  5.50, 0.0,   0.08),
            ("OSB 18mm",            "m²",  12.00, 0.0,   0.10),
            ("Mineralwolle 160mm",  "m²",  18.00, 0.0,   0.05),
            ("Dampfsperre",         "m²",   3.50, 0.0,   0.15),
        ]

        for (name, einheit, preis, verbrauch, verschnitt) in daten {
            let m = KalkMaterial(context: context)
            m.id = UUID()
            m.name = name
            m.einheit = einheit
            m.preisProEinheit = preis
            m.verbrauchProM2 = verbrauch
            m.verschnittProzent = verschnitt
            m.letzteAktualisierung = Date()
            m.quelleRaw = "manuell"
        }

        try? context.save()
    }

    // MARK: - Standard-Geraete

    private static func seedGeraete(context: NSManagedObjectContext) {
        let req: NSFetchRequest<Geraet> = Geraet.fetchRequest()
        let count = (try? context.count(for: req)) ?? 0
        guard count == 0 else { return }

        let daten: [(String, Double, Int32)] = [
            // (Name, Anschaffung, Nutzungsdauer in Stunden)
            ("Betonmischer 90l",       1200.0,  2000),
            ("Rüttler / Verdichter",   3500.0,  3000),
            ("Kran (Tagesmiete)",       450.0,     8),
            ("Bagger 3t (Tagesmiete)", 350.0,     8),
            ("Mörtelschlitten",         180.0,  5000),
            ("Flex / Trennschleifer",   250.0,  1500),
        ]

        for (name, kosten, stunden) in daten {
            let g = Geraet(context: context)
            g.id = UUID()
            g.name = name
            g.anschaffungsKosten = kosten
            g.nutzungsdauerStunden = stunden
        }

        try? context.save()
    }
}
