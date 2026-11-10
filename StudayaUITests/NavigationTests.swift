import XCTest

final class NavigationTests: XCTestCase {
    @MainActor func testOnboardingAndStudyTabs() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test", "-AppleLanguages", "(fr)"]
        app.launch()
        app.buttons["Commencer"].tap()
        let level = app.buttons["Niveau d’études"]
        XCTAssertGreaterThanOrEqual(level.frame.height, 52)
        level.tap()
        app.buttons["Master"].tap()
        XCTAssertEqual(level.value as? String, "Master")
        let program = app.textFields["Formation"]
        program.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1)).withOffset(CGVector(dx: 0, dy: 8)).tap()
        program.typeText("Sciences\n")
        app.buttons["Continuer"].tap()
        app.steppers.firstMatch.buttons.element(boundBy: 1).tap()
        app.buttons["Continuer"].tap()
        app.buttons["Continuer"].tap()
        XCTAssertTrue(app.buttons["Activer les notifications"].exists)
        app.buttons["Plus tard"].tap()
        app.buttons["Continuer"].tap()
        app.buttons["Valider mon profil"].tap()
        app.buttons["Continuer gratuitement"].tap()
        capture("Accueil", app)
        app.tabBars.buttons["Matières"].tap()
        capture("Matières", app)
        XCTAssertTrue(app.buttons["Ajouter une matière"].waitForExistence(timeout: 5))
        app.buttons["Ajouter une matière"].tap()
        let name = app.textFields["Nom de la matière"]
        name.tap()
        name.typeText("Biologie")
        app.buttons["Enregistrer"].tap()
        app.buttons.containing(.staticText, identifier: "Biologie").firstMatch.tap()
        app.buttons["Importer un planning en photo"].tap()
        XCTAssertTrue(app.staticTexts["Studaya Premium"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Choisir une photo du planning"].exists)
        app.buttons["Fermer"].tap()
        app.buttons["Ajouter un cours ou un TD"].tap()
        let chapter = app.textFields["Nom du cours ou TD"]
        chapter.tap()
        chapter.typeText("Cellules")
        app.buttons["Enregistrer"].tap()
        XCTAssertTrue(app.staticTexts["Cellules"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Planning"].tap()
        app.buttons["Calendrier"].tap()
        capture("Planning", app)
        XCTAssertTrue(app.buttons["calendar.nextMonth"].waitForExistence(timeout: 10), app.debugDescription)
        app.tabBars.buttons["Focus"].tap()
        capture("Focus", app)
        app.buttons["Commencer"].tap()
        app.buttons["Mettre en pause"].tap()
        XCTAssertTrue(app.buttons["Reprendre"].exists)
        app.buttons["Réinitialiser"].tap()
        app.tabBars.buttons["Progrès"].tap()
        for title in ["Bilan de concentration sur 30 jours", "Temps étudié par matière", "Exporter les sessions Focus en CSV"] {
            let feature = app.buttons[title]
            for _ in 0..<6 { if feature.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(feature.exists, title)
            feature.tap()
            XCTAssertTrue(app.staticTexts["Studaya Premium"].waitForExistence(timeout: 5), title)
            XCTAssertTrue(app.buttons["Fermer"].waitForExistence(timeout: 5), title)
            app.buttons["Fermer"].tap()
        }
        for _ in 0..<5 {
            if app.staticTexts["Pomodoros terminés"].isHittable { break }; app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Pomodoros terminés"].exists)
        app.tabBars.buttons["Accueil"].tap()
        for _ in 0..<6 {
            if app.buttons["Ouvrir mes matières"].isHittable { break }; app.swipeUp()
        }
        XCTAssertTrue(app.buttons["Ouvrir mes matières"].exists)
        app.buttons["Réglages"].tap()
        XCTAssertTrue(app.buttons["Études et calendrier"].waitForExistence(timeout: 5))
        app.buttons["Études et calendrier"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Sciences")).firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "2 année(s)")).firstMatch.exists, app.debugDescription)
        app.buttons["Revoir ma configuration"].tap()
        XCTAssertEqual(app.textFields["Formation"].value as? String, "Sciences")
    }
    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }

}
