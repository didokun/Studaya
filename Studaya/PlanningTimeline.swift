import SwiftUI

struct PlanningTimeline: View {
    static let stages = [
        String(localized: "Lecture de tes matières"), String(localized: "Organisation des cours et TD"), String(localized: "Repérage des échéances"),
        String(localized: "Répartition des séances"), String(localized: "Vérification des disponibilités"), String(localized: "Enregistrement du planning")
    ]
    let subjects: [PathSubject]
    let stage: Int
    let missing: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var finished: Bool { stage >= Self.stages.count }
    private var units: [PathUnit] { subjects.flatMap(\.units) }
    private var events: [PathEvent] { subjects.flatMap { $0.presentations + $0.controls } }
    private var requested: Int { units.reduce(0) { $0 + $1.sessions } + events.reduce(0) { $0 + $1.preparation } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image("Logo").resizable().frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 10.32, style: .continuous))
                Text(finished ? String(localized: "Ton planning est prêt !") : String(localized: "Création de ton planning")).font(.title.bold())
            }
            ProgressView(value: Double(stage), total: Double(Self.stages.count)).tint(.mintBrand)
                .accessibilityLabel(String(localized: "Création du planning"))
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Self.stages.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 16) {
                                VStack(spacing: 6) {
                                    if index == stage {
                                        ProgressView().tint(.mintBrand).frame(width: 28, height: 28)
                                    } else {
                                        Image(systemName: index < stage ? "checkmark.circle.fill" : "circle")
                                            .font(.title2).foregroundStyle(index < stage ? Color.mintBrand : .secondary)
                                            .frame(width: 28, height: 28)
                                    }
                                    if index < Self.stages.count - 1 {
                                        Rectangle().fill(Color.mintBrand.opacity(index < stage ? 0.65 : 0.15)).frame(width: 2)
                                    }
                                }.accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(Self.stages[index]).font(.headline)
                                    if index <= stage { details(index).font(.subheadline).foregroundStyle(.secondary) }
                                    else { Text(String(localized: "À venir")).font(.subheadline).foregroundStyle(.secondary) }
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 28)
                            }
                            .opacity(index > stage ? 0.55 : 1)
                            .id(index)
                            .accessibilityElement(children: .combine)
                            .accessibilityValue(index < stage ? String(localized: "Terminée") : index == stage ? String(localized: "En cours") : String(localized: "À venir"))
                        }
                        if finished {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(String(localized: "Parcours de révision créé"), systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(Color.mintBrand)
                                Text(String(localized: "Retrouve tes séances dans Planner et ton suivi dans Révision."))
                                if missing > 0 { Text(String(localized: "\(missing) séances sans créneau avant leur échéance : ajuste tes dates ou tes disponibilités.")).foregroundStyle(.orange) }
                            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.mintBrand.opacity(0.1), in: RoundedRectangle(cornerRadius: 18)).id("result")
                        }
                    }.padding(.vertical, 12)
                }.onChange(of: stage) { _, next in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) {
                        if finished { scroll.scrollTo("result", anchor: .bottom) }
                        else { scroll.scrollTo(min(next, Self.stages.count - 1), anchor: .top) }
                    }
                }
            }
        }.padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity)
    }
    @ViewBuilder private func details(_ index: Int) -> some View {
        switch index {
        case 0:
            Text(String(localized: "\(subjects.count) matières · \(subjects.map(\.displayCode).joined(separator: ", "))"))
        case 1:
            ForEach(subjects) { subject in
                VStack(alignment: .leading, spacing: 6) {
                    Text(subject.displayCode).fontWeight(.semibold)
                    ForEach(subject.units) { unit in
                        Text(String(localized: "\(L10n.key(unit.kind)) · \(unit.name) · début \(unit.start?.formatted(date: .abbreviated, time: .omitted) ?? String(localized: "à préciser"))"))
                    }
                }
            }
        case 2:
            Text(String(localized: "\(events.count) présentations et contrôles · \(subjects.filter(\.hasExam).count) examens finaux"))
        case 3:
            Text(String(localized: "\(requested) séances demandées, réparties selon les dates de début et les échéances."))
        case 4:
            Text(String(localized: "Prise en compte de tes jours libres, cours, travail et autres indisponibilités."))
        default:
            Text(finished ? String(localized: "Planning enregistré sur cet appareil.") : String(localized: "Finalisation des créneaux et des rappels."))
        }
    }
}
