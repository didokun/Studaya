import SwiftUI
import StoreKit

/// Every Premium entry point stays visible; authorization happens at its destination.
struct PremiumAccess<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @ObservedObject private var membership = Membership.shared
    @Environment(\.dismiss) private var dismiss
    @State private var checked = false
    @State private var restoring = false
    @State private var offers = false
    @State private var status: String?
    var body: some View {
        NavigationStack {
            Group {
                if !checked { ProgressView(String(localized: "Vérification de Premium…")) }
                else if membership.premium == true { content() }
                else if offers && membership.premium == false { PremiumOptions().padding(.horizontal) }
                else {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.checkmark").font(.largeTitle)
                        Text(String(localized: "Accès Studaya Premium")).font(.title2.bold())
                        Text(String(localized: "Déjà abonné ? Restaure tes achats avec le compte Apple utilisé pour Studaya.")).multilineTextAlignment(.center)
                        Button(restoring ? "Restauration…" : String(localized: "Restaurer mes achats")) {
                            restoring = true
                            Task {
                                defer { restoring = false }
                                do {
                                    try await AppStore.sync()
                                    await membership.refresh()
                                    if membership.premium == nil { status = String(localized: "Apple n’a pas pu vérifier ton achat. Réessaie plus tard.") }
                                    else if membership.premium == false { status = String(localized: "Aucun achat Studaya actif retrouvé pour ce compte dans cette boutique.") }
                                } catch { status = error.localizedDescription }
                            }
                        }.buttonStyle(Primary()).disabled(restoring)
                        if let status { Text(status).font(.footnote) }
                        if membership.premium == false {
                            Button(String(localized: "Voir les offres")) { offers = true }.disabled(restoring)
                        }
                    }.padding()
                }
            }.studyScreen().navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Fermer")) { dismiss() }.accessibilityIdentifier("premium.close") } }
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
            Label("Premium", systemImage: "sparkles").font(.caption.weight(.semibold)).foregroundStyle(StudyDesign.accent)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(StudyDesign.accent.opacity(0.1), in: Capsule())
        }.accessibilityElement(children: .combine).accessibilityLabel(title).accessibilityValue("Premium")
    }
}
