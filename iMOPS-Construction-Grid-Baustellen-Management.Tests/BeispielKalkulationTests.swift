import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

/// Haelt das vollstaendig kalkulierte Beispiel-LV fest: alle 15 Eigenleistungs-Positionen
/// (Gruendung, Waende, Decken, Dach, Elektro) haben Material, Lohn und teils Geraet.
/// Vorher standen 8 davon auf 0,00 €, die anderen 7 kamen einen Schritt vorher dazu.
///
/// Die Tests pruefen NICHT, ob die Aufwandswerte richtig sind (das kann nur ein Polier),
/// sondern dass sie ankommen, sich nicht verdoppeln und die Summe bewegen.
struct BeispielKalkulationTests {

    @MainActor
    private static let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { Self.controller.container.viewContext }

    /// Baut die Beispiel-Baustelle GENAU EINMAL auf (Stammdaten -> LV -> Kalkulation).
    ///
    /// Zwei Fallstricke, die hier bewusst abgefangen sind:
    /// 1. `MarktbreitSeeder` haengt an einem UserDefaults-Flag. Im Test-Host steht das
    ///    schon auf true, der Seeder wuerde also nichts anlegen und alle Tests haetten
    ///    keine Positionen. Darum vorher loeschen.
    /// 2. Swift Testing laesst Tests parallel laufen. Ein `static let` wird garantiert
    ///    nur einmal ausgewertet — damit teilen sich alle Tests denselben Aufbau, statt
    ///    sich gegenseitig mitten ins Seeden zu fahren.
    @MainActor
    private static let aufgebaut: Bool = {
        UserDefaults.standard.removeObject(forKey: "marktbreit_efh_beispiel_seeded_v5")
        let ctx = controller.container.viewContext
        StammdatenSeeder.seedIfNeeded(context: ctx)
        MarktbreitSeeder.seedIfNeeded(context: ctx)
        BeispielKalkulationSeeder.seedIfNeeded(context: ctx)
        return true
    }()

    @MainActor
    private func seedeAlles() { _ = Self.aufgebaut }

    @MainActor
    private func position(_ posNr: String) -> LVPosition? {
        let req: NSFetchRequest<LVPosition> = LVPosition.fetchRequest()
        req.predicate = NSPredicate(format: "posNr == %@", posNr)
        return try? ctx.fetch(req).first
    }

    /// Alle 15 Eigenleistungs-Positionen haben jetzt einen Preis > 0. Die uebrigen 9
    /// sind NU-Pauschalen und werden bewusst nicht aufgerechnet.
    @Test @MainActor func alleEigenleistungenSindNichtMehrNull() {
        seedeAlles()

        let eigenleistung = ["3.20.1", "3.20.2", "3.20.3",
                             "3.30.1", "3.30.2", "3.30.2b", "3.30.3", "3.40.1",
                             "3.50.1", "3.50.2", "3.50.3",
                             "3.60.1", "3.60.2", "3.60.3", "4.40.1"]
        for nr in eigenleistung {
            guard let pos = position(nr) else {
                Issue.record("Position \(nr) fehlt — MarktbreitSeeder geaendert?")
                continue
            }
            #expect(pos.hatKalkulation, "\(nr) hat keine Kalkulation")
            #expect(LVKalkulator.effektiverEP(for: pos) > 0, "\(nr) rechnet auf 0")
        }
    }

    /// KEINE Position im Beispiel steht mehr auf 0,00 EUR — weder Eigenleistung noch
    /// NU-Pauschale. Das ist die Zusage "vollstaendiges Beispiel-LV" als Test.
    @Test @MainActor func keinePositionMehrOhnePreis() {
        seedeAlles()
        let req: NSFetchRequest<LVPosition> = LVPosition.fetchRequest()
        let alle = (try? ctx.fetch(req)) ?? []
        let ohnePreis = alle.zaehlbarePositionen()
            .filter { LVKalkulator.effektiverEP(for: $0) <= 0 }
            .compactMap(\.posNr)
        #expect(ohnePreis.isEmpty, "Ohne Preis: \(ohnePreis.sorted())")
    }

