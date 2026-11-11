import XCTest

final class LocalizationUITests: XCTestCase {
    struct Language: Decodable {
        let language: String, region: String, title: String, start: String, program: String
        let next: String, later: String, save: String, free: String
        let home: String, planner: String, subjects: String, progress: String, settings: String
    }
    private func languages() throws -> [Language] {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "LocalizationFixtures", withExtension: "json"))
        return try JSONDecoder().decode([Language].self, from: Data(contentsOf: url))
    }
    @MainActor private func launch(_ language: Language) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test", "-AppleLanguages", "(\(language.language))", "-AppleLocale", language.region]
        app.launch()
        return app
    }
    @MainActor func testOnboardingFollowsAllSixteenPhoneLanguages() throws {
        continueAfterFailure = false
        for language in try languages() {
            let app = launch(language)
            XCTAssertTrue(app.staticTexts[language.title].waitForExistence(timeout: 8), language.language + ": " + language.title)
            XCTAssertTrue(app.buttons[language.start].exists, language.language)
            let logo = app.images["onboarding.logo"], counter = app.staticTexts["onboarding.step"]
            XCTAssertTrue(logo.exists && counter.exists, language.language)
            if language.language == "ar" { XCTAssertGreaterThan(logo.frame.midX, counter.frame.midX) }
            else { XCTAssertLessThan(logo.frame.midX, counter.frame.midX) }
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Onboarding " + language.language; screenshot.lifetime = .keepAlways; add(screenshot)
            app.buttons[language.start].tap()
            XCTAssertTrue(app.textFields[language.program].waitForExistence(timeout: 5), language.language + ": " + language.program)
            app.terminate()
        }
    }
    @MainActor func testEnglishFrenchAndArabicMainNavigation() throws {
        continueAfterFailure = false
        for language in try languages().filter({ ["en", "fr", "ar"].contains($0.language) }) {
            let app = launch(language)
            app.buttons[language.start].tap()
            app.textFields[language.program].tap(); app.textFields[language.program].typeText("Physics\n")
            app.buttons[language.next].tap(); app.buttons[language.next].tap(); app.buttons[language.next].tap()
            app.buttons[language.later].tap(); app.buttons[language.next].tap()
            app.buttons[language.save].tap(); app.buttons[language.free].tap()
            XCTAssertTrue(app.tabBars.buttons[language.home].waitForExistence(timeout: 8), language.language)
            for tab in [language.planner, language.subjects, language.progress] {
                XCTAssertTrue(app.tabBars.buttons[tab].exists, language.language + ": " + tab)
                app.tabBars.buttons[tab].tap()
            }
            app.buttons[language.settings].tap()
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Settings " + language.language; screenshot.lifetime = .keepAlways; add(screenshot)
            app.terminate()
        }
    }
}
