import SwiftUI
import StoreKit
import OSLog

@MainActor final class Membership: ObservableObject {
    static let shared = Membership()
    static let products = ["studaya.premium.monthly", "studaya.premium.yearly", "studaya.premium.lifetime"]
    @Published private(set) var premium: Bool?
    @Published private(set) var activeIDs = Set<String>()
    private var refreshGeneration = 0
    func refresh() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        var verificationFailed = false
        var active = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .unverified(let transaction, _) = result, Self.products.contains(transaction.productID) { verificationFailed = true }
            if case .verified(let transaction) = result, Self.products.contains(transaction.productID),
               transaction.revocationDate == nil, !transaction.isUpgraded { active.insert(transaction.productID) }
        }
        // A device can have a verified renewal in its transaction history
        // before the current-entitlements sequence reflects it.
        if active.isEmpty && !verificationFailed {
            for id in Self.products where id != "studaya.premium.lifetime" {
                guard !Task.isCancelled else { return }
                switch await Transaction.latest(for: id) {
                case .verified(let renewal):
                    if renewal.productID == id, Self.isCurrentRenewal(expiration: renewal.expirationDate,
                       revoked: renewal.revocationDate != nil, upgraded: renewal.isUpgraded, now: .now) {
                        active.insert(id)
                    }
                case .unverified: verificationFailed = true
                case nil: break
                }
            }
        }
        guard generation == refreshGeneration, !Task.isCancelled else { return }
        activeIDs = active
        premium = active.isEmpty && verificationFailed ? nil : !active.isEmpty
    }
    static func isCurrentRenewal(expiration: Date?, revoked: Bool, upgraded: Bool, now: Date) -> Bool {
        guard !revoked, !upgraded, let expiration else { return false }
        return expiration > now
    }
    func observe() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result, Self.products.contains(transaction.productID) {
                await refresh()
                await transaction.finish()
            }
        }
    }
}

struct PremiumOptions: View {
    var onContinue: (() -> Void)? = nil
    @ObservedObject private var membership = Membership.shared
    @State private var catalog: [Product] = []
    @State private var selected = "studaya.premium.monthly"
    @State private var busy = false
    @State private var message: String?
    @State private var loaded = false
    @State private var loadingPrices = false
    @State private var priceMessage: String?
    @State private var priceDiagnostics = ""
    private static let logger = Logger(subsystem: "com.talinha.studaya", category: "StoreKit")
    @State private var managing = false
    @State private var trialIDs = Set<String>()
    private var offersTrial: Bool { trialIDs.contains(selected) }

