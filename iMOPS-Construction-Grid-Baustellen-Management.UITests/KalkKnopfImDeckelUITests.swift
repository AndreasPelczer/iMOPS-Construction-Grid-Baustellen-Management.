//
//  KalkKnopfImDeckelUITests.swift
//  Der ƒ-Knopf am Baustein — ein Tipp, eine Kalkulation.
//
//  Warum ein UI-Test und kein Screenshot: Ein Bild zeigt, DASS der Knopf da ist.
//  Der Auftrag verlangt aber, dass **ein Tipp darauf genau eine Sache tut** —
//  nicht die DisclosureGroup zuklappen, nicht den `actionPosition`-Dialog öffnen.
//  Das sieht man keinem Bild an. Genau deshalb steht `.buttonStyle(.borderless)`
//  am Knopf, und genau das prüft dieser Test.
//
//  Gestartet wird über den DEBUG-Snapshot-Modus (`--target=LVDeckelKalk`), damit
//  der Test keine Baustelle zusammenklicken muss und immer dieselben Daten sieht.
//

import XCTest

final class KalkKnopfImDeckelUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Deckel aufklappen → ƒ am Baustein antippen → die Tiefenkalkulation steht da.
    func testKalkKnopfOeffnetDieKalkulationDesBausteins() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--snapshot-mode", "--target=LVDeckelKalk"]
        app.launch()

        // Der Deckel (Element „Pflasterfläche Hofzufahrt", 100 m²).
        let deckel = app.staticTexts["Pflasterfläche Hofzufahrt"]
        XCTAssertTrue(deckel.waitForExistence(timeout: 20), "Deckel nicht gefunden")

        // Aufklappen — die Bausteine erscheinen.
        deckel.tap()
        let baustein = app.staticTexts["Frostschutzschicht"]
        XCTAssertTrue(baustein.waitForExistence(timeout: 5),
                      "Deckel ließ sich nicht aufklappen")

        // Der ƒ-Knopf steht sichtbar an der Baustein-Zeile.
        let kalkKnopf = app.buttons["Kalkulation Frostschutzschicht"]
        XCTAssertTrue(kalkKnopf.waitForExistence(timeout: 5),
                      "ƒ-Knopf fehlt an der Baustein-Zeile")

        // Beweisbild: aufgeklappter Deckel mit den ƒ-Knöpfen.
        let bild = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        bild.name = "Deckel aufgeklappt mit ƒ-Knöpfen"
        bild.lifetime = .keepAlways
        add(bild)

        // EIN Tipp — und die Kalkulation dieses Bausteins steht da.
        kalkKnopf.tap()
        XCTAssertTrue(app.navigationBars["Kalkulation"].waitForExistence(timeout: 5),
                      "Der ƒ-Tipp hat die Kalkulation nicht geöffnet")

        // Und er hat NICHT die Gruppe zugeklappt und NICHT den Aktions-Dialog
        // geöffnet — beides wäre passiert, wenn `.borderless` fehlte.
        XCTAssertFalse(app.sheets.firstMatch.exists, "Statt der Kalkulation kam ein Dialog")

        let bild2 = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        bild2.name = "Tiefenkalkulation nach einem Tipp"
        bild2.lifetime = .keepAlways
        add(bild2)
    }
}
