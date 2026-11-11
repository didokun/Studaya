import Foundation

extension RevisionPath {
    /// Merge into a value-type draft only; creation of the planning remains the sole persistence step.
    static func mergingPhoto(_ entries: [ImportedPlanningEntry], into original: PathSubject, replaceExam: Bool = false) throws -> PathSubject {
        let rows = try PhotoPlanning.validate(entries)
        var draft = original
        let units = rows.filter { $0.kind.isUnit }
        if !units.isEmpty { draft.units.removeAll { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        for row in rows.sorted(by: { $0.kind.isUnit && !$1.kind.isUnit }) {
            let name = row.kind.isUnit ? row.title.trimmingCharacters(in: .whitespacesAndNewlines) : draft.units.first { $0.id == row.unitID }?.name ?? draft.name
            if row.kind.isUnit {
                guard !draft.units.contains(where: { $0.kind == row.kind.rawValue && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame && (($0.start == nil && row.date == nil) || ($0.start != nil && row.date != nil && Calendar.current.isDate($0.start!, inSameDayAs: row.date!))) }) else { throw StudyError.invalid(String(localized: "Ce cours ou TD existe déjà dans le parcours : \(name).")) }
                var unit = PathUnit()
                unit.id = row.id
                unit.name = name; unit.kind = row.kind.rawValue; unit.start = row.date
                unit.sessions = row.sessions; unit.exercises = row.exercises
                unit.notes = row.evidence.isEmpty ? "" : "Source · planning importé\n" + row.evidence
                draft.units.append(unit)
            } else if row.kind == .exam {
                guard let date = row.date else {
                    guard draft.undatedExam == nil else { throw StudyError.invalid(String(localized: "Un examen sans date figure déjà dans le parcours.")) }
                    draft.undatedExam = PathEvent(title: name, due: nil, preparation: row.sessions)
                    continue
                }
                guard !draft.hasExam || replaceExam else { throw StudyError.invalid(String(localized: "Confirme le remplacement de l’examen déjà renseigné dans le parcours.")) }
                draft.hasExam = true; draft.exam = date; draft.undatedExam = nil
            } else {
                guard row.unitID == nil || draft.units.contains(where: { $0.id == row.unitID }) else { throw StudyError.invalid(String(localized: "Le cours ou TD lié n’est plus disponible dans ce parcours.")) }
                let existing = row.kind == .presentation ? draft.presentations : draft.controls
                guard !existing.contains(where: { $0.title.localizedCaseInsensitiveCompare(name) == .orderedSame && $0.due == row.date }) else { throw StudyError.invalid(String(localized: "Cette échéance existe déjà dans le parcours : \(name).")) }
                let event = PathEvent(title: name, due: row.date, preparation: row.sessions, unitID: row.unitID)
                switch row.kind {
                case .presentation: draft.presentations.append(event)
                case .control: draft.controls.append(event)
                default: break
                }
            }
        }
        if draft.hasExam {
            guard draft.units.filter({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).compactMap(\.start).allSatisfy({ Calendar.current.startOfDay(for: $0) < Calendar.current.startOfDay(for: draft.exam) }) else { throw StudyError.invalid(String(localized: "L’examen doit avoir lieu après le début des cours et TD du parcours.")) }
        }
        return draft
    }
}
