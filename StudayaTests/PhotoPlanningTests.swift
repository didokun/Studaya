import XCTest
import SwiftData
import UIKit
import StoreKitTest
@testable import Studaya

@MainActor final class PhotoPlanningTests: XCTestCase {
    func testTimelineMovesOneCardInBothDirections() {
        let a = UUID(), b = UUID(), c = UUID()
        XCTAssertEqual(TimelineOrder.dropping(a, on: c, in: [a,b,c]), [b,c,a])
        XCTAssertEqual(TimelineOrder.dropping(c, on: a, in: [a,b,c]), [c,a,b])
        XCTAssertNil(TimelineOrder.dropping(UUID(), on: c, in: [a,b,c]))
    }
    func testCourseTableKeepsUndatedSessionsAndReadsExplicitDates() {
        let entries = PlanningTable.drafts([
            ["", "Séance", "Thème", "Cas"],
            ["AMPHI", "", "Introduction au contrôle de gestion", "CAS LUCKY DUCK"],
            ["TD", "1", "coût\nL’arbitrage coût et valeur", "CAS LM"],
            ["TD", "2", "Les tableaux de bord", "12/11/2026"]
        ])
        XCTAssertEqual(entries.map(\.kind), [.course, .td, .td])
        XCTAssertNil(entries[0].date)
        XCTAssertEqual(entries[1].title, "L’arbitrage coût et valeur")
        XCTAssertNil(entries[1].date)
        XCTAssertNotNil(entries[2].date)
        XCTAssertTrue(entries.allSatisfy { !$0.verified })
    }

