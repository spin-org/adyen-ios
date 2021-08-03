import UIKit

protocol DisplayScalable {
	var displayScale: CGFloat { get }
}

/// Adjusts value to conform to a view's `displayScale`
/// Useful when determing the height of cells based on non-integral font sizes
func ceil(value: CGFloat, toDisplayScaleOfView view: DisplayScalable) -> CGFloat {
	let a = floor(value)

	if a == value {
		return value
	}

	var scale = view.displayScale
	let oneOverScale = 1.0 / scale
	let b = value - a
	let e = CGFloat(Double.ulpOfOne)

	scale = oneOverScale

	while scale < e {
		if scale > b {
			return a + scale
		}

		scale += oneOverScale
	}

	return a + 1.0
}

extension UIView: DisplayScalable {
	var displayScale: CGFloat {
		let s = traitCollection.displayScale

		if s > 0.0 {
			return s
		}

		return UIScreen.main.scale
	}
}

extension UIViewController: DisplayScalable {
	var displayScale: CGFloat {
		let s = traitCollection.displayScale

		if s > 0.0 {
			return s
		}

		return UIScreen.main.scale
	}
}
