//
//  TrennlinienTests.swift
//
//  "wenn du etwas baust dann ist das doch allgemein gültig oder nur für diesen fall
//   und diese baustelle? das sollte nie passieren." (Andreas, 22.09.2026)
//
//  Der erste Wurf kannte EINE Trennlinie — die, die sein Fall brauchte. Diese Tests
//  halten fest, dass der Katalog mehrere kennt UND dass er nicht ins Rauschen kippt:
//  an BV Setiadji durchgerechnet waren von zwölf Vorschlägen fünf Unsinn.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct TrennlinienTests {

    private func baustelle(_ auftragsName: String,
                           _ texte: [String]) -> (NSManagedObjectContext, Auftrag) {
        PaketZuordnung.shared.leeren()
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Test"
        let a = Auftrag(context: ctx)
        a.processingDetails = auftragsName
        a.status = .pending; a.storageNote = ""; a.event = e
        let titel = auftragsName.split(separator: " ").first.map(String.init) ?? "99"
        for (i, t) in texte.enumerated() {
            let p = LVPosition(context: ctx)
            p.posNr = String(format: "%@.%04d", titel, (i + 1) * 10)
            p.bezeichnung = t; p.menge = 10; p.einheit = "m"; p.event = e
        }
        return (ctx, a)
    }

    @Test func derKatalogLaedt() {
        #expect(TrennlinienKatalog.alle.count >= 5, "es darf nicht bei einer bleiben")
        for l in TrennlinienKatalog.alle {
            #expect(!l.begruendung.isEmpty, "\(l.id) ohne Begründung")
            #expect(!l.stamm.isEmpty)
        }
    }

    /// Der Originalfall — Erdreich gegen Innenausbau.
    @Test func erdarbeitenWerdenErkannt() throws {
        let (_, a) = baustelle("411 Abwasser-, Wasser-, Gasanlagen", [
            "Schmutzwasser-Hausanschluss PP DN 150 bis Schacht (T 2,60 m)",
            "Grundleitungen KG DN 100 frostfrei",
            "Kontrollschächte setzen",
            "Sanitärinstallation Bad DG",
            "Sanitärinstallation WC EG"])
        defer { PaketZuordnung.shared.leeren() }

        let v = Arbeitspakete.teilungsVorschlaege(fuer: a)
        let erd = try #require(v.first { $0.name.contains("Erdarbeiten") })
        #expect(erd.abtrennen.count == 3)
    }

    /// Mehrere Linien in einem Titel — Fertigteil UND Vorbereitung.
    @Test func mehrereLinienGleichzeitig() {
        let (_, a) = baustelle("351 Decken / Horizontale Baukonstruktionen", [
            "Filigran-Elementdecke d = 20 cm, C 20/25, liefern und versetzen",
            "Deckendurchbrueche und Bodendurchbrueche aussparen",
            "Bewehrung Betonstahlmatten", "Ortbetonergänzung", "Ausschalen"])
        defer { PaketZuordnung.shared.leeren() }

        let namen = Arbeitspakete.teilungsVorschlaege(fuer: a).map(\.name)
        #expect(namen.contains { $0.contains("Fertigteile") })
        #expect(namen.contains { $0.contains("Vorbereitung") })
    }

    /// 🔴 Trägt der Auftrag die Trennlinie schon im NAMEN, ist nichts zu trennen.
    /// „311 Baugrube / Erdbau" bekam den Vorschlag, die Erdarbeiten abzutrennen —
    /// das ganze Paket IST Erdbau.
    @Test func derSelbstbezugWirdAbgefangen() {
        let (_, a) = baustelle("311 Baugrube / Erdbau", [
            "Baugrube Wohnhaus ausheben, BKL 4-6",
            "Baugrube Garage ausheben",
            "Böschung herstellen max. 1:1,5",
            "Planum herstellen", "Abfuhr Überschussmassen"])
        defer { PaketZuordnung.shared.leeren() }

        #expect(!Arbeitspakete.teilungsVorschlaege(fuer: a)
            .contains { $0.name.contains("Erdarbeiten") })
    }

    /// 🔴 Aussen- und Innenwand mauert dieselbe Kolonne am selben Tag. Die Linie
    /// „Arbeiten aussen" darf das Mauerwerk nicht auseinanderreissen.
    @Test func mauerwerkWirdNichtNachInnenUndAussenGetrennt() {
        let (_, a) = baustelle("331 Baukonstruktionen", [
            "Mauerwerk Außenwand Ytong PPW 2-0,35, d = 24 cm",
            "Mauerwerk Außenwand Ytong PP 2-0,35, d = 24 cm, OG",
            "Mauerwerk Innenwand Ytong PP 4-0,55, d = 11,5 cm",
            "Kimmschicht LM 21 unter Außenwand", "Ringanker"])
        defer { PaketZuordnung.shared.leeren() }

        #expect(!Arbeitspakete.teilungsVorschlaege(fuer: a)
            .contains { $0.name.contains("aussen") })
    }

    /// 🔴 „Mutterboden abtragen" ist Oberboden abschieben, kein Abbruch.
    @Test func mutterbodenIstKeinAbbruch() {
        let (_, a) = baustelle("312 Bodenarbeiten", [
            "Mutterboden 0,20 m abtragen und seitlich lagern",
            "Bodenaustausch herstellen", "Planum", "Verdichten", "Abfuhr"])
        defer { PaketZuordnung.shared.leeren() }

        #expect(!Arbeitspakete.teilungsVorschlaege(fuer: a)
            .contains { $0.name.contains("Abbruch") })
    }

    /// Ein Vorschlag, der alles oder nichts nimmt, ist keiner.
    @Test func allesOderNichtsIstKeineTrennung() {
        let (_, a) = baustelle("399 Sonstiges", [
            "Fertiggarage 6000/3500/2750 liefern und stellen",
            "Fertigteil-Stützwand liefern", "Fertigteilstufen liefern"])
        defer { PaketZuordnung.shared.leeren() }
        #expect(Arbeitspakete.teilungsVorschlaege(fuer: a).isEmpty,
                "alle drei sind Fertigteile — da gibt es nichts abzutrennen")
    }

    /// Unter drei Positionen wird gar nicht erst geschaut.
    @Test func kleinePaketeBleibenInRuhe() {
        let (_, a) = baustelle("411 Anlagen", ["Hausanschluss", "Waschbecken"])
        defer { PaketZuordnung.shared.leeren() }
        #expect(Arbeitspakete.teilungsVorschlaege(fuer: a).isEmpty)
    }
}
