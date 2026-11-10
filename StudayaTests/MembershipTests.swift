import XCTest
import StoreKit
import StoreKitTest
@testable import Studaya

@MainActor final class MembershipTests: XCTestCase {
    func testRenewalFallbackRejectsExpiredRefundedAndUpgradedPurchases() {
        let now = Date(), future = now.addingTimeInterval(3600)
        XCTAssertTrue(Membership.isCurrentRenewal(expiration: future, revoked: false, upgraded: false, now: now))
        XCTAssertFalse(Membership.isCurrentRenewal(expiration: now, revoked: false, upgraded: false, now: now))
        XCTAssertFalse(Membership.isCurrentRenewal(expiration: nil, revoked: false, upgraded: false, now: now))
        XCTAssertFalse(Membership.isCurrentRenewal(expiration: future, revoked: true, upgraded: false, now: now))
        XCTAssertFalse(Membership.isCurrentRenewal(expiration: future, revoked: false, upgraded: true, now: now))
    }
    func testTestStoreOffersAndUnlocksPremium() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Studaya", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let offers = try await Product.products(for: Membership.products)
        XCTAssertEqual(Set(offers.map(\.id)), Set(Membership.products))
        let yearly = try XCTUnwrap(offers.first { $0.id == "studaya.premium.yearly" })
        guard case .success(.verified(let transaction)) = try await yearly.purchase() else {
            XCTFail("Transaction annuelle non vérifiée"); return
        }
        await transaction.finish()
        await Membership.shared.refresh()
        XCTAssertTrue(Membership.shared.activeIDs.contains(yearly.id))
    }
}
