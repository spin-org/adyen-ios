//
// Copyright (c) 2021 Adyen N.V.
//
// This file is open source and available under the MIT license. See the LICENSE file for more info.
//

import Adyen
import UIKit

internal protocol VoucherViewDelegate: AnyObject {

    func didComplete(presentingViewController: UIViewController)

    func saveAsImage(voucherView: UIView, presentingViewController: UIViewController)
    
    func download(url: URL, voucherView: UIView, presentingViewController: UIViewController)
}

internal class AbstractVoucherView: UIView, Localizable {

    internal weak var delegate: VoucherViewDelegate?

    internal struct Model {
        
        internal enum ShareButton {
            
            case saveImage
            
            case download(URL)
            
        }

        internal let separatorModel: VoucherSeparatorView.Model
        
        internal let shareButton: ShareButton

        internal let shareButtonTitle: String

        internal let doneButtonTitle: String

        internal let style: Style

        internal struct Style {

            internal let mainButtonStyle: ButtonStyle

            internal let secondaryButtonStyle: ButtonStyle

            internal let backgroundColor: UIColor
        }
    }

    internal var localizationParameters: LocalizationParameters?

    internal weak var presenter: UIViewController?

    /// Ugly hack to work around the following bug
    /// https://stackoverflow.com/questions/59413850/uiactivityviewcontroller-dismissing-current-view-controller-after-sharing-file
    private lazy var fakeViewController: UIViewController = {
        let viewController = UIViewController()
        presenter?.addChild(viewController)
        presenter?.view.insertSubview(viewController.view, at: 0)
        viewController.view.frame = .zero
        viewController.didMove(toParent: presenter)
        return viewController
    }()

    private lazy var voucherView: VoucherCardView = {
        let topView = createTopView()
        let bottomView = createBottomView()

        return VoucherCardView(model: model.separatorModel,
                               topView: topView,
                               bottomView: bottomView)
    }()

    private lazy var saveButton: UIButton = {
        let accessibilityIdentifier = ViewIdentifierBuilder.build(scopeInstance: "adyen.voucher", postfix: "saveButton")

        return createButton(with: model.style.mainButtonStyle,
                            title: model.shareButtonTitle,
                            action: #selector(shareVoucher),
                            accessibilityIdentifier: accessibilityIdentifier)
    }()

    private lazy var doneButton: UIButton = {
        let accessibilityIdentifier = ViewIdentifierBuilder.build(scopeInstance: "adyen.voucher", postfix: "doneButton")

        return createButton(with: model.style.secondaryButtonStyle,
                            title: model.doneButtonTitle,
                            action: #selector(done),
                            accessibilityIdentifier: accessibilityIdentifier)
    }()

    private func createButton(with style: ButtonStyle,
                              title: String,
                              image: UIImage? = nil,
                              action: Selector,
                              accessibilityIdentifier: String) -> UIButton {
        let button = UIButton(style: style)
        button.setTitle(title, for: .normal)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityIdentifier = accessibilityIdentifier

        return button
    }

    private let model: Model

    internal init(model: Model) {
        self.model = model
        super.init(frame: .zero)
        buildUI()
        backgroundColor = model.style.backgroundColor
    }

    private func buildUI() {
        addVoucherView()
        addShareButton()
        addDoneButton()
    }

    @available(*, unavailable)
    internal required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal func createTopView() -> UIView {
        fatalError("This is an abstract class that needs to be subclassed.")
    }

    internal func createBottomView() -> UIView {
        fatalError("This is an abstract class that needs to be subclassed.")
    }

    override internal func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        updateLayout()
    }

    override internal func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }

    private func updateLayout() {
        saveButton.adyen.round(using: model.style.mainButtonStyle.cornerRounding)
        doneButton.adyen.round(using: model.style.secondaryButtonStyle.cornerRounding)
    }

    private func addVoucherView() {
        voucherView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(voucherView)

        voucherView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        voucherView.topAnchor.constraint(equalTo: topAnchor, constant: 20).isActive = true
        voucherView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20).isActive = true
    }

    private func addShareButton() {
        addSubview(saveButton)
        saveButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18).isActive = true
        saveButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18).isActive = true
        saveButton.topAnchor.constraint(equalTo: voucherView.bottomAnchor, constant: 30).isActive = true
    }

    private func addDoneButton() {
        addSubview(doneButton)
        doneButton.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: -24).isActive = true
        doneButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18).isActive = true
        doneButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18).isActive = true
        doneButton.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 16).isActive = true
    }

    @objc private func shareVoucher() {
        switch model.shareButton {
        case .saveImage:
            delegate?.saveAsImage(voucherView: voucherView, presentingViewController: fakeViewController)
        case let .download(url):
            delegate?.download(url: url, voucherView: voucherView, presentingViewController: fakeViewController)
        }
    }

    @objc private func done() {
        delegate?.didComplete(presentingViewController: fakeViewController)
    }

}
