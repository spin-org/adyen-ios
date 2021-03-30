//
// Copyright (c) 2021 Adyen N.V.
//
// This file is open source and available under the MIT license. See the LICENSE file for more info.
//

import Adyen
#if canImport(AdyenCard)
    import AdyenCard
#endif
#if canImport(AdyenComponents)
    import AdyenComponents
#endif
#if canImport(AdyenActions)
    import AdyenActions
#endif
#if canImport(AdyenDropIn)
    import AdyenDropIn
#endif
import UIKit

internal protocol Presenter: AnyObject {

    func present(viewController: UIViewController, completion: (() -> Void)?)

    func dismiss(completion: (() -> Void)?)

    func presentAlert(withTitle title: String)

    func presentAlert(with error: Error, retryHandler: (() -> Void)?)
}

internal final class IntegrationExample: APIClientAware {
    internal let payment = Payment(amount: Configuration.amount, countryCode: Configuration.countryCode)
    internal let environment = Configuration.componentsEnvironment

    internal var paymentMethods: PaymentMethods?
    internal var currentComponent: PresentableComponent?

    internal weak var presenter: Presenter?

    internal var clientKey: String {
        if CommandLine.arguments.contains("-UITests") {
            return "local_DUMMYKEYFORTESTING"
        }
        return Configuration.clientKey
    }

    // MARK: - Action Handling for Components

    internal lazy var actionComponent: AdyenActionComponent = {
        let handler = AdyenActionComponent()
        handler.redirectComponentStyle = RedirectComponentStyle()
        handler.delegate = self
        handler.presentationDelegate = self
        handler.environment = environment
        handler.clientKey = clientKey
        return handler
    }()

    // MARK: - Networking

    internal func requestPaymentMethods() {
        let request = PaymentMethodsRequest()
        apiClient.perform(request) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(response):
                self.paymentMethods = response.paymentMethods
            case let .failure(error):
                self.presentAlert(with: error, retryHandler: self.requestPaymentMethods)
            }
        }
    }

    internal func finish(with resultCode: PaymentsResponse.ResultCode) {
        let success = resultCode == .authorised || resultCode == .received || resultCode == .pending
        currentComponent?.finalizeIfNeeded(with: success)

        presenter?.dismiss { [weak self] in
            // Payment is processed. Add your code here.
            self?.presentAlert(withTitle: resultCode.rawValue)
        }
    }

    internal func finish(with error: Error) {
        let isCancelled = (error as? ComponentError) == .cancelled
        currentComponent?.finalizeIfNeeded(with: false)

        presenter?.dismiss { [weak self] in
            // Payment is unsuccessful. Add your code here.
            if !isCancelled { self?.presentAlert(with: error) }
        }
    }

    internal func presentAlert(with error: Error, retryHandler: (() -> Void)? = nil) {
        presenter?.presentAlert(with: error, retryHandler: retryHandler)
    }

    internal func presentAlert(withTitle title: String) {
        presenter?.presentAlert(withTitle: title)
    }
}
