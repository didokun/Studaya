import SwiftUI

// Shared meaning and colors in the month grid, week strip and event cards.
enum CalendarStudyKind: String, CaseIterable {
    case exam = "Examen", control = "Contrôle", presentation = "Présentation", revision = "Révision", review = "Rappel"
    var color: Color {
        switch self {
        case .exam: StudyDesign.coral
        case .control: Color(red: 0.70, green: 0.39, blue: 0.06)
        case .presentation: Color(red: 0.12, green: 0.40, blue: 0.72)
        case .revision: StudyDesign.accent
        case .review: StudyDesign.mint
        }
    }
    var symbol: String {
        switch self { case .exam: "graduationcap.fill"; case .control: "checkmark.seal.fill"; case .presentation: "person.wave.2.fill"; case .revision: "pencil.and.outline"; case .review: "brain.head.profile" }
    }
    static func deadline(_ kind: String) -> Self {
        if kind.localizedCaseInsensitiveContains("examen") { return .exam }
        if kind == "Présentation" { return .presentation }
        return .control
    }
}
struct CalendarDayMarker: Identifiable {
    let subjectID: UUID?
    let code: String
    let symbol: String
    let kind: CalendarStudyKind
    var id: String { (subjectID?.uuidString ?? "libre") + kind.rawValue }
}

@MainActor enum CalendarDayPlan {
    static func markers(on date: Date, subjects: [Subject], sessions: [Session], deadlines: [StudyDeadline], reviews: [SpacedReview], chapters: [Chapter], calendar: Calendar = .current) -> [CalendarDayMarker] {
        var result: [CalendarDayMarker] = []
        func append(_ subject: Subject?, kind: CalendarStudyKind) {
            let item = CalendarDayMarker(subjectID: subject?.id, code: subject?.displayCode ?? "", symbol: subject.map { StudyDesign.symbol(for: $0.name) } ?? kind.symbol, kind: kind)
            if !result.contains(where: { $0.id == item.id }) { result.append(item) }
        }
        for kind in CalendarStudyKind.allCases {
            if kind == .exam {
                for subject in subjects where subject.hasExam && calendar.isDate(subject.exam, inSameDayAs: date) { append(subject, kind: .exam) }
            }
            for deadline in deadlines where deadline.hasDueDate && CalendarStudyKind.deadline(deadline.kind) == kind && calendar.isDate(deadline.due, inSameDayAs: date) {
                append(subjects.first { $0.id == deadline.subjectID }, kind: kind)
            }
            if kind == .revision {
                for session in sessions where calendar.isDate(session.start, inSameDayAs: date) { append(subjects.first { $0.id == session.subjectID }, kind: .revision) }
            }
            if kind == .review {
                for review in reviews where !review.done && calendar.isDate(review.due, inSameDayAs: date) {
                    if let chapter = chapters.first(where: { $0.id == review.chapterID }) { append(subjects.first { $0.id == chapter.subjectID }, kind: .review) }
                }
            }
        }
        return result
    }
}

struct CalendarDayIcons: View {
    let markers: [CalendarDayMarker]
    var showCode = false
    var selected = false
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                ForEach(Array(markers.prefix(2))) { marker in
                    Image(systemName: marker.symbol).font(.system(size: 10, weight: .semibold))
                        .frame(width: 18, height: 17)
                        .foregroundStyle(selected ? .white : marker.kind.color)
                        .background(selected ? Color.white.opacity(0.18) : marker.kind.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 5))
                }
            }
            if showCode, let marker = markers.first {
                Text(marker.code + (markers.count > 1 ? " +\(markers.count - 1)" : ""))
                    .font(.system(size: 9, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
            } else if markers.count > 2 { Text("+\(markers.count - 2)").font(.system(size: 9)) }
        }.frame(minHeight: showCode ? 29 : 18)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(markers.map { L10n.key($0.kind.rawValue) + " " + $0.code }.joined(separator: ", "))
    }
}
struct CalendarLegend: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach([CalendarStudyKind.exam, .control, .presentation, .revision], id: \.self) { kind in
                Label(L10n.key(kind.rawValue), systemImage: kind.symbol).foregroundStyle(kind.color).lineLimit(1)
            }
        }.font(.caption)
    }
}
