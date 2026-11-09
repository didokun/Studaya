import XCTest

final class NavigationTests: XCTestCase {
    @MainActor func testOnboardingAndStudyTabs() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test", "-AppleLanguages", "(fr)"]
        app.launch()
        app.buttons["Commencer"].tap()
        let program = app.textFields["Formation"]
        program.tap(); program.typeText("Sciences\n")
        app.buttons["Continuer"].tap()
        app.buttons["Deux années"].tap()
        app.buttons["Continuer"].tap()
        app.textFields["Matières"].tap()
        app.textFields["Matières"].typeText("Chimie, Physique\n")
        app.buttons["Continuer"].tap()
        app.buttons["Continuer"].tap()
        app.buttons["Valider mon planning"].tap()
        app.buttons["Continuer gratuitement"].tap()
        app.tabBars.buttons["Révision"].tap()
        XCTAssertTrue(app.buttons["Ajouter une matière"].waitForExistence(timeout: 5))
        app.buttons["Ajouter une matière"].tap()
        let name = app.textFields["Nom de la matière"]
        name.tap()
        name.typeText("Biologie")
        app.buttons["Enregistrer"].tap()
        app.buttons.containing(.staticText, identifier: "Biologie").firstMatch.tap()
        app.buttons["Ajouter un chapitre"].tap()
        let chapter = app.textFields["Nom du chapitre"]
        chapter.tap()
        chapter.typeText("Cellules")
        app.buttons["Enregistrer"].tap()
        XCTAssertTrue(app.staticTexts["Cellules"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Planner"].tap()
        app.buttons["Calendrier"].tap()
        XCTAssertTrue(app.datePickers.firstMatch.exists)
        app.tabBars.buttons["Focus"].tap()
        app.buttons["Commencer"].tap()
        app.buttons["Mettre en pause"].tap()
        XCTAssertTrue(app.buttons["Reprendre"].exists)
        app.buttons["Réinitialiser"].tap()
        app.tabBars.buttons["Stats"].tap()
        if !app.staticTexts["Pomodoros terminés"].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Pomodoros terminés"].exists)
        app.tabBars.buttons["Today"].tap()
        if !app.buttons["Ouvrir mes matières"].exists { app.swipeUp() }
        XCTAssertTrue(app.buttons["Ouvrir mes matières"].exists)
        app.buttons["Réglages"].tap()
        app.buttons["Études et calendrier"].tap()
        XCTAssertTrue(app.staticTexts["Sciences"].exists)
        XCTAssertTrue(app.staticTexts["Deux ans"].exists)
        app.buttons["Revoir ma configuration"].tap()
        XCTAssertEqual(app.textFields["Formation"].value as? String, "Sciences")
    }
}
