//
//  AssetsAccessTests.swift
//  AdyenUIKitTests
//
//  Created by Mohamed Eldoheiri on 12/24/20.
//  Copyright © 2020 Adyen. All rights reserved.
//

@testable import Adyen
#if canImport(AdyenActions)
@testable import AdyenActions
#endif
#if canImport(AdyenCard)
@testable import AdyenCard
#endif
import XCTest

class AssetsAccessTests: XCTestCase {

    func testCoreResourcesAccess() throws {
        XCTAssertNotNil(UIImage(named: "verification_false", in: Bundle.coreInternalResources, compatibleWith: nil))
    }

    func testActionResourcesAccess() throws {
        XCTAssertNotNil(UIImage(named: "mbway", in: Bundle.actionsInternalResources, compatibleWith: nil))
        XCTAssertNotNil(UIImage(named: "blik", in: Bundle.actionsInternalResources, compatibleWith: nil))
    }

    func testCardResourcesAccess() throws {
        XCTAssertNotNil(UIImage(named: "ic_card_back", in: Bundle.cardInternalResources, compatibleWith: nil))
        XCTAssertNotNil(UIImage(named: "ic_card_front", in: Bundle.cardInternalResources, compatibleWith: nil))
    }
}