    func testPremiumRequiredIncludingUnknownStatus() {
        XCTAssertThrowsError(try PhotoPlanning.requirePremium(nil))
        XCTAssertThrowsError(try PhotoPlanning.requirePremium(false))
        XCTAssertNoThrow(try PhotoPlanning.requirePremium(true))
    }
    func testStrictDatesNeverGuessYearOrNormalizeInvalidDates() {
        XCTAssertNil(PhotoPlanning.parseDate(nil))
        XCTAssertNil(PhotoPlanning.parseDate("mardi 12 novembre"))
        XCTAssertNil(PhotoPlanning.parseDate("12/11"))
        XCTAssertNil(PhotoPlanning.parseDate("2026-02-30"))
        XCTAssertNil(PhotoPlanning.parseDate("2026-11-12T25:00"))
        XCTAssertNotNil(PhotoPlanning.parseDate("2026-11-12T14:30"))
        XCTAssertNotNil(PhotoPlanning.parseDate("2026-11-12"))
    }
    func testOnlySelectedExplicitlyVerifiedDatedRowsCanBeImported() throws {
        var entry = ImportedPlanningEntry(title: "TD intégrales", kind: .td)
        XCTAssertThrowsError(try PhotoPlanning.validate([entry]))
        entry.date = Date()
        XCTAssertThrowsError(try PhotoPlanning.validate([entry]))
        entry.verified = true
        XCTAssertEqual(try PhotoPlanning.validate([entry]).count, 1)
        var unselected = ImportedPlanningEntry(); unselected.selected = false
        XCTAssertEqual(try PhotoPlanning.validate([entry, unselected]).count, 1)
        var duplicate = entry; duplicate.id = UUID(); duplicate.date = entry.date!.addingTimeInterval(1)
        XCTAssertThrowsError(try PhotoPlanning.validate([entry, duplicate]))
        var exam = entry; exam.kind = .exam
        var secondExam = exam; secondExam.title = "Deuxième examen"
        XCTAssertThrowsError(try PhotoPlanning.validate([exam, secondExam]))
    }
    func testOCRReadsRealImageAndRejectsInvalidData() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 600)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1600, height: 600))
            ("MATHEMATIQUES\nTD Integrales 12/11/2026\nControle 19/11/2026 14:30" as NSString).draw(in: CGRect(x: 60, y: 70, width: 1480, height: 460), withAttributes: [.font: UIFont.systemFont(ofSize: 64), .foregroundColor: UIColor.black])
        }
        let result = try PlanningPhotoOCR.read(XCTUnwrap(image.pngData()))
        XCTAssertTrue(result.text.localizedCaseInsensitiveContains("Integrales"))
        XCTAssertTrue(result.text.contains("2026"))
        XCTAssertThrowsError(try PlanningPhotoOCR.read(Data("not an image".utf8)))
    }
    func testVerifiedStoreKitPremiumImportAndFreeRejection() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Studaya", withExtension: "storekit"))
        let store = try SKTestSession(contentsOf: url)
        store.disableDialogs = true; store.clearTransactions()
        defer { store.clearTransactions() }
        let container = try Storage.container(memory: true), db = container.mainContext
        let subject = Subject("Maths", exam: .now); subject.hasExam = false; db.insert(subject); try db.save()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        let entry = ImportedPlanningEntry(title: "TD intégrales", kind: .td, date: tomorrow, evidence: "TD intégrales", verified: true)
        do { try await PhotoPlanning.save([entry], subject: subject, replaceExam: false, db: db); XCTFail("Free import must be rejected") } catch {}
        XCTAssertTrue(try db.fetch(FetchDescriptor<Chapter>()).isEmpty)
        _ = try await store.buyProduct(identifier: "studaya.premium.lifetime")
        _ = try await PhotoPlanning.save([entry], subject: subject, replaceExam: false, db: db)
        let chapter = try XCTUnwrap(db.fetch(FetchDescriptor<Chapter>()).first)
        XCTAssertEqual(chapter.subjectID, subject.id)
        XCTAssertEqual(chapter.startDate, tomorrow)
        XCTAssertEqual(chapter.kind, "TD")
        do { try await PhotoPlanning.save([entry], subject: subject, replaceExam: false, db: db); XCTFail("Duplicate must be rejected") } catch {}
        XCTAssertEqual(try db.fetch(FetchDescriptor<Chapter>()).count, 1)
    }
    func testPhotoImportPopulatesDraftWithoutSavingUntilCreation() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        var draft = PathSubject(); draft.name = "Maths"
        let start = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        let due = Calendar.current.date(byAdding: .day, value: 10, to: start)!
        let exam = Calendar.current.date(byAdding: .day, value: 20, to: due)!
        let rows = [
            ImportedPlanningEntry(title: "TD intégrales", kind: .td, date: start, evidence: "TD intégrales", verified: true),
            ImportedPlanningEntry(title: "Exposé", kind: .presentation, date: due, verified: true),
            ImportedPlanningEntry(title: "Contrôle", kind: .control, date: due, verified: true),
            ImportedPlanningEntry(title: "Final", kind: .exam, date: exam, verified: true)
        ]
        let merged = try RevisionPath.mergingPhoto(rows, into: draft)
        XCTAssertEqual(draft.units.first?.name, "")
        XCTAssertTrue(try db.fetch(FetchDescriptor<Subject>()).isEmpty)
        XCTAssertTrue(try db.fetch(FetchDescriptor<Chapter>()).isEmpty)
        XCTAssertEqual(merged.units.count, 1)
        XCTAssertEqual(merged.units.first?.kind, "TD")
        XCTAssertEqual(merged.units.first?.start, start)
        XCTAssertEqual(merged.presentations.count, 1)
        XCTAssertEqual(merged.controls.count, 1)
        XCTAssertEqual(merged.exam, exam)
        try RevisionPath.create([merged], db: db)
        XCTAssertEqual(try db.fetch(FetchDescriptor<Chapter>()).first?.notes, "Source · planning importé\nTD intégrales")
        XCTAssertEqual(try db.fetch(FetchDescriptor<StudyDeadline>()).count, 2)
    }
    func testDraftPhotoMergeDoesNotOverwriteExamOrDuplicateWork() throws {
        var draft = PathSubject(); draft.name = "Maths"
        let start = Date.now
        draft.units[0].name = "TD existant"; draft.units[0].kind = "TD"; draft.units[0].start = start
        let duplicate = ImportedPlanningEntry(title: "TD existant", kind: .td, date: start, verified: true)
        XCTAssertThrowsError(try RevisionPath.mergingPhoto([duplicate], into: draft))
        draft.hasExam = true; draft.exam = start.addingTimeInterval(30 * 86400)
        let exam = ImportedPlanningEntry(title: "Examen", kind: .exam, date: start.addingTimeInterval(40 * 86400), verified: true)
        XCTAssertThrowsError(try RevisionPath.mergingPhoto([exam], into: draft))
        let updated = try RevisionPath.mergingPhoto([exam], into: draft, replaceExam: true)
        XCTAssertEqual(updated.exam, exam.date)
        XCTAssertNotEqual(draft.exam, updated.exam)
    }

}
