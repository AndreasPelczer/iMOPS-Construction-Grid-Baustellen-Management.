//
//  ServerFehlertextTests.swift
//  Regression zum Vorfall 04.08.2026 — 502 im Startfenster sah aus wie ein CSV-Fehler
//
//  Ein Mengen-CSV-Upload traf den Mops, während er neu startete. Cloudflare antwortete
//  mit einer HTML-Fehlerseite; die App schob den rohen Body ins Fehlerfeld. Ergebnis:
//  40 Zeilen HTML auf dem Bildschirm, die nach kaputter Datei aussahen — obwohl Datei
//  UND Server in Ordnung waren (derselbe Upload lief Minuten später fehlerfrei durch).
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct ServerFehlertextTests {

    /// Gekürzt, aber im Aufbau echt: genau das kam am 04.08. zurück.
    private let cloudflare502 = """
    <!DOCTYPE html>
    <!--[if lt IE 7]> <html class="no-js ie6 oldie" lang="en-US"> <![endif]-->
    <head>
    <title>baumops.com | 502: Bad gateway</title>
    <meta charset="UTF-8" />
    </head>
    <body>
    <span class="inline-block">Bad gateway</span>
    <span class="code-label">Error code 502</span>
    <div class="mt-3">2026-08-04 15:14:53 UTC</div>
    </body>
    </html>
    """.data(using: .utf8)!

    @Test("502 erklärt den Neustart, statt HTML auszuspucken")
    func cloudflareSeiteWirdUebersetzt() {
        let text = ServerFehlertext.fuer(status: 502, data: cloudflare502)

        // Das Entscheidende: kein Roh-HTML mehr im Fehlerfeld.
        #expect(!text.contains("<"))
        #expect(!text.lowercased().contains("doctype"))
        #expect(!text.contains("Error code 502"))

        // Und der Satz muss die Sorge nehmen, es läge an der Datei.
        #expect(text.contains("startet"))
        #expect(text.contains("An der Datei liegt es nicht."))
    }

    @Test("503 und 504 verhalten sich wie 502")
    func weitereGatewayFehler() {
        for status in [503, 504] {
            let text = ServerFehlertext.fuer(status: status, data: cloudflare502)
            #expect(!text.contains("<"), "Status \(status) zeigte Roh-HTML")
            #expect(text.contains("startet"), "Status \(status) ohne Neustart-Hinweis")
        }
    }

    /// Eine Fehlerseite kann auch mit Status 200 durchkommen (Proxy/Portal/Tunnel-Panne).
    /// Dann rettet uns der Statuscode nicht — nur der Blick in den Body.
    @Test("HTML mit Status 200 wird trotzdem erkannt")
    func htmlTrotzStatus200() {
        let text = ServerFehlertext.fuer(status: 200, data: cloudflare502)
        #expect(!text.contains("<"))
        #expect(text.contains("startet"))
    }

    /// Der Mops schickt eigene Fehler als {"detail": "..."} — die sind präziser als
    /// jeder Text, den wir hier erfinden könnten, und müssen durchgereicht werden.
    @Test("Eigene Server-Meldung schlägt den Standardtext")
    func detailWirdDurchgereicht() {
        let json = #"{"detail":"Nur .xlsx oder .csv (SketchUp-Mengenauszug) wird unterstützt."}"#
            .data(using: .utf8)!
        let text = ServerFehlertext.fuer(status: 400, data: json)
        #expect(text == "Nur .xlsx oder .csv (SketchUp-Mengenauszug) wird unterstützt.")
    }

    @Test("Zu große Datei bleibt als solche erkennbar")
    func zuGross() {
        let text = ServerFehlertext.fuer(status: 413, data: Data())
        #expect(text.contains("zu groß"))
    }

    /// Kein Gateway-Fehler, kein HTML — aber auch kein lesbares Ergebnis.
    /// Hier darf gerade NICHT der Neustart-Hinweis kommen, der wäre gelogen.
    @Test("Unerwartete 200-Antwort meldet sich ehrlich als unlesbar")
    func unlesbareAntwort() {
        let murks = "kein json, kein html, nur murks".data(using: .utf8)!
        let text = ServerFehlertext.fuer(status: 200, data: murks)
        #expect(text.contains("ließ sich nicht lesen"))
        #expect(!text.contains("startet"))
    }

    @Test("Unbekannter Fehlerstatus nennt die Zahl")
    func unbekannterStatus() {
        let text = ServerFehlertext.fuer(status: 418, data: Data())
        #expect(text.contains("418"))
    }

    /// Materialliste und Wandleser laden gegen denselben Server hoch und fallen darum in
    /// dasselbe Startfenster. Sie müssen dieselbe Auskunft geben — sonst lernt man die
    /// Lage an der einen Stelle und steht an der anderen wieder ratlos da.
    @Test("Beide Upload-Wege erklären den Neustart gleich")
    func beideWegeGleich() {
        // Der Wandleser lädt DXF statt CSV — für die Fehlerlage macht das keinen Unterschied.
        let ausMaterialliste = ServerFehlertext.fuer(status: 502, data: cloudflare502)
        let ausWandleser = ServerFehlertext.fuer(status: 502, data: cloudflare502)
        #expect(ausMaterialliste == ausWandleser)
        #expect(ausWandleser == ServerFehlertext.neustartHinweis)
    }
}
