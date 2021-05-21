//
// Copyright (c) 2021 Adyen N.V.
//
// This file is open source and available under the MIT license. See the LICENSE file for more info.
//

import Foundation

/**
 The data supplied by a payment component upon completion.

 - SeeAlso:
 [API Reference](https://docs.adyen.com/api-explorer/#/CheckoutService/latest/post/payments__example_payments-klarna)
 */
public struct PaymentComponentData {
    
    /// The payment method details submitted by the payment component.
    public let paymentMethod: PaymentMethodDetails
    
    /// Indicates whether the user has chosen to store the payment method.
    public let storePaymentMethod: Bool

    /// The partial payment order if any.
    public let order: PartialPaymentOrder?

    /// The payment amount.
    public let amount: Amount?

    /// Shopper name.
    public var shopperName: ShopperName? {
        guard let shopperInfo = paymentMethod as? ShopperInformation else { return nil }
        return shopperInfo.shopperName
    }

    /// The email address.
    public var emailAddress: String? {
        guard let shopperInfo = paymentMethod as? ShopperInformation else { return nil }
        return shopperInfo.emailAddress
    }

    /// The telephone number.
    public var telephoneNumber: String? {
        guard let shopperInfo = paymentMethod as? ShopperInformation else { return nil }
        return shopperInfo.telephoneNumber
    }
    
    /// Indicates the device default browser info.
    public let browserInfo: BrowserInfo?

    /// The billing address information.
    public var billingAddress: PostalAddress? {
        guard let shopperInfo = paymentMethod as? BillingAddressInformation else { return nil }
        return shopperInfo.billingAddress
    }
    
    /// Initializes the payment component data.
    ///
    /// :nodoc:
    ///
    /// - Parameters:
    ///   - paymentMethodDetails: The payment method details submitted from the payment component.
    ///   - amount: The payment amount.
    ///   - order: The partial payment order if any.
    ///   - storePaymentMethod: Whether the user has chosen to store the payment method.
    ///   - browserInfo: The device default browser info.
    public init(paymentMethodDetails: PaymentMethodDetails,
                amount: Amount?,
                order: PartialPaymentOrder?,
                storePaymentMethod: Bool = false,
                browserInfo: BrowserInfo? = nil) {
        self.paymentMethod = paymentMethodDetails
        self.storePaymentMethod = storePaymentMethod
        self.browserInfo = browserInfo
        self.order = order
        self.amount = amount
    }
    
    /// Creates a new `PaymentComponentData` by populating the `browserInfo`,
    /// in case the browser info like the user-agent is needed, but its not needed for mobile payments.
    ///
    /// - Parameters:
    ///   - completion: The completion closure that is called with the new `PaymentComponentData` instance.
    public func dataByAddingBrowserInfo(completion: @escaping ((_ newData: PaymentComponentData) -> Void)) {
        BrowserInfo.initialize {
            completion(PaymentComponentData(paymentMethodDetails: paymentMethod,
                                            amount: amount,
                                            order: order,
                                            storePaymentMethod: storePaymentMethod,
                                            browserInfo: $0))
        }
    }
    
}
