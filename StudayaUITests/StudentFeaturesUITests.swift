import XCTest

final class StudentFeaturesUITests: XCTestCase {
    @MainActor func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<7 { if element.isHittable { return }; app.swipeUp() }
    }
    @MainActor func testEventsSelectTDWithoutTypingTitles() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test", "-AppleLanguages", "(fr)"]
        app.launch()
        app.buttons["Commencer"].tap()
        app.textFields["Formation"].tap(); app.textFields["Formation"].typeText("Licence\n")
        app.buttons["Continuer"].tap()
        app.buttons["Continuer"].tap()
        app.buttons["Continuer"].tap()
        app.buttons["Plus tard"].tap()
        app.buttons["Continuer"].tap()
        app.buttons["Valider mon profil"].tap(); app.buttons["Continuer gratuitement"].tap()
        app.tabBars.buttons["Matières"].tap()
        app.buttons["Créer mon Parcours de révision"].tap()
        app.textFields["Nom de la matière"].tap(); app.textFields["Nom de la matière"].typeText("Maths\n")
        app.textFields["subject.code"].tap(); app.textFields["subject.code"].typeText("MTH\n")
        app.buttons["Continuer"].tap()
        app.textFields["Nom du cours ou TD"].tap(); app.textFields["Nom du cours ou TD"].typeText("Intégrales\n")
        app.segmentedControls.buttons["TD"].tap()
        app.buttons["Continuer"].tap()
        app.buttons["Ajouter une présentation"].tap()
        XCTAssertFalse(app.textFields["Titre"].exists)
        app.buttons["event.unit"].tap()
        app.buttons["TD · Intégrales"].tap()
        XCTAssertTrue(app.buttons["Continuer"].isEnabled)
        app.buttons["Continuer"].tap()
        app.buttons["Ajouter un contrôle"].tap()
        XCTAssertFalse(app.textFields["Titre"].exists)
        XCTAssertTrue(app.buttons["Continuer"].isEnabled)
        app.buttons["Continuer"].tap()
        XCTAssertTrue(app.switches["Date de l’examen final connue"].exists)
        XCTAssertFalse(app.textFields["Titre"].exists)
        app.buttons["Continuer"].tap()
        XCTAssertTrue(app.staticTexts["Présentation · Intégrales"].exists)
        XCTAssertTrue(app.staticTexts["Contrôle · MTH"].exists)
    }
    @MainActor func testSubjectCodeCanBeCreatedAndEdited() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test", "-AppleLanguages", "(fr)"]
        app.launch()
        app.buttons["Commencer"].tap()
        app.textFields["Formation"].tap(); app.textFields["Formation"].typeText("Licence\n")
        app.buttons["Continuer"].tap(); app.buttons["Continuer"].tap(); app.buttons["Continuer"].tap()
        app.buttons["Plus tard"].tap(); app.buttons["Continuer"].tap()
        app.buttons["Valider mon profil"].tap(); app.buttons["Continuer gratuitement"].tap()
        app.tabBars.buttons["Matières"].tap()
        app.buttons["Ajouter une matière"].tap()
        app.textFields["Nom de la matière"].tap(); app.textFields["Nom de la matière"].typeText("Analyse numerique\n")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Code utilisé : AN ·")).firstMatch.exists)
        app.textFields["subject.code"].tap(); app.textFields["subject.code"].typeText("ANA\n")
        app.buttons["Enregistrer"].tap()
        let row = app.buttons.containing(.staticText, identifier: "Analyse numerique").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        app.buttons["Modifier la matière"].tap()
        let field = app.textFields["subject.code"]
        XCTAssertEqual(field.value as? String, "ANA")
        field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "AN2\n")
        app.buttons["Enregistrer"].tap()
        XCTAssertTrue(app.navigationBars["AN2"].waitForExistence(timeout: 5))
    }
    @MainActor func testFocusSurvivesBackgroundAndNotificationSettingsAreAvailable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test", "-AppleLanguages", "(fr)"]
        app.launch()
        app.buttons["Commencer"].tap()
        app.textFields["Formation"].tap(); app.textFields["Formation"].typeText("Licence\n")
        app.buttons["Continuer"].tap(); app.buttons["Continuer"].tap(); app.buttons["Continuer"].tap()
        app.buttons["Plus tard"].tap(); app.buttons["Continuer"].tap()
        app.buttons["Valider mon profil"].tap(); app.buttons["Continuer gratuitement"].tap()
        app.tabBars.buttons["Focus"].tap(); app.buttons["Commencer"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons.matching(NSPredicate(format: "label IN %@", ["Autoriser", "Allow"])).firstMatch
        if allow.waitForExistence(timeout: 4) { allow.tap() }
        XCTAssertTrue(app.buttons["Mettre en pause"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["Mettre en pause"].waitForExistence(timeout: 5))
        app.buttons["Mettre en pause"].tap()
        XCTAssertTrue(app.buttons["Reprendre"].exists)
        app.buttons["Réinitialiser"].tap()
        app.buttons["Réglages"].tap(); app.buttons["Rappels et notifications"].tap()
        XCTAssertTrue(app.switches["Planning du matin"].exists)
        XCTAssertTrue(app.switches["Bilan du soir"].exists)
        XCTAssertTrue(app.switches["À l’heure des séances"].exists)
        let focus = app.switches["Fin de Focus, début et fin du repos"]
        reveal(focus, in: app)
        XCTAssertTrue(focus.exists)
    }
    @MainActor func testAppleCalendarSyncAndRemovalKeepStudyPlanning() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test", "-AppleLanguages", "(fr)"]
        app.launch()
        app.buttons["Commencer"].tap()
        app.textFields["Formation"].tap(); app.textFields["Formation"].typeText("Licence\n")
        app.buttons["Continuer"].tap(); app.buttons["Continuer"].tap(); app.buttons["Continuer"].tap()
        app.buttons["Plus tard"].tap(); app.buttons["Continuer"].tap()
        app.buttons["Valider mon profil"].tap(); app.buttons["Continuer gratuitement"].tap()
        app.tabBars.buttons["Matières"].tap(); app.buttons["Ajouter une matière"].tap()
        app.textFields["Nom de la matière"].tap(); app.textFields["Nom de la matière"].typeText("Analyse numerique\n")
        app.buttons["Enregistrer"].tap()
        app.buttons.containing(.staticText, identifier: "Analyse numerique").firstMatch.tap()
        app.buttons["Ajouter un cours ou un TD"].tap()
        app.textFields["Nom du cours ou TD"].tap(); app.textFields["Nom du cours ou TD"].typeText("Matrices\n")
        app.buttons["Enregistrer"].tap()
        app.tabBars.buttons["Planning"].tap()
        let week = XCTAttachment(screenshot: app.screenshot()); week.name = "Planning semaine avec matières"; week.lifetime = .keepAlways; add(week)
        app.buttons["Synchroniser avec Calendrier Apple"].tap()
        app.buttons["Activer la synchronisation"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons.matching(NSPredicate(format: "label CONTAINS[cd] %@ OR label == %@", "complet", "Allow Full Access")).firstMatch
        if allow.waitForExistence(timeout: 4) { allow.tap() }
        let status = app.staticTexts["calendar.sync.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 8))
        XCTAssertTrue(status.label.contains("synchronisé(s)"), status.label)
        let before = status.label
        app.buttons["Synchroniser maintenant"].tap()
        XCTAssertEqual(status.label, before)
        let remove = app.buttons["Tout supprimer de Calendrier Apple"]
        reveal(remove, in: app); remove.tap()
        app.buttons["Supprimer les événements Studaya"].tap()
        XCTAssertTrue(status.label.contains("supprimé(s)"), status.label)
        XCTAssertTrue(app.buttons["Activer la synchronisation"].exists)
        app.navigationBars.buttons["Planning"].tap()
        app.segmentedControls.buttons["Calendrier"].tap()
        app.swipeUp()
        let month = XCTAttachment(screenshot: app.screenshot()); month.name = "Planning mois avec matières"; month.lifetime = .keepAlways; add(month)
        app.tabBars.buttons["Matières"].tap()
        let subjectRow = app.buttons.containing(.staticText, identifier: "Analyse numerique").firstMatch
        if subjectRow.exists { subjectRow.tap() }
        XCTAssertTrue(app.buttons["Modifier la matière"].waitForExistence(timeout: 5))
        let course = app.buttons.containing(.staticText, identifier: "Matrices").firstMatch
        reveal(course, in: app)
        XCTAssertTrue(course.exists)
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