    /// Die dickere Kelleraussenwand (36,5 cm) muss teurer sein als die 24er — mehr Stein,
    /// mehr Moertel, hoeherer Aufwandswert. Genau der Unterschied, den die Statik-Notiz
    /// als Stolperstein markiert; wenn der im Preis verschwindet, stimmt das Rezept nicht.
    @Test @MainActor func dickereKellerwandIstTeurer() {
        seedeAlles()
        guard let duenn = position("3.30.2"), let dick = position("3.30.2b") else {
            Issue.record("Kellerwand-Positionen fehlen"); return
        }
        #expect(LVKalkulator.effektiverEP(for: dick) > LVKalkulator.effektiverEP(for: duenn))
    }

    /// Dacheindeckung: Ziegel + Lattung + Unterspannbahn, Zimmerer und Helfer.
    /// Der EP muss in einer Groessenordnung liegen, die auf einem Dach vorkommt —
    /// grosszuegige Schranken, weil hier NICHT die Richtigkeit geprueft wird.
    @Test @MainActor func dacheindeckungLiegtInPlausiblerGroessenordnung() {
        seedeAlles()
        guard let pos = position("3.60.2") else { Issue.record("3.60.2 fehlt"); return }

        let ep = LVKalkulator.effektiverEP(for: pos)
        #expect(ep > 40, "Dacheindeckung unter 40 €/m² — Material verloren?")
        #expect(ep < 250, "Dacheindeckung ueber 250 €/m² — Faktor verrutscht?")
        #expect(pos.einheit == "m²")
    }

    /// Geschaetzt ist ein anderer Zustand als gemessen — die Positionen sagen das auch.
    @Test @MainActor func kalkuliertePositionenSindAlsSchaetzungMarkiert() {
        seedeAlles()
        guard let pos = position("3.50.1") else { Issue.record("3.50.1 fehlt"); return }
        #expect(pos.istGeschaetzt)
    }

    /// Zweimal seeden darf nichts verdoppeln — sonst waechst das Beispiel bei jedem
    /// App-Start und die Preise mit ihm.
    @Test @MainActor func zweitesSeedenVerdoppeltNichts() {
        seedeAlles()
        guard let pos = position("3.60.3") else { Issue.record("3.60.3 fehlt"); return }
        let materialVorher = pos.materialArray.count
        let lohnVorher = pos.lohnArray.count
        let epVorher = LVKalkulator.effektiverEP(for: pos)

        BeispielKalkulationSeeder.seedIfNeeded(context: ctx)

        #expect(pos.materialArray.count == materialVorher)
        #expect(pos.lohnArray.count == lohnVorher)
        #expect(abs(LVKalkulator.effektiverEP(for: pos) - epVorher) < 0.001)
    }

    /// Zwei Beispiel-Mitarbeiter fuer die Crew-Planung, und auch die nur einmal.
    @Test @MainActor func zweiMitarbeiterGenauEinmal() {
        seedeAlles()
        BeispielKalkulationSeeder.seedIfNeeded(context: ctx)

        let req: NSFetchRequest<Employee> = Employee.fetchRequest()
        let alle = (try? ctx.fetch(req)) ?? []
        #expect(alle.count == 2)
        #expect(alle.allSatisfy { $0.isActive })
        #expect(alle.contains { $0.rolle == "Polier" })
    }

    /// Lohnstunden landen in der Summe — das ist die Zahl, aus der spaeter die
    /// Brigade-Planung kommt.
    @Test @MainActor func beispielHatJetztLohnstunden() {
        seedeAlles()
        let req: NSFetchRequest<LVPosition> = LVPosition.fetchRequest()
        let alle = (try? ctx.fetch(req)) ?? []
        #expect(LVKalkulator.gesamtStunden(positionen: alle) > 0)
    }
}
