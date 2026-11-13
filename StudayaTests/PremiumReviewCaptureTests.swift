import XCTest
import SwiftUI
import StoreKit
import StoreKitTest
@testable import Studaya

@MainActor final class PremiumReviewCaptureTests: XCTestCase {
    func testRenderActualPremiumScreen() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "ReviewProducts", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let products = try await Product.products(for: Membership.products)
        XCTAssertEqual(products.count, 3)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = UIScreen.main.bounds
        window.rootViewController = UIHostingController(rootView:
            NavigationStack {
                PremiumOptions().padding(.horizontal).studyScreen().navigationTitle("Subscription").navigationBarTitleDisplayMode(.inline)
            }.font(.body).fontDesign(.rounded).tint(StudyDesign.accent).controlSize(.large)
        )
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(4))
        window.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Studaya-Premium-en-US"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
