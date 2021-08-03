import UIKit

extension NSMutableAttributedString {
	func setTextColor(_ color: UIColor) {
		setTextColor(color, range: NSRange(location: 0, length: length))
	}

	func setTextColor(_ color: UIColor, range: NSRange) {
		removeAttribute(.foregroundColor, range: range)
		addAttribute(.foregroundColor, value: color, range: range)
	}
}
