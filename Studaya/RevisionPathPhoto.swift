import Foundation

extension RevisionPath {
    /// Merge into a value-type draft only; creation of the planning remains the sole persistence step.
    static func mergingPhoto(_ entries: [ImportedPlanningEntry], into original: PathSubject, replaceExam: Bool = false) throws -> PathSubject {
        let rows = try PhotoPlanning.validate(entries)
        var draft = original
        let units = rows.filter { $0.kind.isUnit }
        if !units.isEmpty { draft.units.removeAll { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        for row in rows {
            let name = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if row.kind.isUnit {
                guard !draft.units.contains(where: { $0.kind == row.kind.rawValue && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame && Calendar.current.isDate($0.start, inSameDayAs: row.date!) }) else { throw StudyError.invalid("Ce cours ou TD existe déjà dans le parcours : \(name).") }
                var unit = PathUnit()
                unit.name = name; unit.kind = row.kind.rawValue; unit.start = row.date!
                unit.sessions = row.sessions; unit.exercises = row.exercises
                unit.notes = row.evidence.isEmpty ? "" : "Source · planning importé\n" + row.evidence
                draft.units.append(unit)
            } else if row.kind == .exam {
                guard !draft.hasExam || replaceExam else { throw StudyError.invalid("Confirme le remplacement de l’examen déjà renseigné dans le parcours.") }
                draft.hasExam = true; draft.exam = row.date!
            } else {
                let existing = row.kind == .presentation ? draft.presentations : draft.controls
                guard !existing.contains(where: { $0.title.localizedCaseInsensitiveCompare(name) == .orderedSame && $0.due == row.date! }) else { throw StudyError.invalid("Cette échéance existe déjà dans le parcours : \(name).") }
                let event = PathEvent(title: name, due: row.date!, preparation: row.sessions)
                switch row.kind {
                case .presentation: draft.presentations.append(event)
                case .control: draft.controls.append(event)
                default: break
                }
            }
        }
        if draft.hasExam {
            guard draft.units.filter({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).allSatisfy({ Calendar.current.startOfDay(for: $0.start) < Calendar.current.startOfDay(for: draft.exam) }) else { throw StudyError.invalid("L’examen doit avoir lieu après le début des cours et TD du parcours.") }
        }
        return draft
    }
}
