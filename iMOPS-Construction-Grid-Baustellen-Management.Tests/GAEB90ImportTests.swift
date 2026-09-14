//
//  GAEB90ImportTests.swift
//  Belegt den GAEB-90-Leser an den ECHTEN Bytes von Andreas' Beispieldatei
//  (base64-eingebettet — testet damit auch den cp850-Decode-Pfad, nicht nur
//  meine Spalten-Annahme). „Erst messen, dann behaupten."
//
//  Datei: beispiel-ausschreibung-GAEB90.d83 (erzeugt mit dem Dangl-GAEB-Tool).
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct GAEB90ImportTests {

    /// Die echte .d83 als base64 (Bytes 1:1, inkl. cp850-Einheiten m²/m³).
    private static let d83Base64 = "VDAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMDEKNzAgICAgICAgICAgICAgICAgICAgICAgQ3JlYXRlZCB3aXRoIERhbmdsIEdBRUIgVG9vbCAgICAgICAgICAgICAgICAgICAgICAwMDAwMDIKNzAgICAgICAgICAgICAgICAgICAgIENvcHlyaWdodCAyMDEzIC0gMjAxNiBHZW9yZyBEYW5nbCAgICAgICAgICAgICAgICAgICAwMDAwMDMKNzAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBibG9nLmRhbmdsLm1lICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMDQKNzAgICAgICAgICAgICAgICAgVmVyc2lvbiAxLjIuMy4wIChCdWlsdDogMjMuMDQuMjAxNiAxODozMCkgICAgICAgICAgICAgICAwMDAwMDUKVDkgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMDYKMDAgICAgICAgIDgzTCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAxMTIyUFBQMDA5MCAwMDAwMDcKMDFUaGlzIGlzIGFuIGV4YW1wbGUgR0FFQiBwcm9qZWN0ICAgICAgICAgMDMuMDUuMTYgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMDgKMDJFeGFtcGxlIFByb2plY3QgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMDkKMDNCb2IgdGhlIEJ1aWxkZXIgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMTAKMDYyTGFib3VyICAgICAgICBNYXRlcmlhbCAgICAgIEdlYXIgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMTEKMDg/ICAgICBFdXJvICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMTIKMjAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMTMKMjYgICBQcm9qZWN0IEluZm9ybWF0aW9uICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMTQKMjYgICBUaGlzIGlzIGEgc21hbGwgc2FtcGxlIHByb2plY3QgdG8gaWxsdXN0cmF0ZSB0aGUgdXNhZ2UgICAgICAgICAgICAgICAwMDAwMTUKMjYgICBvZiB0aGUgR0FFQiBjb252ZXJ0ZXIgYXQgaHR0cHM6Ly9ibG9nLmRhbmdsLm1lICAgICAgICAgICAgICAgICAgICAgICAwMDAwMTYKMTEwMSAgICAgICBOICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMTcKMTJNYWluIEJ1aWxkaW5nICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMTgKMTEwMTAxICAgICBOICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMTkKMTIgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMjAKMjEwMTAxMDAxICBOTk4gICAgICAgICAwMDAwMDAwMTAwMEZsYXQgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMjEKMjVTaXRlIFByZXBhcmF0aW9uICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMjIKMjYgICBQcmVwYXJhdGlvbiBvZiB0aGUgc2l0ZSBiZWZvcmUgY29uc3RydWN0aW9uIHN0YXJ0LiAgICAgICAgICAgICAgICAgICAwMDAwMjMKMzEwMTAxICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMjQKMTEwMTAyICAgICBOICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMjUKMTJDb25zdHJ1Y3Rpb24gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMjYKMjEwMTAyMDAxICBOTk4gICAgICAgWCAgICAgICAgICAgIG38ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMjcKMjVFeGNhdmF0aW9uICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMjgKMjYgICBFeGNhdmF0aW9uIGZvciB0aGUgYnVpbGRpbmcgcGl0LiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMjkKMjEwMTAyMDAyICBOTk4gICAgICAgICAwMDAwMDYwMDAwMG38ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMzAKMjVGaWxsaW5nICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMzEKMjYgICBGaWxsaW5nIG9mIGV4Y2F2YXRlZCBidWlsZGluZyBwaXQgd2l0aCBwcm9wZXIgbWF0ZXJpYWwgICAgICAgICAgICAgICAwMDAwMzIKMjYgICBmb3IgZm91bmRhdGlvbi4gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMzMKMjEwMTAyMDAzICBOTk4gICAgICAgWCAgICAgICAgICAgIG38ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMzQKMjVTb2lsIFJlbW92YWwgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMzUKMjYgICBSZW1vdmFsIG9mIHVudXNhYmxlIGV4Y2F2YXRlZCBzb2lsIGZyb20gdGhlICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMzYKMjYgICBjb25zdHJ1Y3Rpb24gc2l0ZS4gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMzcKMjEwMTAyMDA0ICBOTk4gICAgICAgICAwMDAwMDgwMDAwMG39ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMzgKMjVDb25yZXRlIFNsYWJzICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMzkKMjYgICBDb25jcmV0ZSBzbGFicyBmb3IgdGhlIGJ1aWxkaW5nIGNvbnN0cnVjdGlvbi4gICAgICAgICAgICAgICAgICAgICAgICAwMDAwNDAKMjEwMTAyMDA1ICBOTk4gICAgICAgICAwMDAwMDI0MDAwMG39ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwNDEKMjVDb25jcmV0ZSBXYWxscyAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwNDIKMjYgICBDb25jcmV0ZSB3YWxscyBmb3IgdGhlIGJ1aWxkaW5nIGNvbnN0cnVjdGlvbi4gICAgICAgICAgICAgICAgICAgICAgICAwMDAwNDMKMzEwMTAyICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwNDQKMzEwMSAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwNDUKOTkgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgMDAwMDYwMDAwNDY="

    private static var d83Data: Data { Data(base64Encoded: d83Base64)! }

    @Test("Kopfdaten: DP 83, Projektname, Auftraggeber, 6 Positionen")
    func kopfdaten() throws {
        let r = try GAEB90Importer.parse(data: Self.d83Data)
        #expect(r.dp == 83)
        #expect(r.projectName == "Example Project")
        #expect(r.ownerName == "Bob the Builder")
        #expect(r.items.count == 6)
    }

    @Test("Position mit Menge: Filling = 600 m³, Text gelesen")
    func fillingPosition() throws {
        let r = try GAEB90Importer.parse(data: Self.d83Data)
        let filling = try #require(r.items.first { $0.kurztext.localizedCaseInsensitiveContains("filling") })
        #expect(filling.posNr == "0102002")
        #expect(filling.menge == 600.0)          // 00000600000 / 1000
        #expect(filling.einheit == "m³")         // cp850 → m³
        #expect(filling.langtext.localizedCaseInsensitiveContains("foundation"))
    }

    @Test("m²/m³ und 3 Nachkommastellen korrekt")
    func mengenUndEinheiten() throws {
        let r = try GAEB90Importer.parse(data: Self.d83Data)
        let slabs = try #require(r.items.first { $0.kurztext.localizedCaseInsensitiveContains("slab") })
        #expect(slabs.menge == 800.0)
        #expect(slabs.einheit == "m²")

        let walls = try #require(r.items.first { $0.kurztext.localizedCaseInsensitiveContains("wall") })
        #expect(walls.menge == 240.0)
        #expect(walls.einheit == "m²")
    }

    @Test("Bedarfsposition (X, ohne Menge) → Menge 0, Einheit bleibt")
    func bedarfsposition() throws {
        let r = try GAEB90Importer.parse(data: Self.d83Data)
        let excavation = try #require(r.items.first { $0.kurztext.localizedCaseInsensitiveContains("excavation") })
        #expect(excavation.menge == 0.0)
        #expect(excavation.einheit == "m³")
        #expect(excavation.isAlternative)        // X = Bedarfsposition
    }

    @Test("Weiche: GAEBImporter.parse(url:) erkennt .d83 und routet auf GAEB 90")
    func routingUeberDateiEndung() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("route-\(UUID().uuidString).d83")
        try Self.d83Data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let r = try GAEBImporter.parse(url: url)
        #expect(r.gaebVersion == "90")           // vom GAEB-90-Leser gesetzt
        #expect(r.items.count == 6)
    }
}
