import SwiftUI

struct PremiumInsights: View {
    let logs: [FocusLog]
    let subjects: [Subject]
    @ObservedObject private var membership = Membership.shared
    var body: some View {
        Section("Studaya Premium") {
            if membership.premium == true {
                let cutoff = Calendar.current.date(byAdding: .day, value: -29, to: Calendar.current.startOfDay(for: .now))!
                let recent = logs.filter { $0.date >= cutoff }
                LabeledContent("Focus sur 30 jours", value: "\(recent.reduce(0) { $0 + $1.minutes }) min")
                ForEach(subjects) { subject in
                    LabeledContent(subject.name, value: "\(recent.filter { $0.subjectID == subject.id }.reduce(0) { $0 + $1.minutes }) min")
                }
                ShareLink(item: csvFile, preview: SharePreview("Sessions Focus")) { Label("Exporter les sessions Focus en CSV", systemImage: "square.and.arrow.up") }
            } else {
                NavigationLink { PremiumOptions().padding(.horizontal) } label: { Label("Découvrir le bilan sur 30 jours", systemImage: "chart.line.uptrend.xyaxis") }
            }
        }
    }
    private var csvFile: FocusExport {
        var rows = ["Date,Matière,Minutes"]
        for log in logs.sorted(by: { $0.date < $1.date }) {
            let title = subjects.first { $0.id == log.subjectID }?.name ?? "Focus libre"
            let safe = title.replacingOccurrences(of: "\"", with: "\"\"")
            rows.append("\(log.date.ISO8601Format()),\"\(safe)\",\(log.minutes)")
        }
        return FocusExport(text: rows.joined(separator: "\r\n"))
    }
}

import CoreTransferable
import UniformTypeIdentifiers
struct FocusExport: Transferable {
    var text: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { Data($0.text.utf8) }
            .suggestedFileName("Studaya-Focus.csv")
    }
}
