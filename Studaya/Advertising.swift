import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform

/// Consentement publicitaire (UMP) et initialisation du SDK, une seule fois.
/// Aucune requête publicitaire tant que le consentement n’est pas obtenu.
@MainActor final class AdConsent: ObservableObject {
    static let shared = AdConsent()
    @Published var ready = false
    @Published var needsOptions = false
    private var preparation: Task<Void, Never>?
    private var prepared = false
    private var started = false

    func prepare() async {
        if let preparation { await preparation.value; return }
        guard !prepared else { return }
        let task = Task { @MainActor in
            let info = ConsentInformation.shared
            do {
                try await info.requestConsentInfoUpdate(with: RequestParameters())
                try await ConsentForm.loadAndPresentIfRequired(from: nil)
                self.prepared = true
            } catch {
                // UMP may still authorize requests using consent from a previous session.
            }
            await self.refreshPermission()
        }
        preparation = task
        await task.value
        preparation = nil
    }

    func refreshPermission() async {
        let info = ConsentInformation.shared
        needsOptions = info.privacyOptionsRequirementStatus == .required
        if info.canRequestAds, !started {
            _ = await MobileAds.shared.start()
            started = true
        }
        ready = info.canRequestAds && started
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
                        await consent.refreshPermission()
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
    static func isEligible(premium: Bool?, age: Int) -> Bool { premium == false && isAdult(age) }
}

/// Identifiants fournis par les réglages de build (STUDAYA_ADMOB_*, via Info.plist).
/// Vide = aucune pub demandée. Debug utilise les identifiants de test Google.
enum AdUnits {
    static var bannerID: String { Bundle.main.object(forInfoDictionaryKey: "StudayaBannerID") as? String ?? "" }
    static var interstitialID: String { Bundle.main.object(forInfoDictionaryKey: "StudayaInterstitialID") as? String ?? "" }
}

/// Bannière identifiée en haut des écrans et dans les listes de révision. Jamais pour Premium, ni sans consentement.
struct BrowsingBanner: View {
    @ObservedObject private var membership = Membership.shared
    @ObservedObject private var consent = AdConsent.shared
    @AppStorage(AdPolicy.ageKey) private var age = 0
    @State private var loaded = false

    private var eligible: Bool { AdPolicy.isEligible(premium: membership.premium, age: age) }

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
        banner.rootViewController = AdvertisingPresentation.root
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
    /// Adds a clearly labelled header only for eligible, consenting free users.
    func browsingAdvertising(_ enabled: Bool) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            if enabled { BrowsingBanner() }
        }
    }
}

/// One global cooldown across every successful completion, persisted across launches.
enum AdFrequencyPolicy {
    static let interval: TimeInterval = 3600
    static func allows(last: Date?, now: Date = .now) -> Bool {
        guard let last else { return true }
        return now.timeIntervalSince(last) >= interval
    }
}

@MainActor private enum AdvertisingPresentation {
    static var root: UIViewController? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?.windows.first { $0.isKeyWindow }?.rootViewController
    }
    static var top: UIViewController? {
        var controller = root
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
}

/// Full screen only at a completed action; never displayed later when loading finishes.
@MainActor final class SessionAdvertising: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = SessionAdvertising()
    private static let lastShownKey = "studaya.ads.lastInterstitialImpression"
    private var ad: InterstitialAd?
    private var loadedAt: Date?
    private var loading = false
    private var presenting = false
    private var scheduled = false

    private var eligible: Bool {
        AdPolicy.isEligible(premium: Membership.shared.premium, age: StudyPreferences.current.integer(forKey: AdPolicy.ageKey))
            && !AdUnits.interstitialID.isEmpty
            && AdFrequencyPolicy.allows(last: StudyPreferences.current.object(forKey: Self.lastShownKey) as? Date)
    }

    func preload() async {
        guard eligible, !loading, !presenting else { return }
        if let loadedAt, ad != nil, Date.now.timeIntervalSince(loadedAt) < 3500 { return }
        loading = true
        defer { loading = false }
        await AdConsent.shared.prepare()
        guard AdConsent.shared.ready, eligible else { return }
        do {
            let loaded = try await InterstitialAd.load(with: AdUnits.interstitialID, request: Request())
            guard eligible else { return }
            loaded.fullScreenContentDelegate = self
            ad = loaded
            loadedAt = .now
        } catch { ad = nil; loadedAt = nil }
    }

    func showAtCompletion() {
        guard !scheduled, !presenting, eligible else { return }
        scheduled = true
        Task { @MainActor in
            // Give the successfully saved form time to dismiss before presenting.
            try? await Task.sleep(for: .milliseconds(650))
            scheduled = false
            let preferences = StudyPreferences.current
            let working = preferences.double(forKey: "timerEnd") > Date.now.timeIntervalSince1970
                && !preferences.bool(forKey: "timerRest")
            guard eligible, !working, !presenting, UIApplication.shared.applicationState == .active,
                  AdConsent.shared.ready, ConsentInformation.shared.canRequestAds else { return }
            guard let loaded = ad, let loadedAt, Date.now.timeIntervalSince(loadedAt) < 3500 else {
                await preload()
                return
            }
            guard let controller = AdvertisingPresentation.top,
                  !controller.isBeingDismissed, !controller.isBeingPresented,
                  controller.viewIfLoaded?.window != nil else { return }
            do {
                try loaded.canPresent(from: controller)
                presenting = true
                loaded.present(from: controller)
            } catch { ad = nil; self.loadedAt = nil; await preload() }
        }
    }

    func adDidRecordImpression(_ ad: any FullScreenPresentingAd) {
        StudyPreferences.current.set(Date.now, forKey: Self.lastShownKey)
    }
    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        presenting = false; self.ad = nil; loadedAt = nil
        Task { await preload() }
    }
    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        presenting = false; self.ad = nil; loadedAt = nil
        Task { await preload() }
    }
}
