//
//  YtongBedarfTests.swift
//  Prüft die öffentlichen Ytong-Bedarfswerte + dass daraus Mauerwerks-Rezepte werden,
//  die der Auto-Match findet (Mengen aus dem Vordruck, Preis 0 → Stammdaten).
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct YtongBedarfTests {

    private let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @Test func tabelleIstSauber() {
        #expect(!YtongBedarf.werte.isEmpty)
        let dicken = YtongBedarf.werte.map(\.wanddickeMm)
        #expect(Set(dicken).count == dicken.count)            // keine Doppel-Wanddicke
        for z in YtongBedarf.werte {
            #expect(z.steineProM3 > 0)
            #expect(z.moertelKgProM3 > 0)
        }
        // Stichprobe gegen den Vordruck: 24 cm → 27,8 Steine / 12,0 kg
        let z24 = YtongBedarf.zeile(wanddickeMm: 240)
        #expect(z24?.steineProM3 == 27.8)
        #expect(z24?.moertelKgProM3 == 12.0)
    }

    @Test func rezeptHatSteinUndMoertel() {
        let z = YtongBedarf.zeile(wanddickeMm: 240)!
        let r = YtongBedarf.rezept(fuer: z)
        #expect(r.material.count == 2)
        #expect(r.geraet.isEmpty)
        let stein = r.material.first { $0.name.contains("Planstein") }
        #expect(stein?.mengeProEinheit == 27.8)
        #expect(stein?.einheit == "Stück")
        #expect(stein?.einzelpreis == 0)                       // Preis kommt aus Stammdaten
        let moertel = r.material.first { $0.name.contains("Dünnbettmörtel") }
        #expect(moertel?.mengeProEinheit == 12.0)
    }

    @Test @MainActor func seedingLegtBausteineAnDieAutoMatchFindet() throws {
        let n = YtongBedarf.seedIfNeeded(context: ctx)
        #expect(n == YtongBedarf.werte.count)

        // Eine importierte Position „Mauerwerk Ytong 24 cm" (m³) → Auto-Match schreibt Material
        let pos = LVPosition(context: ctx)
        pos.bezeichnung = "Mauerwerk Ytong 24 cm"
        pos.einheit = "m³"
        pos.menge = 10
        #expect(LeistungskatalogService.autoMatch(position: pos, in: ctx))
        #expect(pos.materialArray.contains { ($0.materialName ?? "").contains("Planstein") })
        #expect(pos.materialArray.contains { ($0.materialName ?? "").contains("Dünnbettmörtel") })
    }

    @Test @MainActor func seedingIstIdempotentUndUeberschreibtLohnNicht() throws {
        _ = YtongBedarf.seedIfNeeded(context: ctx)
        // Prof/Katalog setzt später einen Aufwandswert an dem Baustein
        let baustein = try #require(LeistungskatalogService.finde(leistung: "Mauerwerk Ytong 24 cm", einheit: "m³", in: ctx))
        baustein.maurerStunden = 1.2
        try ctx.save()
        // Nochmal seeden → Lohn bleibt erhalten, kein Doppel-Baustein
        _ = YtongBedarf.seedIfNeeded(context: ctx)
        let wieder = try #require(LeistungskatalogService.finde(leistung: "Mauerwerk Ytong 24 cm", einheit: "m³", in: ctx))
        #expect(wieder.maurerStunden == 1.2)
        let req: NSFetchRequest<Leistungsbaustein> = Leistungsbaustein.fetchRequest()
        req.predicate = NSPredicate(format: "leistung == %@", "Mauerwerk Ytong 24 cm")
        #expect((try ctx.fetch(req)).count == 1)
    }
}
