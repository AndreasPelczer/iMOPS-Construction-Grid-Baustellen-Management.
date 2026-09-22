//
//  MaterialPapiereTests.swift
//
//  "ich bin dafür das eine baustelle nicht fertig geplant ist wenn nicht für jedes
//   teil ein sicherheitsdatenblatt vorhanden wenn es eingesetzt werden soll"
//   (Andreas, Nacht 21./22.09.2026)
//
//  🔴 Aber NICHT für jedes Teil — nur für Gefahrstoffe. Schotter braucht keins.
//  Sonst stünden achtzig Prozent dauerhaft auf rot, und ein Zustand, der immer rot
//  ist, ist Rauschen (seine eigene Regel vom Vormittag).
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct GefahrstoffKatalogTests {

    @Test func derKatalogLaedt() {
        #expect(!GefahrstoffKatalog.alle.isEmpty, "gefahrstoffe.yaml muss im Bundle liegen")
    }

    @Test func zementIstEiner() throws {
        let g = try #require(GefahrstoffKatalog.erkannt("Zement CEM I 42,5 R"))
        #expect(g.warum.lowercased().contains("alkalisch") || g.warum.lowercased().contains("chromat"))
    }

    /// 🔴 Der wichtigste Test: was KEIN Gefahrstoff ist, darf nichts melden.
    @Test func schotterUndSteineSindKeine() {
        for harmlos in ["Schotter 0/32", "Pflasterstein Beton grau 10x20",
                        "Betonstahl B500B", "Sand 0/2", "Kies 16/32",
                        "Kantenstein Granit", "Drainagerohr DN 100"] {
            #expect(GefahrstoffKatalog.erkannt(harmlos) == nil,
                    "\(harmlos) ist kein Gefahrstoff")
        }
    }

    @Test func dieUeblichenVerdaechtigenWerdenErkannt() {
        for stoff in ["Zementmörtel MG III", "Bitumen-Voranstrich", "2K-Epoxidharz",
                      "Reiniger für Werkzeug", "Mineralwolle WLG 035", "Propangas 11 kg"] {
            #expect(GefahrstoffKatalog.erkannt(stoff) != nil, "\(stoff) braucht ein SDB")
        }
    }

    /// Jeder Eintrag sagt, WARUM — sonst ist es eine Behauptung.
    @Test func jederEintragIstBegruendet() {
        for g in GefahrstoffKatalog.alle {
            #expect(!g.warum.isEmpty, "\(g.id) ohne Begründung")
            #expect(!g.quelleKurz.isEmpty, "\(g.id) ohne Quelle")
            #expect(!g.stamm.isEmpty)
        }
    }
}

struct MaterialPapierBuchTests {

    private func frisch() -> MaterialPapierBuch {
        MaterialPapierBuch.shared.leeren()
        return MaterialPapierBuch.shared
    }

    private func sdb(stand: Date = Date()) -> MaterialPapier {
        MaterialPapier(art: .sicherheitsdatenblatt, ablage: "SDB_CEM_I.pdf",
                       stand: stand, hinterlegtVon: "Andreas")
    }

    @Test func gefahrstoffOhnePapierIstEineLuecke() throws {
        let b = frisch(); defer { b.leeren() }
        let l = try #require(b.luecke(fuer: "Zement CEM I 42,5 R"))
        #expect(l.sdbFehlt)
        #expect(l.istGefahrstoff)
        #expect(l.satz == "Sicherheitsdatenblatt fehlt")
    }

    /// 🔴 Schotter meldet nichts — auch ohne jedes Papier.
    @Test func harmlosesMaterialMeldetNichts() {
        let b = frisch(); defer { b.leeren() }
        #expect(b.luecke(fuer: "Schotter 0/32") == nil)
        #expect(b.luecke(fuer: "Pflasterstein grau") == nil)
    }

    @Test func mitPapierIstDieLueckeWeg() {
        let b = frisch(); defer { b.leeren() }
        #expect(b.luecke(fuer: "Zement CEM I")?.sdbFehlt == true)

        b.hinterlegen(sdb(), fuer: "Zement CEM I")
        b.hinterlegen(MaterialPapier(art: .merkblatt, ablage: "TM.pdf"), fuer: "Zement CEM I")
        #expect(b.luecke(fuer: "Zement CEM I") == nil)
        #expect(b.hat(.sicherheitsdatenblatt, fuer: "Zement CEM I"))
    }

    /// 🔴 Ein SDB von 2019 hilft niemandem — Hersteller ändern Rezepturen.
    @Test func einAltesSDBGiltNichtMehr() throws {
        let b = frisch(); defer { b.leeren() }
        let vorVierJahren = Calendar.current.date(byAdding: .year, value: -4, to: Date())!
        b.hinterlegen(sdb(stand: vorVierJahren), fuer: "Zement CEM I")

        let l = try #require(b.luecke(fuer: "Zement CEM I"))
        #expect(l.sdbVeraltet)
        #expect(!b.hat(.sicherheitsdatenblatt, fuer: "Zement CEM I"))
        #expect(l.satz.contains("drei Jahre"))
    }

    /// Beim Merkblatt spielt das Alter keine Rolle — eine Trocknungszeit altert nicht.
    @Test func einMerkblattAltertNicht() {
        let alt = Calendar.current.date(byAdding: .year, value: -10, to: Date())!
        let m = MaterialPapier(art: .merkblatt, ablage: "TM.pdf", stand: alt)
        #expect(!m.istVeraltet)
    }

    /// Wer es besser weiss, hat recht: die Einstufung von Hand schlägt den Katalog.
    @Test func einstufungVonHandSchlaegtDenKatalog() {
        let b = frisch(); defer { b.leeren() }
        #expect(b.istGefahrstoff("Zementmörtel"))
        b.einstufen("Zementmörtel", istGefahrstoff: false)
        #expect(!b.istGefahrstoff("Zementmörtel"))
        #expect(b.luecke(fuer: "Zementmörtel") == nil)

        b.einstufen("Spezialpulver XY", istGefahrstoff: true)
        #expect(b.istGefahrstoff("Spezialpulver XY"))
    }

    /// Derselbe Zement ist auf jeder Baustelle derselbe — Gross/Kleinschreibung egal.
    @Test func derSchluesselIstBaustellenuebergreifend() {
        let b = frisch(); defer { b.leeren() }
        b.hinterlegen(sdb(), fuer: "Zement CEM I 42,5 R")
        #expect(b.hat(.sicherheitsdatenblatt, fuer: "zement cem i 42,5 r"))
        #expect(b.hat(.sicherheitsdatenblatt, fuer: "  Zement  CEM I 42,5 R  "))
    }

    /// Ein neues Papier ersetzt das alte derselben Art, statt sich zu stapeln.
    @Test func dasNeuesteGilt() {
        let b = frisch(); defer { b.leeren() }
        b.hinterlegen(MaterialPapier(art: .sicherheitsdatenblatt, ablage: "alt.pdf"), fuer: "Zement")
        b.hinterlegen(MaterialPapier(art: .sicherheitsdatenblatt, ablage: "neu.pdf"), fuer: "Zement")
        let p = b.papiere(fuer: "Zement")
        #expect(p.count == 1)
        #expect(p.first?.ablage == "neu.pdf")
    }
}
