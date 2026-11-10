import Foundation
import Vision
import ImageIO

enum PlanningTable {
    static func read(_ data: Data) async throws -> [ImportedPlanningEntry] {
        guard #available(iOS 26, *), data.count <= 30 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2600
              ] as CFDictionary) else { return [] }
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.recognitionLanguages = [Locale.Language(identifier: "fr"), Locale.Language(identifier: "en")]
        let documents = try await request.perform(on: image)
        var entries: [ImportedPlanningEntry] = []
        for table in documents.flatMap({ $0.document.tables }) {
            try Task.checkCancellation()
            let rows = table.rows.indices.map { row in
                table.columns.indices.map { col in
                    table.cell(row: row, col: col)?.content.text.transcript ?? ""
                }
            }
            entries += drafts(rows)
        }
        return Array(entries.prefix(50))
    }

    static func drafts(_ rows: [[String]]) -> [ImportedPlanningEntry] {
        let headers = ["theme", "topic", "intitule", "objet", "chapitre", "activite", "contenu", "matiere", "module", "subject"]
        func normalized(_ s: String) -> String {
            s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr")).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let header = rows.indices.first(where: { row in rows[row].contains { headers.contains(normalized($0)) } }),
              let theme = rows[header].firstIndex(where: { headers.contains(normalized($0)) }) else { return [] }
        return rows.dropFirst(header + 1).compactMap { row in
            guard row.indices.contains(theme) else { return nil }
            let lines = row[theme].components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "•·"))) }
                .filter { !$0.isEmpty }
            let descriptiveLine = lines.first { $0.split(whereSeparator: { $0.isWhitespace }).count >= 3 }
            guard let title = descriptiveLine ?? lines.first, title.count >= 3, !headers.contains(normalized(title)) else { return nil }
            let labels = row.enumerated().filter { $0.offset != theme }.map { normalized($0.element) }
            let kind: ImportedKind
            if labels.contains(where: { $0.range(of: #"^td\b"#, options: .regularExpression) != nil }) { kind = .td }
            else if labels.contains("examen final") { kind = .exam }
            else if labels.contains("controle") { kind = .control }
            else if labels.contains("presentation") { kind = .presentation }
            else { kind = .course }
            let evidence = row.filter { !$0.isEmpty }.joined(separator: " · ")
            return ImportedPlanningEntry(title: title, kind: kind, date: explicitDate(in: evidence), evidence: evidence)
        }
    }

    private static func explicitDate(in text: String) -> Date? {
        let pattern = #"\b([0-3]?\d)/([01]?\d)/(20\d{2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        let fields = (1...3).compactMap { Range(match.range(at: $0), in: text).flatMap { Int(text[$0]) } }
        guard fields.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        let parts = DateComponents(year: fields[2], month: fields[1], day: fields[0])
        guard let date = calendar.date(from: parts), calendar.dateComponents([.year,.month,.day], from: date) == parts else { return nil }
        return date
    }
}
