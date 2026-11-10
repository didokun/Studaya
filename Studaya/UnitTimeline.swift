import SwiftUI

enum TimelineOrder {
    static func dropping(_ id: UUID, on target: UUID, in ids: [UUID]) -> [UUID]? {
        guard id != target, let from = ids.firstIndex(of: id), let to = ids.firstIndex(of: target) else { return nil }
        var result = ids
        result.remove(at: from)
        result.insert(id, at: to)
        return result
    }

    static func chapters(_ chapters: [Chapter]) -> [Chapter] {
        chapters.sorted {
            if $0.timelineIndex != $1.timelineIndex { return ($0.timelineIndex ?? Int.max) < ($1.timelineIndex ?? Int.max) }
            if $0.startDate != $1.startDate { return ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
        }
    }
}

struct UnitTimeline<Card: View>: View {
    let ids: [UUID]
    let move: ([UUID]) -> Void
    @ViewBuilder var card: (UUID) -> Card
    @State private var target: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 2) {
                        Text("\(index + 1)").font(.caption.bold().monospacedDigit())
                            .frame(width: 27, height: 27).background(Color.mintBrand.opacity(0.22), in: Circle())
                        if index < ids.count - 1 { Rectangle().fill(Color.mintBrand.opacity(0.45)).frame(width: 2) }
                    }.accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        HStack(alignment: .top) {
                            card(id).frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
                                .frame(width: 36, height: 44).contentShape(Rectangle())
                                .draggable(id.uuidString)
                                .accessibilityLabel("Déplacer la séance \(index + 1)")
                        }
                    }.padding(12).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).stroke(target == id ? Color.mintBrand : Color.secondary.opacity(0.18), lineWidth: target == id ? 2 : 1) }
                    .padding(.bottom, 10)
                }
                .dropDestination(for: String.self) { values, _ in
                    guard let text = values.first, let source = UUID(uuidString: text),
                          let order = TimelineOrder.dropping(source, on: id, in: ids) else { return false }
                    move(order); return true
                } isTargeted: { active in if active { target = id } else if target == id { target = nil } }
                .contextMenu {
                    if index > 0 { Button("Monter d’une place") { shift(id, to: ids[index-1]) } }
                    if index+1 < ids.count { Button("Descendre d’une place") { shift(id, to: ids[index+1]) } }
                }
            }
        }
    }
    private func shift(_ id: UUID, to destination: UUID) {
        if let order = TimelineOrder.dropping(id, on: destination, in: ids) { move(order) }
    }
}
