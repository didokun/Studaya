import SwiftUI

enum PremiumInsight: String, Identifiable, CaseIterable {
    case history = "Bilan de concentration sur 30 jours"
    case subjects = "Temps étudié par matière"
    case export = "Exporter les sessions Focus en CSV"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .history: "chart.bar"; case .subjects: "books.vertical"; case .export: "square.and.arrow.up" }
    }
}

struct PremiumInsights: View {
    var onSelect: (PremiumInsight) -> Void
    var body: some View {
        Section("Studaya Premium") {
            ForEach(PremiumInsight.allCases) { feature in
                Button { onSelect(feature) } label: {
                    PremiumFeatureLabel(title: feature.rawValue, symbol: feature.symbol)
                }.accessibilityLabel(feature.rawValue)
            }
        }
    }
}

struct PremiumInsightDetail: View {
    let feature: PremiumInsight
    let logs: [FocusLog]
    let subjects: [Subject]
    private var recent: [FocusLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -29, to: Calendar.current.startOfDay(for: .now))!
        return logs.filter { $0.date >= cutoff }
    }
    var body: some View {
        List {
            switch feature {
            case .history:
                Section("30 derniers jours") {
                    LabeledContent("Temps de concentration", value: "\(recent.reduce(0) { $0 + $1.minutes }) min")
                    LabeledContent("Séances Focus", value: "\(recent.count)")
                }
            case .subjects:
                Section("Temps étudié · 30 derniers jours") {
                    if subjects.isEmpty { Text("Ajoute une matière pour suivre ton temps de travail.") }
                    ForEach(subjects) { subject in
                        LabeledContent(subject.name, value: "\(recent.filter { $0.subjectID == subject.id }.reduce(0) { $0 + $1.minutes }) min")
                    }
                }
            case .export:
                Section("Export Focus") {
                    Text("Exporte tes sessions de concentration avec la date, la matière et la durée.")
                    ShareLink(item: csvFile, preview: SharePreview("Sessions Focus")) {
                        Label("Exporter les sessions Focus en CSV", systemImage: "square.and.arrow.up")
                    }
                }
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
