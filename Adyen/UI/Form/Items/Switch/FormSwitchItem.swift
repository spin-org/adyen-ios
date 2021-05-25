//
// Copyright (c) 2020 Adyen N.V.
//
// This file is open source and available under the MIT license. See the LICENSE file for more info.
//

import Foundation

public protocol FormSwitchItemProtocol: FormValueItem {
    /// The switch item style.
    var style: FormSwitchItemStyle { get }
    /// The title displayed next to the switch.
    var title: String? { get set }
    /// :nodoc:
    var identifier: String? { get set }
}

public extension FormSwitchItemProtocol where ValueType == Bool {
    /// :nodoc:
    var value: Bool {
        get {
            let value = objc_getAssociatedObject(self, &FormSwitchItemAssociatedKeys.value) as? ValueType
            return value ?? false
        }
        set {
            objc_setAssociatedObject(self,
                                     &FormSwitchItemAssociatedKeys.value,
                                     newValue,
                                     objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            valueDidChange()
        }
    }
}

public extension FormSwitchItemProtocol {
    /// The switch item style.
    var style: FormSwitchItemStyle {
        get {
            let value = objc_getAssociatedObject(self, &FormSwitchItemAssociatedKeys.style) as? FormSwitchItemStyle
            return value ?? FormSwitchItemStyle()
        }
        set {
            objc_setAssociatedObject(self,
                                     &FormSwitchItemAssociatedKeys.style,
                                     newValue,
                                     objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// The title displayed next to the switch.
    var title: String? {
        get {
            objc_getAssociatedObject(self, &FormSwitchItemAssociatedKeys.title) as? String
        }
        set {
            objc_setAssociatedObject(self,
                                     &FormSwitchItemAssociatedKeys.title,
                                     newValue,
                                     objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// :nodoc:
    var identifier: String? {
        get {
            objc_getAssociatedObject(self, &FormSwitchItemAssociatedKeys.identifier) as? String
        }
        set {
            objc_setAssociatedObject(self,
                                     &FormSwitchItemAssociatedKeys.identifier,
                                     newValue,
                                     objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

private struct FormSwitchItemAssociatedKeys {
    internal static var value = "value"
    internal static var title = "title"
    internal static var style = "style"
    internal static var identifier = "identifier"
}


/// An item in which a switch is toggled, producing a boolean value.
/// :nodoc:
public final class FormSwitchItem: FormSwitchItemProtocol {
    
    @Observable(false) public var switchValue: Bool
    
    /// Initializes the switch item.
    ///
    /// - Parameter style: The switch item style.
    public init(style: FormSwitchItemStyle = FormSwitchItemStyle()) {
        self.style = style
        self.value = true
    }
    
    public func valueDidChange() {
        switchValue = value
    }
    
    /// :nodoc:
    public func build(with builder: FormItemViewBuilder) -> AnyFormItemView {
        builder.build(with: self)
    }
}

