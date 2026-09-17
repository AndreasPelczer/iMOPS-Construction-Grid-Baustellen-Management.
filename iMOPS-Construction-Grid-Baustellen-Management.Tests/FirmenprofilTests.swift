//
//  FirmenprofilTests.swift
//  Umschalter Goldschmitt (echt) ↔ Mops (neutral): mit welchen Sätzen rechnet der Mops,
//  und zeigt der Vergleich beide Preise aus denselben Stunden?
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct FirmenprofilTests {

    private let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { controller.container.viewContext }

    /// Goldschmitts echten Facharbeiter-Satz (ZG1 = 74 €/h) in die Stammdaten legen.
    @MainActor private func seedGoldschmittFacharbeiter() {
        let l = Lohnsatz(context: ctx)
        l.id = UUID(); l.qualifikation = "Facharbeiter (Raphael)"
        l.stundenlohn = 26.91; l.zuschlagFaktor = 2.75   // → 74,00
    }

    @MainActor private func position(_ bez: String, _ einheit: String, menge: Double = 10) -> LVPosition {
        let p = LVPosition(context: ctx)
        p.bezeichnung = bez; p.einheit = einheit; p.menge = menge
        return p
    }

    @Test @MainActor func goldschmittFacharbeiterTeurerAlsMops() {
        seedGoldschmittFacharbeiter()
        let g = Firmenprofil.goldschmitt.satz(fuer: .facharbeiter, in: ctx)
        let m = Firmenprofil.mops.satz(fuer: .facharbeiter, in: ctx)
        #expect(abs(g - 74.0) < 0.01)          // Goldschmitts echter ZG1
        #expect(abs(m - 28.50 * 1.65) < 0.01)   // Mops neutral ~47,03
        #expect(g > m)
    }

    @Test @MainActor func lohnVergleichZeigtBeideProfile() {
        seedGoldschmittFacharbeiter()
        let pos = position("Rohrleger-Leistung", "m", menge: 100)
        // 1,0 h/m als 1 Rohrleger (Facharbeiter) über den Kolonnen-Schreiber
        LeistungskatalogService.schreibeAufwandAusKolonne(mittelStunden: 1.0, kolonne: "1 Rohrleger", auf: pos, in: ctx)
        let v = LeistungskatalogService.lohnVergleich(auf: pos, in: ctx)
        #expect(abs(v.goldschmitt - 74.0) < 0.01)          // 1 h × 74
        #expect(abs(v.mops - 47.025) < 0.01)    // 1 h × ~47
        #expect(v.goldschmitt > v.mops)
    }

    @Test @MainActor func aktivesProfilBestimmtGeschriebenenSatz() {
        seedGoldschmittFacharbeiter()
        let alt = Firmenprofil.aktiv
        defer { Firmenprofil.setzeAktiv(alt) }

        Firmenprofil.setzeAktiv(.goldschmitt)
        let posG = position("Rohrleger G", "m")
        LeistungskatalogService.schreibeAufwandAusKolonne(mittelStunden: 1.0, kolonne: "1 Rohrleger", auf: posG, in: ctx)
        #expect(abs((posG.lohnArray.first?.stundenBruttoEK ?? 0) - 74.0) < 0.01)

        Firmenprofil.setzeAktiv(.mops)
        let posM = position("Rohrleger M", "m")
        LeistungskatalogService.schreibeAufwandAusKolonne(mittelStunden: 1.0, kolonne: "1 Rohrleger", auf: posM, in: ctx)
        #expect(abs((posM.lohnArray.first?.stundenBruttoEK ?? 0) - 47.025) < 0.01)
    }

    /// Stundenlohn-/Regie-Position: „Facharbeiter" mit Einheit „h" → GELB, EP = Profil-Satz.
    @Test @MainActor func stundenlohnPositionWirdBepreist() {
        seedGoldschmittFacharbeiter()
        let alt = Firmenprofil.aktiv
        defer { Firmenprofil.setzeAktiv(alt) }
        Firmenprofil.setzeAktiv(.mops)

        let pos = position("Facharbeiter", "h", menge: 8)
        let e = AutoKalkulationsService.bewerte(pos, in: ctx)
        #expect(e.status == .gelb)
        #expect(e.meldungen.contains { $0.contains("Stundenlohn") })
        // 1 Lohnstunde je Einheit zum Mops-Facharbeiter-Satz (deterministisch, unabhängig
        // vom Firmen-Zuschlag, der in den VK-Preis eingeht).
        #expect(pos.lohnArray.count == 1)
        #expect(abs((pos.lohnArray.first?.stundenBruttoEK ?? 0) - 47.025) < 0.01)
        #expect(pos.lohnArray.first?.stunden == 1.0)
        #expect(e.einheitspreisVK > 0)
    }
}
