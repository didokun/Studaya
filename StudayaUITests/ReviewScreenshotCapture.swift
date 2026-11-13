import XCTest
import StoreKitTest

final class ReviewScreenshotCapture: XCTestCase {
    @MainActor func testCapturePremiumForAppReview() throws {
        continueAfterFailure = false
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "ReviewProducts", withExtension: "storekit"))
        let store = try SKTestSession(contentsOf: url)
        store.disableDialogs = true
        store.clearTransactions()
        defer { store.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.buttons["Start"].tap()
        let program = app.textFields["Study program"]
        XCTAssertTrue(program.waitForExistence(timeout: 10), app.debugDescription)
        program.tap(); program.typeText("University\n")
        let age = app.steppers["onboarding.age"]
        for _ in 0..<8 { if age.isHittable { break }; app.swipeUp() }
        for _ in 0..<18 { age.buttons.element(boundBy: 1).tap() }
        app.buttons["Continue"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Not now"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Save my profile"].tap()
        XCTAssertTrue(app.staticTexts["Studaya Premium"].waitForExistence(timeout: 15), app.debugDescription)
        let purchase = app.buttons["Subscribe to Premium"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 15), app.debugDescription)
        let ready = NSPredicate(format: "enabled == true")
        expectation(for: ready, evaluatedWith: purchase)
        waitForExpectations(timeout: 25)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Studaya-Premium-Review-en-US"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
