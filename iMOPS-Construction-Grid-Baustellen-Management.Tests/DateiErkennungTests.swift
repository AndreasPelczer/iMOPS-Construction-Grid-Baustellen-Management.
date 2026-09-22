//
//  DateiErkennungTests.swift
//
//  "können wir alles was mit importieren zu tun hat zusammenführen unter importe,
//   die jetzigen importe an den richtigen stellen bleiben bestehen, aber es gibt
//   sie auch kompakt. ist das sinnvoll?" (Andreas, 22.09.2026)
//
//  🔴 Beim Messen kam heraus: `DroppedFileType` kannte KEIN DXF, kein DWG, kein IFC,
//  kein JSON und kein GAEB 90 — also ausgerechnet die Formate, die Raphi schickt.
//  Und `FileDropOverlayModifier` war gebaut und nirgends eingehängt.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct DateiErkennungTests {

    private func typ(_ name: String) -> DroppedFileType {
        DroppedFileType.detect(from: URL(fileURLWithPath: "/tmp/\(name)"))
    }

    /// 🔴 Die Formate, die vorher durchfielen.
    @Test func dieFehlendenFormateWerdenErkannt() {
        #expect(typ("gelaende.dxf") == .dxf)
        #expect(typ("grundriss.DXF") == .dxf, "Gross- und Kleinschreibung egal")
        #expect(typ("plan.dwg") == .dwg)
        #expect(typ("haus.ifc") == .ifc)
        #expect(typ("lv.json") == .json)
        #expect(typ("ausschreibung.d83") == .gaeb90)
        #expect(typ("ausschreibung.d84") == .gaeb90)
    }

    @Test func dieBekanntenBleibenBekannt() {
        #expect(typ("lv.x84") == .gaeb)
        #expect(typ("lv.x83") == .gaeb)
        #expect(typ("modell.skp") == .skp)
        #expect(typ("statik.pdf") == .pdf)
        #expect(typ("foto.heic") == .photo)
        #expect(typ("mengen.xlsx") == .excel)
        #expect(typ("modell.usdz") == .cad)
    }

    @Test func unbekanntesBleibtUnbekannt() {
        #expect(typ("notizen.txt") == .unknown)
        #expect(typ("archiv.zip") == .unknown)
        #expect(typ("ohne_endung") == .unknown)
    }

    /// Jeder Typ sagt in Klartext, was der Mops damit macht — keine Dateiendungen.
    @Test func jederTypErklaertSich() {
        for t: DroppedFileType in [.gaeb, .gaeb90, .dxf, .dwg, .ifc, .cad, .skp,
                                   .pdf, .photo, .excel, .json, .unknown] {
            #expect(!t.wasDerMopsDamitMacht.isEmpty)
            #expect(!t.displayName.isEmpty)
            #expect(!t.iconName.isEmpty)
        }
    }

    /// Stammdaten und Tabellen gehen ohne Baustelle, Zeichnungen nicht.
    @Test func wasEineBaustelleBraucht() {
        #expect(DroppedFileType.gaeb.brauchtBaustelle)
        #expect(DroppedFileType.dxf.brauchtBaustelle)
        #expect(DroppedFileType.ifc.brauchtBaustelle)
        #expect(!DroppedFileType.excel.brauchtBaustelle)
        #expect(!DroppedFileType.json.brauchtBaustelle)
        #expect(!DroppedFileType.unknown.brauchtBaustelle)
    }

    /// 🔴 Der Mops sagt bei Unbekanntem ehrlich, dass er es nicht kennt —
    /// statt zu raten.
    @Test func beiUnbekanntemKeineErfindung() {
        let text = DroppedFileType.unknown.wasDerMopsDamitMacht.lowercased()
        #expect(text.contains("kennt") && text.contains("nicht"))
    }
}
