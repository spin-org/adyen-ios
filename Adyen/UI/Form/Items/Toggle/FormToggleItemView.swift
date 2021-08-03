//
// Copyright (c) 2021 Adyen N.V.
//
// This file is open source and available under the MIT license. See the LICENSE file for more info.
//

import UIKit

/// A view representing a switch item.
/// :nodoc:
public final class FormToggleItemView: FormValueItemView<Bool, FormToggleItemStyle, FormToggleItem> {
    
    /// Initializes the switch item view.
    ///
    /// - Parameter item: The item represented by the view.
	public required init(item: FormToggleItem) {
		super.init(item: item)
		titleLabel = {
			let titleLabel = TextCheckingLabel(style: item.style.title)
		 
			if let string = item.title, string == localizedString(.payment_authorize, nil) {
				titleLabel.touchHandler = { textCheckingResult in
					guard let url = textCheckingResult.url else {
                        adyenPrint("No url for label: \(titleLabel)")
                        return
                    }
					
					UIApplication.shared.open(url)
				}
				titleLabel.attributedText = {
					let mas = NSMutableAttributedString(string: string)
					let range = mas.mutableString.range(of: localizedString(.spin_terms, nil))
					
					mas.addAttributes([.link: URL(string: "https://www.spin.pm/legal?tab=terms#terms-tab")!, .underlineStyle: NSUnderlineStyle.single.rawValue], range: range)
					return mas
				}()
				titleLabel.usesGestureRecognizer = true
			} else {
				titleLabel.text = item.title
			}
		
			titleLabel.numberOfLines = 0
			titleLabel.isAccessibilityElement = false
			titleLabel.accessibilityIdentifier = item.identifier.map { ViewIdentifierBuilder.build(scopeInstance: $0, postfix: "titleLabel") }

			return titleLabel
		}()
		
		showsSeparator = false
		
		isAccessibilityElement = true
		accessibilityLabel = item.title
		accessibilityTraits = switchControl.accessibilityTraits
		accessibilityValue = switchControl.accessibilityValue
		
		addSubview(stackView)
		stackView.adyen.anchor(inside: self.layoutMarginsGuide)
	}
    
    // MARK: - Switch Control
    
    internal lazy var switchControl: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = item.value
        switchControl.onTintColor = item.style.tintColor
        switchControl.isAccessibilityElement = false
        switchControl.addTarget(self, action: #selector(switchControlValueChanged), for: .valueChanged)
        switchControl.setContentHuggingPriority(.required, for: .horizontal)
        switchControl.accessibilityIdentifier = item.identifier.map { ViewIdentifierBuilder.build(scopeInstance: $0, postfix: "switch") }
        
        return switchControl
    }()
    
    @objc private func switchControlValueChanged() {
        accessibilityValue = switchControl.accessibilityValue
        item.value = switchControl.isOn
    }
    
    /// :nodoc:
    @discardableResult
    override public func accessibilityActivate() -> Bool {
        switchControl.isOn = !switchControl.isOn
        switchControlValueChanged()
        
        return true
    }
    
    // MARK: - Stack View
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, switchControl])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 8.0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        return stackView
    }()

}
