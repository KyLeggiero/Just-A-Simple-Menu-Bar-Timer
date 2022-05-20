//
//  Just_A_Simple_Menu_Bar_TimerUITestsLaunchTests.swift
//  Just A Simple Menu Bar TimerUITests
//
//  Created by Ky Leggiero on 4/19/22.
//

import XCTest

class Just_A_Simple_Menu_Bar_TimerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
