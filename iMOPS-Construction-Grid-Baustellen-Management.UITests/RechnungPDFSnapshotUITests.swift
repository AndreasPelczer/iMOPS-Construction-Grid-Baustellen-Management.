//
//  RechnungPDFSnapshotUITests.swift
//  Das Rechnungsblatt einmal ansehen — der Nachweis, den kein Zahlentest ersetzt.
//
//  Ein Unit-Test kann prüfen, dass das PDF nicht leer ist und die richtige Nummer
//  trägt. Ob Logo, Anschrift und Fuß an der richtigen Stelle sitzen und sich nicht
//  überlappen, sieht man nur.
//

import XCTest

final class RechnungPDFSnapshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRechnungsblattSiehtAus() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--snapshot-mode", "--target=RechnungPDF"]
        app.launch()

        // Der Mitteilungs-Dialog gehört SpringBoard, liegt über der App und
        // schluckt jeden Tap. Wegräumen, bevor irgendetwas passiert.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for titel in ["Nicht erlauben", "Erlauben", "Don’t Allow", "Allow", "OK"] {
            let knopf = springboard.buttons[titel]
            if knopf.waitForExistence(timeout: 2) { knopf.tap(); break }
        }

        // PDFKit braucht einen Moment, bis die Seite steht.
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        let bild = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        bild.name = "Rechnungsblatt mit Briefkopf und Fuß"
        bild.lifetime = .keepAlways
        add(bild)
    }
}
