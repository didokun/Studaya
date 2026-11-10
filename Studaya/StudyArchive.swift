import SwiftUI
import SwiftData

struct ReviewRow: View {
    let review: SpacedReview
    let chapter: Chapter
    @Environment(\.modelContext) private var db
    @State private var focus = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(chapter.name + " · J+\(review.intervalDays)", systemImage: "brain.head.profile").font(.headline)
            Text(review.due, format: .dateTime.day().month().hour().minute()).font(.caption)
            Text("Rappel d’un travail terminé · teste-toi sans correction").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Démarrer ce rappel") { focus = true }
                Button("Rappel effectué") {
                    review.done = true
                    do { try db.save() } catch { db.rollback(); self.error = error.localizedDescription }
                }
            }.buttonStyle(.borderless)
        }.sheet(isPresented: $focus) { NavigationStack { Focus(initialChapterID: chapter.id, initialReviewID: review.id).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { focus = false } } } } }
        .alert("Rappel", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
    }
}

struct StudyArchive: View {
    @Query(sort: \Chapter.name) private var chapters: [Chapter]
    @Query(sort: \StudyDeadline.due) private var deadlines: [StudyDeadline]
    @Query private var subjects: [Subject]
    @Query(sort: \SpacedReview.due) private var reviews: [SpacedReview]
    @State private var search = ""
    @State private var editing: StudyDeadline?
    func matches(_ text: String) -> Bool { search.isEmpty || text.localizedCaseInsensitiveContains(search) }
    var body: some View {
        List {
            Section("Cours et TD terminés") {
                ForEach(chapters.filter { chapter in chapter.completed && matches(chapter.name + " " + (subjects.first(where: { $0.id == chapter.subjectID })?.name ?? "")) }) { chapter in
                    NavigationLink { ChapterPage(chapter: chapter) } label: { Label(chapter.kind + " · " + chapter.name, systemImage: "checkmark.circle") }
                }
            }
            Section("Échéances terminées") {
                ForEach(deadlines.filter { $0.done && matches($0.title) }) { item in
                    VStack(alignment: .leading) { DeadlineRow(item: item); Button("Modifier l’échéance") { editing = item } }
                }
            }
            Section("Rappels espacés à venir ou à rattraper") {
                ForEach(reviews.filter { !$0.done }) { review in
                    if let chapter = chapters.first(where: { $0.id == review.chapterID }), matches(chapter.name) { ReviewRow(review: review, chapter: chapter) }
                }
            }
            Section("Historique des rappels") {
                ForEach(reviews.filter(\.done)) { review in
                    if let chapter = chapters.first(where: { $0.id == review.chapterID }), matches(chapter.name) {
                        Label(chapter.name + " · J+\(review.intervalDays)", systemImage: "checkmark.circle.fill")
                    }
                }
            }
        }.navigationTitle("Archives").searchable(text: $search, prompt: "Rechercher un travail terminé")
        .sheet(item: $editing) { item in if let subject = subjects.first(where: { $0.id == item.subjectID }) { DeadlineEditor(subject: subject, existing: item) } }
    }
}
