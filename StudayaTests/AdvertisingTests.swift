import XCTest
@testable import Studaya

final class AdvertisingTests: XCTestCase {
    func testAgeMustBeKnownAndAdult() {
        for age in [0, 13, 17] { XCTAssertFalse(AdPolicy.isAdult(age)) }
        XCTAssertTrue(AdPolicy.isAdult(18))
        XCTAssertTrue(AdPolicy.isAdult(65))
    }

    func testAdsWaitForMembershipAndExcludePremiumAndMinors() {
        XCTAssertFalse(AdPolicy.isEligible(premium: nil, age: 20))
        XCTAssertFalse(AdPolicy.isEligible(premium: true, age: 20))
        XCTAssertFalse(AdPolicy.isEligible(premium: false, age: 17))
        XCTAssertFalse(AdPolicy.isEligible(premium: false, age: 0))
        XCTAssertTrue(AdPolicy.isEligible(premium: false, age: 18))
    }

    func testGlobalCooldownIsAnElapsedHourAcrossMidnightAndRelaunches() {
        let impression = Date(timeIntervalSince1970: 86_390)
        XCTAssertTrue(AdFrequencyPolicy.allows(last: nil, now: impression))
        for elapsed in [-1.0, 0, 60, 3599] {
            XCTAssertFalse(AdFrequencyPolicy.allows(last: impression, now: impression.addingTimeInterval(elapsed)))
        }
        XCTAssertTrue(AdFrequencyPolicy.allows(last: impression, now: impression.addingTimeInterval(3600)))
        XCTAssertTrue(AdFrequencyPolicy.allows(last: impression, now: impression.addingTimeInterval(7200)))
    }
}
