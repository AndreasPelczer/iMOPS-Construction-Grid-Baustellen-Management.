//
//  iMOPS_Construction_Grid_Baustellen_ManagementUITestsLaunchTests.swift
//  iMOPS-Construction-Grid-Baustellen-Management.UITests
//

import XCTest

final class iMOPS_Construction_Grid_Baustellen_ManagementUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
