//
// Copyright (c) 2020 Adyen N.V.
//
// This file is open source and available under the MIT license. See the LICENSE file for more info.
//

import Adyen
import Foundation
import PassKit

internal struct Configuration {
    // swiftlint:disable explicit_acl
    
    static let environment = DemoServerEnvironment.test
    
    static let appName = "Adyen Demo"
    
    static let amount = Payment.Amount(value: 17408, currencyCode: "EUR")
    
    static let reference = "Test Order Reference - iOS UIHost"
    
    static let countryCode = "NL"
    
    static let returnUrl = "ui-host://"
    
    static let shopperReference = "iOS Checkout Shopper"
    static let merchantAccount = "SpinAccount095ECOM"
    
    static let shopperEmail = "checkoutshopperios@example.org"
    
    static let additionalData = ["allow3DS2": true]
    
    // swiftlint:disable:next line_length
    static let cardPublicKey = "10001|A1CDD3E6D9A4D57345623794E987199F4B9EDAB7D137995667A7EDA317B7A2B397F604972684AA9454B15B272A6C8CA78E3A6DADF0CF57A5FD32543FD4357ACEB00D5D9C7FD0FC41506F94189E18981240EAA43DA743F22525A47C982C485D2DA1D450276A33F57283AE36042C8C9499A2871DFC23D1DF9CDF5925BBF4FDA1484720F76FA594A21722B07907D3F9B85CA066AC75F6718C3F3B419ED0DE8325B69C436A25085A7273AF855819AD52E498290455618C6B2EB37BCBAD07C29ACD4A7370C998086130BC3C893D206EA7DCF14723CFB2A9DFC7D2C5CEE739B2A6AB2C184DE8F427EB44BAF9341FF8BE81C76DAFC2283AAEABE3E2B9EEEABE2C98D2E9"
    
    // swiftlint:disable:next line_length
    static let demoServerAPIKey = "AQEphmfuXNWTK0Qc+iSDgm02hueYR55DGcMTDWlE1rNRjS1UduCj/CcjoG4QwV1bDb7kfNy1WIxIIkxgBw==-HVMl6ri9a3R23e5A3zeRll3j3ztqGuuDu290HGCqqsw=-p5)54AtT#@d9_8PU"

    
    static let applePayMerchantIdentifier = "merchant.pm.spin"

    static let applePaySummaryItems = [
        PKPaymentSummaryItem(label: "Total", amount: NSDecimalNumber(string: "174.08"), type: .final)
    ]
    
    // swiftlint:enable explicit_acl
    
}
