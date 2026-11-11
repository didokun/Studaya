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
        let headers = ["theme", "topic", "intitule", "objet", "chapitre", "activite", "contenu", "matiere", "module", "subject", "titre", "libelle", "description", "programme"]
        func normalized(_ s: String) -> String {
            s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr")).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let header = rows.indices.first(where: { row in rows[row].contains { headers.contains(normalized($0)) } }),
              let theme = rows[header].firstIndex(where: { headers.contains(normalized($0)) }) else {
            return fallbackRows(rows)
        }
        return rows.dropFirst(header + 1).flatMap { row -> [ImportedPlanningEntry] in
            guard row.indices.contains(theme) else { return [] }
            let rawLines = row[theme].components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "•·-"))) }
                .filter { !$0.isEmpty }
            guard !rawLines.isEmpty else { return [] }

            let labels = row.enumerated().filter { $0.offset != theme }.map { normalized($0.element) }
            let evidence = row.filter { !$0.isEmpty }.joined(separator: " · ")

            func kindFor(text: String) -> ImportedKind {
                let norm = normalized(text)
                if labels.contains(where: { $0.range(of: #"^td\b"#, options: .regularExpression) != nil }) || norm.range(of: #"^td\b"#, options: .regularExpression) != nil { return .td }
                if labels.contains("examen final") || norm.contains("examen final") { return .exam }
                if labels.contains("controle") || norm.range(of: #"^contr[oô]le\b"#, options: .regularExpression) != nil { return .control }
                if labels.contains("presentation") || norm.range(of: #"^pr[eé]sentation\b"#, options: .regularExpression) != nil { return .presentation }
                return .course
            }

            // Check if multiple lines represent distinct TDs or sessions (split them so they aren't merged in a single block)
            let sessionLines = rawLines.filter { line in
                let norm = normalized(line)
                return norm.range(of: #"^(?:td|s[eé]ance|cours|cm)\s*\d*\b"#, options: .regularExpression) != nil
            }

            if sessionLines.count > 1 {
                return sessionLines.compactMap { line in
                    guard line.count >= 2, !headers.contains(normalized(line)) else { return nil }
                    let lineDate = explicitDate(in: line) ?? explicitDate(in: evidence)
                    return ImportedPlanningEntry(title: line, kind: kindFor(text: line), date: lineDate, evidence: evidence)
                }
            }

            let descriptiveLine = rawLines.first { $0.split(whereSeparator: { $0.isWhitespace }).count >= 3 }
            guard let title = descriptiveLine ?? rawLines.first, title.count >= 3, !headers.contains(normalized(title)) else { return [] }
            let entryKind = kindFor(text: title)
            return [ImportedPlanningEntry(title: title, kind: entryKind, date: explicitDate(in: evidence), evidence: evidence)]
        }
    }

    private static func fallbackRows(_ rows: [[String]]) -> [ImportedPlanningEntry] {
        var entries: [ImportedPlanningEntry] = []
        for row in rows {
            let fullText = row.joined(separator: " · ")
            for cell in row {
                let lines = cell.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                for line in lines {
                    let norm = line.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr"))
                    if norm.range(of: #"\b(?:td|s[eé]ance|cours|cm|examen|contr[oô]le)\b"#, options: .regularExpression) != nil && line.count >= 4 {
                        let kind: ImportedKind
                        if norm.contains("td") { kind = .td }
                        else if norm.contains("examen") { kind = .exam }
                        else if norm.contains("controle") { kind = .control }
                        else { kind = .course }
                        entries.append(ImportedPlanningEntry(title: line, kind: kind, date: explicitDate(in: fullText), evidence: fullText))
                    }
                }
            }
        }
        return entries
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