    private var product: Product? { catalog.first { $0.id == selected } }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Studaya Premium").font(.largeTitle.bold())
                    VStack(alignment: .leading, spacing: 12) {
                        perk(String(localized: "Importer un planning depuis une photo"), "camera.viewfinder")
                        perk(String(localized: "Bilan de concentration sur 30 jours"), "chart.bar")
                        perk(String(localized: "Temps étudié par matière"), "books.vertical")
                        
                        perk(String(localized: "Exporter les sessions Focus en CSV"), "square.and.arrow.up")
                    }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.navy.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
                    if membership.premium == true {
                        Label(String(localized: "Premium is active"), systemImage: "checkmark.seal.fill")
                        ForEach(membership.activeIDs.sorted(), id: \.self) { id in
                            LabeledContent(String(localized: "Current plan")) {
                                Text(planTitle(id))
                            }
                        }
                        if membership.activeIDs.contains(where: { !$0.hasSuffix("lifetime") }) {
                            Button { managing = true } label: {
                                Label(String(localized: "Change or cancel subscription"), systemImage: "slider.horizontal.3")
                            }.buttonStyle(.borderedProminent)
                        }
                    } else {
                        ForEach(Membership.products, id: \.self) { id in
                            planRow(id)
                        }
                        if loaded && catalog.count < Membership.products.count {
                            #if DEBUG
                            Text(String(localized: "Pour tester des achats fictifs, utilise le schéma Studaya dans Xcode.")).font(.footnote)
                            #endif
                            if let priceMessage { Text(priceMessage).font(.footnote).foregroundStyle(.secondary) }
                            Button(loadingPrices ? "Loading…" : String(localized: "Reload prices")) { Task { await load() } }
                                .disabled(loadingPrices || busy)
                            if !priceDiagnostics.isEmpty {
                                DisclosureGroup(String(localized: "Purchase support details")) {
                                    Text(verbatim: priceDiagnostics).font(.caption.monospaced())
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }.font(.footnote)
                            }
                        }
                        if offersTrial, let product {
                            Text(selected.hasSuffix("monthly") ? String(localized: "7 days free, then \(product.displayPrice) per month.") : String(localized: "7 days free, then \(product.displayPrice) per year."))
                                .font(.headline)
                        }
                        Text(selected.hasSuffix("lifetime") ? String(localized: "One payment for lifetime access.") : String(localized: "Renews automatically until canceled."))
                            .font(.footnote).foregroundStyle(.secondary)
                        Button(String(localized: "Restore purchases")) { Task { await restore() } }.disabled(busy)
                    }
                    if let message { Text(message).font(.footnote) }
                    Link(String(localized: "Apple Standard EULA"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        .font(.footnote)
                }.padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 3) {
                if membership.premium != true {
                    Button( selected.hasSuffix("lifetime") ? String(localized: "Get lifetime access") : offersTrial ? String(localized: "Start my 7-day free trial") : String(localized: "Subscribe to Premium")) {
                        Task { await buy() }
                    }.buttonStyle(Primary()).disabled(product == nil || busy).opacity(product == nil || busy ? 0.6 : 1)
                }
                if let onContinue {
                    Button(membership.premium == true ? String(localized: "Done") : String(localized: "Continuer gratuitement"), action: onContinue)
                        .font(.subheadline).frame(minHeight: 44).disabled(busy)
                }
            }.padding(.vertical, 6)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await load() }
        .manageSubscriptionsSheet(isPresented: $managing)
        .onChange(of: managing) { _, open in
            if !open { Task { await membership.refresh(); await load() } }
        }
    }

    private func perk(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
    }

    private func planTitle(_ id: String) -> String {
        if id.hasSuffix("monthly") { return String(localized: "Monthly") }
        if id.hasSuffix("yearly") { return String(localized: "Annual") }
        return String(localized: "Lifetime")
    }

    private func planRow(_ id: String) -> some View {
        let item = catalog.first { $0.id == id }
        let title = planTitle(id)
        return Button {
            selected = id
            message = nil
        } label: {
            HStack {
                Image(systemName: selected == id ? "checkmark.circle.fill" : "circle")
                Text(title).font(.headline)
                Spacer()
                if let item { Text(item.displayPrice).font(.title3.bold()) }
                else { Text(loaded ? String(localized: "Unavailable") : "Loading…").font(.caption) }
            }.padding(16).frame(maxWidth: .infinity)
            .background(selected == id ? Color.mintBrand.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.mintBrand.opacity(selected == id ? 1 : 0.25)) }
            .contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(item == nil || busy)
        .accessibilityAddTraits(selected == id ? .isSelected : [])
    }

    private func load() async {
        guard !loadingPrices else { return }
        loadingPrices = true
        defer { loadingPrices = false }
        priceMessage = nil
        priceDiagnostics = ""
        let storefront = await Storefront.current
        let bundle = Bundle.main.bundleIdentifier ?? "unknown"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let context = String(localized: "App: \(bundle)\nVersion: \(version) (\(build))\nStorefront: \(storefront?.countryCode ?? "unknown")")
        do {
            // Only replace a previously loaded catalog after a successful response.
            catalog = try await Product.products(for: Membership.products)
            let returned = Set(catalog.map(\.id))
            let missing = Membership.products.filter { !returned.contains($0) }
            if !missing.isEmpty {
                priceMessage = catalog.isEmpty
                    ? String(localized: "The App Store returned no Premium offers. You can continue for free and try again later.")
                    : String(localized: "Some Premium offers are currently unavailable. You can choose an available offer or retry later.")
                priceDiagnostics = context + String(localized: "\nResult: \(catalog.count)/\(Membership.products.count) products\nMissing: ") + missing.joined(separator: ", ")
                Self.logger.notice("Incomplete product catalog: \(priceDiagnostics, privacy: .public)")
            }
        } catch {
            priceMessage = String(localized: "Couldn’t load prices from the App Store. Check your connection and try again.")
            let failure = error as NSError
            priceDiagnostics = context + String(localized: "\nError: \(failure.domain) (\(failure.code))")
            if let underlying = failure.userInfo[NSUnderlyingErrorKey] as? NSError {
                priceDiagnostics += String(localized: "\nUnderlying: \(underlying.domain) (\(underlying.code))")
            }
            Self.logger.error("Product request failed: \(priceDiagnostics, privacy: .public)")
        }
        if product == nil, let first = Membership.products.first(where: { id in catalog.contains { $0.id == id } }) {
            selected = first
        }
        var eligible = Set<String>()
        for item in catalog {
            guard let subscription = item.subscription,
                  let offer = subscription.introductoryOffer, offer.paymentMode == .freeTrial,
                  (offer.period.unit == .week && offer.period.value == 1 || offer.period.unit == .day && offer.period.value == 7),
                  offer.periodCount == 1, await subscription.isEligibleForIntroOffer else { continue }
            eligible.insert(item.id)
        }
        trialIDs = eligible
        loaded = true
    }

    private func buy() async {
        guard let product, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await membership.refresh()
                if membership.premium == true { onContinue?() }
            case .userCancelled: break
            case .pending: message = String(localized: "Purchase pending approval.")
            default: message = String(localized: "Purchase could not be verified.")
            }
        } catch { message = String(localized: "Purchase could not be completed.") }
    }

    private func restore() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await membership.refresh()
            if membership.premium != true { message = String(localized: "No active purchase found.") }
        } catch { message = String(localized: "Couldn’t restore purchases.") }
    }
}
