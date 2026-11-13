import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform

/// Consentement publicitaire (UMP) et initialisation du SDK, une seule fois.
/// Aucune requête publicitaire tant que le consentement n’est pas obtenu.
@MainActor final class AdConsent: ObservableObject {
    static let shared = AdConsent()
    @Published var ready = false
    @Published var needsOptions = false
    private var preparing = false

    func prepare() async {
        guard !preparing else { return }
        preparing = true
        defer { preparing = false }
        do {
            let info = ConsentInformation.shared
            try await info.requestConsentInfoUpdate(with: RequestParameters())
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
            needsOptions = info.privacyOptionsRequirementStatus == .required
            if info.canRequestAds {
                _ = await MobileAds.shared.start()
                ready = true
            }
        } catch { ready = false }
    }
}

/// Entrée « Choix publicitaires » à afficher dans les réglages quand le consentement l’exige.
struct AdvertisingPrivacyOptions: View {
    @ObservedObject private var consent = AdConsent.shared
    @State private var failed = false
    var body: some View {
        if consent.needsOptions {
            Button(String(localized: "Choix publicitaires")) {
                Task {
                    do {
                        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
                        consent.ready = ConsentInformation.shared.canRequestAds
                    } catch { failed = true }
                }
            }
            .alert(String(localized: "Impossible d’ouvrir les choix publicitaires"), isPresented: $failed) { Button("OK") {} }
        }
    }
}

/// Règle d’âge : aucune pub sans âge renseigné (0) ni pour les moins de 18 ans.
enum AdPolicy {
    static let ageKey = "studaya.profile.age"
    static func isAdult(_ age: Int) -> Bool { age >= 18 }
}

/// Identifiants fournis par les réglages de build (STUDAYA_ADMOB_*, via Info.plist).
/// Vide = aucune pub demandée. Debug utilise les identifiants de test Google.
enum AdUnits {
    static var bannerID: String { Bundle.main.object(forInfoDictionaryKey: "StudayaBannerID") as? String ?? "" }
    static var interstitialID: String { Bundle.main.object(forInfoDictionaryKey: "StudayaInterstitialID") as? String ?? "" }
}

/// Bannière 320 × 50 en bas des écrans de consultation. Jamais pour Premium, ni sans consentement.
private struct BrowsingBanner: View {
    @ObservedObject private var membership = Membership.shared
    @ObservedObject private var consent = AdConsent.shared
    @AppStorage(AdPolicy.ageKey) private var age = 0
    @State private var loaded = false

    private var eligible: Bool { membership.premium == false && AdPolicy.isAdult(age) }

    var body: some View {
        Group {
            if eligible && consent.ready && ConsentInformation.shared.canRequestAds && !AdUnits.bannerID.isEmpty {
                VStack(spacing: 4) {
                    Text(String(localized: "Publicité")).font(.caption2).foregroundStyle(.secondary)
                    BannerContainer(unit: AdUnits.bannerID, loaded: $loaded)
                        .frame(width: 320, height: 50)
                }
                .padding(.vertical, loaded ? 10 : 0)
                .frame(maxWidth: .infinity)
                .frame(height: loaded ? 82 : 0)
                .clipped()
                .allowsHitTesting(loaded)
                .background(Color(.systemBackground))
            }
        }
        .task(id: eligible) {
            if eligible && !AdUnits.bannerID.isEmpty { await consent.prepare() }
        }
    }
}

private struct BannerContainer: UIViewRepresentable {
    let unit: String
    @Binding var loaded: Bool

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = unit
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, BannerViewDelegate {
        var parent: BannerContainer
        init(parent: BannerContainer) { self.parent = parent }
        func bannerViewDidReceiveAd(_ bannerView: BannerView) { parent.loaded = true }
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            parent.loaded = false
        }
    }
}

extension View {
    /// Ajoute la bannière en bas de l’écran quand `enabled` est vrai (Accueil et Matières).
    func browsingAdvertising(_ enabled: Bool) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            if enabled { BrowsingBanner() }
        }
    }
}

/// Interstitiel à la fin d’une séance : au plus une fois par jour, jamais pour Premium.
@MainActor final class SessionAdvertising: ObservableObject {
    static let shared = SessionAdvertising()
    private static let lastShownKey = "interstitialLastShownDay"
    private var ad: InterstitialAd?

    private var eligible: Bool {
        Membership.shared.premium == false && AdPolicy.isAdult(UserDefaults.standard.integer(forKey: AdPolicy.ageKey))
            && !AdUnits.interstitialID.isEmpty && !shownToday
    }

    func preload() async {
        guard eligible else { return }
        await AdConsent.shared.prepare()
        guard AdConsent.shared.ready, eligible else { return }
        ad = try? await InterstitialAd.load(with: AdUnits.interstitialID, request: Request())
    }

    func showAtCompletion() {
        guard eligible, ConsentInformation.shared.canRequestAds, let loaded = ad else {
            Task { await preload() }
            return
        }
        ad = nil
        UserDefaults.standard.set(Self.today, forKey: Self.lastShownKey)
        loaded.present(from: nil)
        Task { await preload() }
    }

    private var shownToday: Bool {
        UserDefaults.standard.string(forKey: Self.lastShownKey) == Self.today
    }
    private static var today: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }
}
