//
//  FirmaTransferTests.swift
//  „Die Firma" von einem Gerät aufs andere: Stammdaten + Firmensettings in eine Datei und
//  wieder zurück. Diese Tests halten den Round-Trip, den Upsert (kein Duplikat) und die
//  Firmensettings fest — damit Andreas' und Raphis App verlässlich dieselben Zahlen bekommen.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct FirmaTransferTests {

    @Test @MainActor func stammdatenRoundtripUeberZweiApps() throws {
        // App A: eine Firma mit echten Zahlen.
        let a = PersistenceController(inMemory: true); let ca = a.container.viewContext
        let m = KalkMaterial(context: ca)
        m.id = UUID(); m.name = "Schotter 0/32"; m.einheit = "t"
        m.preisProEinheit = 7.9; m.lieferant = "SHB Werbach"
        let l = Lohnsatz(context: ca)
        l.id = UUID(); l.qualifikation = "Facharbeiter"; l.stundenlohn = 38; l.zuschlagFaktor = 1.85
        let g = Geraet(context: ca)
        g.id = UUID(); g.name = "Kettenbagger"; g.anschaffungsKosten = 120000
        g.nutzungsdauerStunden = 10000; g.leistung = 20
        try ca.save()

        let data = try FirmaTransfer.exportieren(in: ca)

        // App B (frisch): importiert die Datei.
        let b = PersistenceController(inMemory: true); let cb = b.container.viewContext
        let bilanz = try FirmaTransfer.importieren(data, in: cb)
        #expect(bilanz.materialien == 1)

        let mats = try cb.fetch(KalkMaterial.fetchRequest())
        #expect(mats.first?.name == "Schotter 0/32")
        #expect(mats.first?.preisProEinheit == 7.9)
        #expect(mats.first?.lieferant == "SHB Werbach")
        #expect((try cb.fetch(Lohnsatz.fetchRequest())).first?.stundenlohn == 38)
        #expect((try cb.fetch(Geraet.fetchRequest())).first?.leistung == 20)
    }

    @Test @MainActor func firmensettingsUndUpsert() throws {
        let ud = UserDefaults.standard
        ud.set(0.20, forKey: "firma_zuschlag_material")
        ud.set(true, forKey: "firma_zuschlag_je_kostenart")
        defer {
            ud.removeObject(forKey: "firma_zuschlag_material")
            ud.removeObject(forKey: "firma_zuschlag_je_kostenart")
        }

        let a = PersistenceController(inMemory: true); let ca = a.container.viewContext
        let id = UUID()
        let m = KalkMaterial(context: ca)
        m.id = id; m.name = "Edelsplitt 2/5"; m.einheit = "t"; m.preisProEinheit = 11.8
        try ca.save()
        let data = try FirmaTransfer.exportieren(in: ca)

        // Werte verändern → Import stellt Firmensettings wieder her.
        ud.set(0.99, forKey: "firma_zuschlag_material")
        let b = PersistenceController(inMemory: true); let cb = b.container.viewContext
        try FirmaTransfer.importieren(data, in: cb)
        #expect(ud.double(forKey: "firma_zuschlag_material") == 0.20)
        #expect(ud.bool(forKey: "firma_zuschlag_je_kostenart") == true)

        // Upsert: nochmal in denselben ctx importieren → kein Duplikat (Matching über die id).
        try FirmaTransfer.importieren(data, in: cb)
        let treffer = (try cb.fetch(KalkMaterial.fetchRequest())).filter { $0.id == id }
        #expect(treffer.count == 1)
        #expect(treffer.first?.preisProEinheit == 11.8)
    }
}
