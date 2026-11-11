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
        Group {
            ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                timelineRow(index: index, id: id)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder
    private func timelineRow(index: Int, id: UUID) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline line and badge
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.mintBrand.opacity(0.45))
                    .frame(width: 2, height: 8)
                    .opacity(index > 0 ? 1 : 0)

                ZStack {
                    Circle()
                        .fill(target == id ? Color.mintBrand : Color.mintBrand.opacity(0.2))
                        .frame(width: 28, height: 28)
                    Text("\(index + 1)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(target == id ? Color.white : Color.mintBrand)
                }

                Rectangle()
                    .fill(Color.mintBrand.opacity(0.45))
                    .frame(width: 2)
                    .opacity(index < ids.count - 1 ? 1 : 0)
            }
            .frame(width: 28)
            .accessibilityHidden(true)

            // Timeline Card
            HStack(alignment: .top, spacing: 8) {
                card(id)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(target == id ? Color.mintBrand : .secondary)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel(String(localized: "Déplacer l’élément \(index + 1)"))
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(target == id ? Color.mintBrand : Color.secondary.opacity(0.18), lineWidth: target == id ? 2 : 1)
            }
            .scaleEffect(target == id ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: target)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .draggable(id.uuidString) {
            HStack(spacing: 8) {
                Text("\(index + 1)").font(.caption.bold())
                    .frame(width: 22, height: 22)
                    .background(Color.mintBrand, in: Circle())
                    .foregroundStyle(.white)
                card(id)
            }
            .padding(10)
            .frame(maxWidth: 300, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 3)
        }
        .dropDestination(for: String.self) { values, _ in
            guard let text = values.first, let source = UUID(uuidString: text),
                  let order = TimelineOrder.dropping(source, on: id, in: ids) else { return false }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                move(order)
            }
            return true
        } isTargeted: { active in
            withAnimation(.easeInOut(duration: 0.15)) {
                if active { target = id } else if target == id { target = nil }
            }
        }
        .contextMenu {
            if index > 0 {
                Button {
                    shift(id, to: ids[index - 1])
                } label: {
                    Label(String(localized: "Monter d’une place"), systemImage: "arrow.up")
                }
                Button {
                    shift(id, to: ids[0])
                } label: {
                    Label(String(localized: "Placer en premier"), systemImage: "arrow.up.to.line")
                }
            }
            if index + 1 < ids.count {
                Button {
                    shift(id, to: ids[index + 1])
                } label: {
                    Label(String(localized: "Descendre d’une place"), systemImage: "arrow.down")
                }
                Button {
                    shift(id, to: ids[ids.count - 1])
                } label: {
                    Label(String(localized: "Placer en dernier"), systemImage: "arrow.down.to.line")
                }
            }
        }
    }
    private func shift(_ id: UUID, to destination: UUID) {
        if let order = TimelineOrder.dropping(id, on: destination, in: ids) { move(order) }
    }
}
