import SwiftUI

/// Every Premium entry point stays visible; authorization happens at its destination.
struct PremiumAccess<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @ObservedObject private var membership = Membership.shared
    @Environment(\.dismiss) private var dismiss
    @State private var checked = false
    var body: some View {
        NavigationStack {
            Group {
                if !checked || membership.premium == nil { ProgressView("Vérification de Premium…") }
                else if membership.premium == true { content() }
                else { PremiumOptions().padding(.horizontal) }
            }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() }.accessibilityIdentifier("premium.close") } }
        }.task { await membership.refresh(); checked = true }
    }
}

struct PremiumFeatureLabel: View {
    let title: String
    let symbol: String
    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: symbol)
            Spacer(minLength: 8)
            Text("Premium").font(.caption.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.mintBrand.opacity(0.15), in: Capsule())
        }.accessibilityElement(children: .combine).accessibilityLabel(title).accessibilityValue("Premium")
    }
}
