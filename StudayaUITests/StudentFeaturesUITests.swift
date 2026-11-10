import XCTest

final class StudentFeaturesUITests: XCTestCase {
    @MainActor func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<7 { if element.isHittable { return }; app.swipeUp() }
    }
    @MainActor func testTDArchiveAndAvailabilityAndBackupScreens() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test", "-AppleLanguages", "(fr)"]
        app.launch()
        app.buttons["Commencer"].tap()
        app.textFields["Formation"].tap(); app.textFields["Formation"].typeText("Licence\n")
        app.buttons["Continuer"].tap()
        app.buttons["Organisation"].tap(); app.buttons["Par matière"].tap()
        app.buttons["Continuer"].tap()
        app.buttons["Continuer"].tap()
        app.buttons["Plus tard"].tap()
        app.buttons["Continuer"].tap()
        app.buttons["Valider mon profil"].tap(); app.buttons["Continuer gratuitement"].tap()
        app.tabBars.buttons["Matières"].tap()
        app.buttons["Créer mon Parcours de révision"].tap()
        XCTAssertFalse(app.buttons["Semestre"].exists)
        app.buttons["Importer un planning en photo"].firstMatch.tap()
        XCTAssertTrue(app.buttons["premium.close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Studaya Premium"].exists)
        app.buttons["premium.close"].tap()
        app.textFields["Nom de la matière"].tap(); app.textFields["Nom de la matière"].typeText("Mathématiques\n")
        app.buttons["Continuer"].tap()
        app.buttons["Importer un planning en photo"].firstMatch.tap()
        XCTAssertTrue(app.buttons["premium.close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Studaya Premium"].exists)
        app.buttons["premium.close"].tap()
        app.textFields["Nom du cours ou TD"].tap(); app.textFields["Nom du cours ou TD"].typeText("TD intégrales\n")
        app.buttons["Type"].tap(); app.buttons["TD"].tap()
        let exercises = app.steppers.matching(NSPredicate(format: "label CONTAINS %@", "exercices")).firstMatch
        reveal(exercises, in: app)
        for _ in 0..<4 { exercises.buttons.element(boundBy: 0).tap() }
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Date de début")).firstMatch.exists)
        app.buttons["Continuer"].tap()
        app.buttons["Ajouter une présentation"].tap()
        app.textFields["Titre"].tap(); app.textFields["Titre"].typeText("Exposé intégrales\n")
        app.buttons["Continuer"].tap()
        app.buttons["Ajouter un contrôle"].tap()
        app.textFields["Titre"].tap(); app.textFields["Titre"].typeText("Contrôle intégrales\n")
        app.buttons["Continuer"].tap()
        XCTAssertTrue(app.switches["Date de l’examen final connue"].exists)
        app.buttons["Continuer"].tap()
        app.buttons["Créer mon planning"].tap()
        XCTAssertTrue(app.staticTexts["Création de ton planning"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Découvrir mon planning"].exists)
        XCTAssertTrue(app.buttons["Découvrir mon planning"].waitForExistence(timeout: 30))
        app.buttons["Découvrir mon planning"].tap()
        XCTAssertTrue(app.buttons["Parcourir mes années"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Parcourir mes semestres"].exists)
        app.tabBars.buttons["Matières"].tap()
        app.buttons.containing(.staticText, identifier: "Mathématiques").firstMatch.tap()
        let td = app.buttons.containing(.staticText, identifier: "TD intégrales").firstMatch
        reveal(td, in: app); td.tap()
        app.buttons["Travailler ce cours ou TD"].tap()
        XCTAssertTrue(app.buttons["Réinitialiser"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Modifier la matière et le cours")).firstMatch.tap()
        XCTAssertEqual(app.buttons["Cours ou TD"].value as? String, "TD intégrales")
        app.buttons["Fermer"].tap()
        app.steppers.firstMatch.buttons.element(boundBy: 1).tap()
        let synthesis = app.switches["Synthèse refaite sans correction"]
        synthesis.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(synthesis.value as? String, "1")
        XCTAssertTrue(app.buttons["Valider et classer comme terminé"].isEnabled)
        app.buttons["Valider et classer comme terminé"].tap()
        if !app.buttons["Remettre en cours"].waitForExistence(timeout: 3) {
            let archivedTD = app.buttons.containing(.staticText, identifier: "TD intégrales").firstMatch
            reveal(archivedTD, in: app)
            XCTAssertTrue(archivedTD.exists, app.debugDescription)
            archivedTD.tap()
        }
        XCTAssertTrue(app.buttons["Remettre en cours"].waitForExistence(timeout: 5), app.debugDescription)
        reveal(app.buttons["Rappel effectué"].firstMatch, in: app)
        XCTAssertTrue(app.buttons["Rappel effectué"].firstMatch.exists)
        app.tabBars.buttons["Planning"].tap()
        app.buttons["Gérer mes indisponibilités"].tap()
        app.buttons["Ajouter une indisponibilité"].tap()
        let block = app.textFields["Cours, travail, vacances…"]
        block.tap(); block.typeText("Travail\n")
        app.buttons["Enregistrer"].tap()
        XCTAssertTrue(app.staticTexts["Travail"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Accueil"].tap()
        app.buttons["Réglages"].tap()
        app.buttons["Sauvegarde et restauration"].tap()
        XCTAssertTrue(app.buttons["Exporter une sauvegarde complète"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Restaurer une sauvegarde"].exists)
    }
}
