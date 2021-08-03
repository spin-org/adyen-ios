import CoreText
import UIKit
import UIKit.UIGestureRecognizerSubclass

extension NSAttributedString.Key {
	// Use this in attributed strings to force an NSTextCheckingResult for a specific range
	static let textCheckingResult = NSAttributedString.Key(rawValue: "TextCheckingResultAttributeName")
}

/// A label that can be used to display web style links via attributed strings.
class TextCheckingLabel: UILabel {
	var textCheckingTypes: NSTextCheckingTypes = 0
	var textCheckingAttributes: [NSAttributedString.Key: Any]?
	var textCheckingResults: [NSTextCheckingResult] = []
	var touchHandler: ((_ textCheckingResult: NSTextCheckingResult) -> Void)?
	private lazy var labelTapGestureRecognizer = LabelTapGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
	var usesGestureRecognizer: Bool = false {
		didSet {
			guard oldValue != usesGestureRecognizer else {
				return
			}

			if usesGestureRecognizer {
				addGestureRecognizer(labelTapGestureRecognizer)
			} else {
				removeGestureRecognizer(labelTapGestureRecognizer)
			}
		}
	}

	private var _framesetter: CTFramesetter?
	private var textFrame: CTFrame?
	// original `NSTextCheckingResult` when `touchesBegan(_:) is first called` used to compare the touch as it moves in or out of the touch area to simulate behavior similar to `UIControl` and `UIButton`
	private var beganTextCheckingResult: NSTextCheckingResult?
	private var activeTextCheckingResult: NSTextCheckingResult?
	private var highlightPaths: [UIBezierPath]?
	private var isHighlightLayerLoaded = false
	private lazy var highlightLayer: CALayer = { [unowned self] in
		let highlightLayer = CALayer()

		highlightLayer.frame = self.layer.bounds.insetBy(dx: -3.0, dy: -3.0)
		self.layer.addSublayer(highlightLayer)
		self.isHighlightLayerLoaded = true
		return highlightLayer
	}()

	private static let framesetterCache: NSCache<NSAttributedString, CTFramesetter> = {
		let cache = NSCache<NSAttributedString, CTFramesetter>()

		cache.name = "LabelFramesetterCache"
		cache.countLimit = 51
		return cache
	}()

	private static func framesetter(for attributedString: NSAttributedString) -> CTFramesetter {
		if let framesetter = framesetterCache.object(forKey: attributedString) {
			return framesetter
		}

		let framesetter = CTFramesetterCreateWithAttributedString(attributedString)

		framesetterCache.setObject(framesetter, forKey: attributedString)
		return framesetter
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		clipsToBounds = false
		isOpaque = false
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		textCheckingTypes = NSTextCheckingTypes(coder.decodeInt64(forKey: "textCheckingTypes"))
		clipsToBounds = false
		isOpaque = false
	}

	convenience init() {
		self.init(frame: .zero)
	}

	override func encode(with coder: NSCoder) {
		if text == nil, attributedText == nil {
			text = ""
		}

		super.encode(with: coder)
		coder.encode(textCheckingTypes, forKey: "textCheckingTypes")
	}

	override var bounds: CGRect {
		didSet {
			if isHighlightLayerLoaded {
				highlightLayer.frame = layer.bounds.insetBy(dx: -3.0, dy: -3.0)
			}
		}
	}

	override var font: UIFont! {
		didSet {
			_framesetter = nil
			accessibilityElements = nil
		}
	}

	private func synthesize(attributedText: NSAttributedString) -> NSAttributedString {
		if numberOfLines != 1 {
			attributedText.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributedText.length), options: [.longestEffectiveRangeNotRequired], using: { value, range, stop in
				if let ps = value as? NSParagraphStyle {
					if lineBreakMode != ps.lineBreakMode {
						lineBreakMode = ps.lineBreakMode
					}

					stop.pointee = true
				}
			})

			switch lineBreakMode {
			case .byTruncatingHead:
				fallthrough
			case .byTruncatingMiddle:
				fallthrough
			case .byTruncatingTail:
				let mas = attributedText.mutableCopy() as! NSMutableAttributedString

				attributedText.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributedText.length), options: [], using: { value, range, stop in
					if let ps = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle {
						ps.lineBreakMode = .byWordWrapping
						CFAttributedStringSetAttribute(mas, CFRangeMake(range.location, range.length), NSAttributedString.Key.paragraphStyle as CFString, ps)
					}
				})

				return mas
			default:
				break
			}
		}

		return attributedText
	}

	private func check(text: Any) -> Any {
		guard textCheckingTypes != 0 else {
			textCheckingResults = []
			return text
		}

		do {
			let dd = try NSDataDetector(types: textCheckingTypes)

			var results: [NSTextCheckingResult] = []
			let string: String? = {
				if let text = text as? NSAttributedString {
					return text.string
				}

				return text as? String
			}()

			if let string = string {
				dd.enumerateMatches(in: string, options: [], range: NSRange(location: 0, length: string.count), using: { result, flags, stop in
					if let result = result {
						results.append(result)
					}

					textCheckingResults = results
				})
			} else {
				textCheckingResults = []
			}

			if textCheckingResults.count > 0 {
				if let text = text as? NSAttributedString {
					return text.mutableCopy() as! NSMutableAttributedString
				} else if let text = text as? String {
					return NSMutableAttributedString(string: text, attributes: [.font: font as Any, .foregroundColor: textColor as Any])
				}
			}
		} catch {
			print("\(error)")
		}

		return text
	}

	private func setAttributedText(for attributedString: NSAttributedString) {
		var results: [NSTextCheckingResult] = []

		attributedString.enumerateAttribute(.textCheckingResult, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, stop in
			if let value = value as? NSTextCheckingResult {
				results.append(value)
			}
		}
		attributedString.enumerateAttribute(.link, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, stop in
			if let value = value as? URL {
				results.append(NSTextCheckingResult.linkCheckingResult(range: range, url: value))
			} else if let value = value as? String, let url = URL(string: value) {
				results.append(NSTextCheckingResult.linkCheckingResult(range: range, url: url))
			}
		}

		textCheckingResults.append(contentsOf: results)

		if textCheckingResults.count > 0 {
			let mas = attributedString.mutableCopy() as! NSMutableAttributedString
			let hasTextColor = (textCheckingAttributes?[.foregroundColor] != nil) ? true : false

			for result in textCheckingResults {
				if let textCheckingAttributes = textCheckingAttributes {
					mas.addAttributes(textCheckingAttributes, range: result.range)
				}

				if !hasTextColor {
					mas.addAttribute(.foregroundColor, value: tintColor as Any, range: result.range)
				}
			}

			isUserInteractionEnabled = true
			super.attributedText = mas
		} else {
			isUserInteractionEnabled = false
			super.attributedText = attributedString
		}
	}

	override var text: String? {
		get {
			return super.text
		}
		set {
			guard let newValue = newValue else {
				super.text = nil
				return
			}

			let text = check(text: newValue)

			if let text = text as? NSAttributedString {
				setAttributedText(for: text)
			} else {
				super.text = text as? String
			}

			_framesetter = nil
			accessibilityElements = nil
		}
	}

	override var attributedText: NSAttributedString? {
		get {
			return super.attributedText
		}
		set {
			guard let newValue = newValue else {
				super.attributedText = nil
				return
			}

			let attributedText = check(text: newValue) as! NSAttributedString

			setAttributedText(for: attributedText)
			_framesetter = nil
			accessibilityElements = nil
		}
	}

	override func tintColorDidChange() {
		super.tintColorDidChange()

		if textCheckingResults.count > 0 {
			let mas = attributedText?.mutableCopy() as! NSMutableAttributedString
			let hasTextColor = (textCheckingAttributes?[.foregroundColor] != nil) ? true : false

			for result in textCheckingResults {
				if let textCheckingAttributes = textCheckingAttributes {
					mas.addAttributes(textCheckingAttributes, range: result.range)
				}

				if !hasTextColor {
					mas.addAttribute(.foregroundColor, value: tintColor as Any, range: result.range)
				}
			}

			super.attributedText = mas
			_framesetter = nil
		}
	}

	private var framesetter: CTFramesetter {
		guard _framesetter == nil else {
			return _framesetter!
		}

		// need to explicitly set foreground color if it's not set, otherwise comparing the attributes of the string become ambiguous and wrong cache results can be returned...
		let attributedString = attributedText ?? NSAttributedString()

		let mas = synthesize(attributedText: attributedString).mutableCopy() as! NSMutableAttributedString
		var ranges: [NSRange] = []
		var index = 0
		var foundRange = false

		mas.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: mas.length), options: []) { value, range, stop in
			foundRange = true

			if range.location > index {
				ranges.append(NSRange(location: index, length: range.location - index))
			}

			index = NSMaxRange(range)
		}

		if !foundRange {
			mas.addAttribute(.foregroundColor, value: textColor as Any, range: NSRange(location: 0, length: mas.length))
		} else {
			if index < mas.length {
				ranges.append(NSRange(location: index, length: mas.length - index))
			}

			for range in ranges {
				mas.addAttribute(.foregroundColor, value: textColor as Any, range: range)
			}
		}

		_framesetter = Self.framesetter(for: mas)
		return _framesetter!
	}

	override var intrinsicContentSize: CGSize {
		return sizeThatFits(CGSize(width: preferredMaxLayoutWidth, height: CGFloat.greatestFiniteMagnitude))
	}

	override func sizeThatFits(_ size: CGSize) -> CGSize {
		if numberOfLines > 1 {
			guard let attributedString = attributedText else {
				return super.sizeThatFits(size)
			}

			var s = CGSize.zero
			let length = attributedString.length
			let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
			var startIndex = 0

			for _ in 0..<numberOfLines where startIndex < length {
				let length = CTTypesetterSuggestLineBreak(typesetter, startIndex, Double(size.width))
				let line = CTTypesetterCreateLine(typesetter, CFRangeMake(startIndex, length))
				let lineBounds = CTLineGetBoundsWithOptions(line, [])

				s.width = max(s.width, lineBounds.width)
				s.height += lineBounds.height

				startIndex += length
			}

			s.width = ceil(s.width)
			s.height = ceil(s.height) + 1.0
			return s
		}

		let constraints: CGSize = {
			if numberOfLines == 1 {
				return CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
			} else {
				return CGSize(width: size.width, height: CGFloat.greatestFiniteMagnitude)
			}
		}()

		var s: CGSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), nil, constraints, nil)

		s.width = ceil(s.width)
		s.height = ceil(s.height) + 1.0
		return s
	}

	override func drawText(in rect: CGRect) {
		guard let ctx = UIGraphicsGetCurrentContext() else {
			print("no graphics context")
			return
		}

		guard var attributedString = attributedText else {
			return
		}

		var _mutableAttributedString: NSMutableAttributedString?
		var mutableAttributedString: NSMutableAttributedString {
			guard let mutableAttributedString = _mutableAttributedString else {
				_mutableAttributedString = attributedString.mutableCopy() as? NSMutableAttributedString
				attributedString = _mutableAttributedString!
				return _mutableAttributedString!
			}

			return mutableAttributedString
		}

		// center text like UILabel does
		let originalFrame: CGRect = {
			var frame = rect
			let textFrame = textRect(forBounds: frame, limitedToNumberOfLines: numberOfLines)

			if frame.height > textFrame.height {
				frame.origin.y -= ceil(value: (frame.height / 2.0) - (textFrame.height / 2.0), toDisplayScaleOfView: self)
			}

			return frame
		}()
		var frame = originalFrame
		var baselineAdjustmentAmount: CGFloat = 0.0
		let ics = intrinsicContentSize

		if adjustsFontSizeToFitWidth, ics.height > bounds.height {
			let size = sizeThatFits(.zero)
			var textWidth = size.width
			let availableWidth: CGFloat = {
				guard numberOfLines > 0 else {
					// approximate the number of lines
					return frame.width * (bounds.height / size.height)
				}

				return frame.width * CGFloat(numberOfLines)
			}()

			if numberOfLines > 1, lineBreakMode == .byWordWrapping {
				textWidth *= 1.1
			}

			if textWidth > availableWidth, textWidth > 0.0 {
				let scale = availableWidth / textWidth

				mutableAttributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: mutableAttributedString.length), options: [], using: { value, range, stop in
					if let font = value as? UIFont {
						let minimumFontSize = round(font.pointSize * minimumScaleFactor)
						let newFontSize = font.pointSize * scale
						// descriptor doesn't work, appears to be related to the settings of NSCTFontUIUsageAttribute
						// let newFont = UIFont(descriptor: font.fontDescriptor, size: max(newFontSize, minimumFontSize))
						let newFont = UIFont(name: font.fontName, size: max(newFontSize, minimumFontSize))!

						// DLog("\n\(UIFont(name: font.fontName, size: max(newFontSize, minimumFontSize))!.fontDescriptor)\n\(UIFont(descriptor: font.fontDescriptor, size: max(newFontSize, minimumFontSize)).fontDescriptor)")

						CFAttributedStringSetAttribute(mutableAttributedString, CFRangeMake(range.location, range.length), NSAttributedString.Key.font as CFString, newFont)

						if baselineAdjustment == .alignCenters {
							baselineAdjustmentAmount = max(baselineAdjustmentAmount, font.pointSize - newFont.pointSize)
						}
					}
				})
			} else if size.height > frame.height {
				let d = size.height - frame.height

				mutableAttributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: mutableAttributedString.length), options: [], using: { value, range, stop in
					if let font = value as? UIFont {
						let minimumFontSize = round(font.pointSize * minimumScaleFactor)
						let newFontSize = font.pointSize - d
						// let newFont = UIFont(descriptor: font.fontDescriptor, size: max(newFontSize, minimumFontSize))
						let newFont = UIFont(name: font.fontName, size: max(newFontSize, minimumFontSize))!

						CFAttributedStringSetAttribute(mutableAttributedString, CFRangeMake(range.location, range.length), NSAttributedString.Key.font as CFString, newFont)

						if baselineAdjustment == .alignCenters {
							baselineAdjustmentAmount = max(baselineAdjustmentAmount, font.pointSize - newFont.pointSize)
						}
					}
				})
			}
		}

		if isHighlighted, highlightedTextColor != nil {
			mutableAttributedString.setTextColor(highlightedTextColor!)
		}

		if let activeTextCheckingResult = activeTextCheckingResult {
			var range = activeTextCheckingResult.range

			if NSMaxRange(range) > mutableAttributedString.length {
				range.length = mutableAttributedString.length - range.location

				if range.length <= 0 {
					range = NSRange(location: NSNotFound, length: 0)
				}
			}

			if range.location != NSNotFound {
				mutableAttributedString.addAttribute(.textCheckingResultHighlightAttribute, value: true, range: range)
			}
		}

		let fs: CTFramesetter = {
			guard _mutableAttributedString != nil else {
				return framesetter
			}

			return Self.framesetter(for: synthesize(attributedText: attributedString))
		}()

		let textRange = CFRangeMake(0, attributedString.length)

		frame.origin.y -= baselineAdjustmentAmount

		ctx.saveGState()
		ctx.concatenate(CGAffineTransform(translationX: 0, y: frame.height).scaledBy(x: 1.0, y: -1.0))

		if shadowColor != nil {
			ctx.setShadow(offset: shadowOffset, blur: 0.0, color: shadowColor?.cgColor)
		}

		let path = CGMutablePath()

		path.addRect(frame)

		textFrame = CTFramesetterCreateFrame(fs, textRange, path, nil)

		let lines = CTFrameGetLines(textFrame!) as! [CTLine]
		let truncateLastLine: Bool = (lineBreakMode == .byTruncatingHead || lineBreakMode == .byTruncatingMiddle || lineBreakMode == .byTruncatingTail)
		var lineCount = lines.count

		if lineCount == 0 {
			CTFrameDraw(textFrame!, ctx)
		} else {
			if numberOfLines > 0, numberOfLines < lineCount {
				lineCount = numberOfLines
			}

			var lineOrigins = [CGPoint](repeating: CGPoint.zero, count: lineCount)

			CTFrameGetLineOrigins(textFrame!, CFRangeMake(0, lineCount), &lineOrigins)

			for lineIndex in 0..<lineCount {
				let line = lines[lineIndex]

				ctx.textPosition = CGPoint(x: lineOrigins[lineIndex].x, y: lineOrigins[lineIndex].y + frame.origin.y)

				if numberOfLines != 1, lineIndex == (numberOfLines - 1), truncateLastLine {
					let lastLineRange = CTLineGetStringRange(line)

					if !(lastLineRange.length == 0 && lastLineRange.location == 0), lastLineRange.location + lastLineRange.length < textRange.location + textRange.length {
						let truncationAttributePosition = lastLineRange.location + (lastLineRange.length - 1)
						let tokenAttributes = attributedString.attributes(at: truncationAttributePosition, effectiveRange: nil)
						let tokenString = NSAttributedString(string: "…", attributes: tokenAttributes)
						let truncationToken = CTLineCreateWithAttributedString(tokenString)
						// append … because if string isn't long enough it won't be added
						let truncationString = attributedString.attributedSubstring(from: NSRange(location: lastLineRange.location, length: lastLineRange.length)).mutableCopy() as! NSMutableAttributedString

						if lastLineRange.length > 0 {
							let lastCharacter = truncationString.string.unicodeScalars.last!

							if CharacterSet.newlines.contains(lastCharacter) {
								truncationString.deleteCharacters(in: NSRange(location: lastLineRange.length - 1, length: 1))
							}
						}

						truncationString.append(tokenString)

						let truncationLine = CTLineCreateWithAttributedString(truncationString)
						// truncate the line in case it is too long.
						var truncatedLine = CTLineCreateTruncatedLine(truncationLine, Double(frame.width), .end, truncationToken)

						if truncatedLine == nil {
							// if the line is not as wide as the truncationToken, truncatedLine is NULL
							truncatedLine = truncationToken
						}

						CTLineDraw(truncatedLine!, ctx)
						continue
					}
				}

				CTLineDraw(line, ctx)
			}
		}

		ctx.restoreGState()

		if activeTextCheckingResult != nil {
			var paths: [UIBezierPath] = []
			var path: UIBezierPath?
			var lastRect = CGRect.null

			ctx.textPosition = .zero

			let bounds = originalFrame
			let textRect = CTFrameGetPath(textFrame!).boundingBox
			let lineCount = lines.count
			var lineOrigins = [CGPoint](repeating: CGPoint.zero, count: lineCount)
			var lineIndex = 0

			CTFrameGetLineOrigins(textFrame!, CFRangeMake(0, lineCount), &lineOrigins)

			for var line in lines {
				// truncation support
				if numberOfLines != 1, lineIndex == (numberOfLines - 1), truncateLastLine {
					let lastLineRange = CTLineGetStringRange(line)

					if !(lastLineRange.length == 0 && lastLineRange.location == 0), lastLineRange.location + lastLineRange.length < textRange.location + textRange.length {
						let truncationAttributePosition = lastLineRange.location + (lastLineRange.length - 1)
						let tokenAttributes = attributedString.attributes(at: truncationAttributePosition, effectiveRange: nil)
						let tokenString = NSAttributedString(string: "…", attributes: tokenAttributes)
						let truncationToken = CTLineCreateWithAttributedString(tokenString)
						// append … because if string isn't long enough it won't be added
						let truncationString = attributedString.attributedSubstring(from: NSRange(location: lastLineRange.location, length: lastLineRange.length)).mutableCopy() as! NSMutableAttributedString

						if lastLineRange.length > 0 {
							let lastCharacter = truncationString.string.unicodeScalars.last!

							if CharacterSet.newlines.contains(lastCharacter) {
								truncationString.deleteCharacters(in: NSRange(location: lastLineRange.length - 1, length: 1))
							}
						}

						truncationString.append(tokenString)

						let truncationLine = CTLineCreateWithAttributedString(truncationString)
						// truncate the line in case it is too long.
						var truncatedLine = CTLineCreateTruncatedLine(truncationLine, Double(frame.width), .end, truncationToken)

						if truncatedLine == nil {
							// if the line is not as wide as the truncationToken, truncatedLine is NULL
							truncatedLine = truncationToken
						}

						line = truncatedLine!
					}
				}
				// end truncation support

				let runs = CTLineGetGlyphRuns(line) as! [CTRun]
				var lineBounds = CTLineGetImageBounds(line, ctx)
				var offset: CGFloat = 0.0

				lineBounds.origin.x += lineOrigins[lineIndex].x
				lineBounds.origin.y += lineOrigins[lineIndex].y
				lineIndex += 1

				for run in runs {
					var ascent: CGFloat = 0.0
					var descent: CGFloat = 0.0
					let width = CGFloat(CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, nil))
					let attributes = CTRunGetAttributes(run) as! [NSAttributedString.Key: Any]

					if let highlight = attributes[.textCheckingResultHighlightAttribute] as? Bool, highlight == true {
						var lineRect = CGRect(x: lineBounds.minX + offset, y: bounds.height - (lineBounds.minY + textRect.minY + ascent + descent), width: width, height: ascent + descent)

						lineRect.size.width += 6.0
						lineRect.size.height += 6.0

						if lastRect.intersects(lineRect) {
							path?.append(UIBezierPath(roundedRect: lineRect, cornerRadius: 2.0))
						} else {
							if path != nil {
								paths.append(path!)
							}

							path = UIBezierPath(roundedRect: lineRect, cornerRadius: 2.0)
						}

						lastRect = lineRect
					}

					offset += width
				}
			}

			if path != nil {
				paths.append(path!)
			}

			highlightPaths = paths
			highlightLayer.contents = {
				let bounds = highlightLayer.bounds

				UIGraphicsBeginImageContextWithOptions(bounds.size, false, displayScale)
				defer { UIGraphicsEndImageContext() }
				UIColor.gray.withAlphaComponent(0.5).set()

				for path in highlightPaths! {
					path.fill()
				}

				return UIGraphicsGetImageFromCurrentImageContext()?.cgImage
			}()
		} else {
			highlightPaths = nil
			highlightLayer.contents = nil
		}
	}

	// MARK: Text Checking

	private func linkAt(_ index: Int) -> NSTextCheckingResult? {
		for result in textCheckingResults {
			if NSLocationInRange(index, result.range) {
				return result
			}
		}

		return nil
	}

	private func linkAt(_ point: CGPoint) -> NSTextCheckingResult? {
		guard bounds.contains(point) else {
			return nil
		}

		guard let textFrame = textFrame else {
			return nil
		}

		let textRect = CTFrameGetPath(textFrame).boundingBoxOfPath
		var point = point
		// Convert tap coordinates (start at top left) to CT coordinates (start at bottom left)
		point.y += textRect.minY + font.descender
		point.y = bounds.height - point.y

		let lines = CTFrameGetLines(textFrame) as! [CTLine]

		guard lines.count > 0 else {
			return nil
		}

		var lineOrigins = [CGPoint](repeating: CGPoint.zero, count: lines.count)

		CTFrameGetLineOrigins(textFrame, CFRangeMake(0, 0), &lineOrigins)

		var lineIndex = 0
		var lineOrigin = CGPoint.zero

		for index in 0..<lines.count {
			lineIndex = index
			lineOrigin = lineOrigins[lineIndex]

			if lineOrigin.y < point.y {
				break
			}
		}

		let line = lines[lineIndex]
		let relativePoint = CGPoint(x: point.x - lineOrigin.x, y: point.y - lineOrigin.y)

		return linkAt(CTLineGetStringIndexForPosition(line, relativePoint))
	}

	// MARK: Events

	// TODO: may need updates similar to `touches…(_:)` if gesture bahavior has evolved over iOS versions
	@objc private func handleGesture(_ gestureRecognizer: UITapGestureRecognizer) {
		switch gestureRecognizer.state {
		case .began:
			let point = gestureRecognizer.location(in: self)

			activeTextCheckingResult = linkAt(point)
			setNeedsDisplay()
		case .ended:
			let point = gestureRecognizer.location(in: self)
			let result = linkAt(point)

			if let activeTextCheckingResult = activeTextCheckingResult, activeTextCheckingResult == result {
				touchHandler?(activeTextCheckingResult)
			}

			activeTextCheckingResult = nil
			setNeedsDisplay()
		case .cancelled:
			fallthrough
		case .failed:
			activeTextCheckingResult = nil
			setNeedsDisplay()
		default:
			break
		}
	}

	override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
		// never return self. always return the result of [super hitTest..]
		// this takes userInteraction state, enabled, alpha values etc. into account
		let view = super.hitTest(point, with: event)

		guard view === self else {
			return view
		}

		if let element = accessibilityElements?.first as? UIAccessibilityElement, element.accessibilityElementIsFocused() {
			return nil
		}

		guard linkAt(point) != nil else {
			return nil
		}

		return view
	}

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let touch = touches.first else {
			return
		}

		let point = touch.location(in: self)

		beganTextCheckingResult = linkAt(point)
		activeTextCheckingResult = beganTextCheckingResult
		setNeedsDisplay()
	}

	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard beganTextCheckingResult != nil else {
			return
		}

		guard let touch = touches.first else {
			return
		}

		let point = touch.location(in: self)
		let result = linkAt(point)

		guard result == beganTextCheckingResult else {
			if activeTextCheckingResult != result {
				activeTextCheckingResult = nil
				setNeedsDisplay()
			}

			return
		}

		if activeTextCheckingResult != result {
			activeTextCheckingResult = result
			setNeedsDisplay()
		}
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		defer {
			beganTextCheckingResult = nil
			activeTextCheckingResult = nil
		}

		guard beganTextCheckingResult != nil else {
			return
		}

		guard let touch = touches.first else {
			return
		}

		let point = touch.location(in: self)
		let result = linkAt(point)

		if let activeTextCheckingResult = activeTextCheckingResult, activeTextCheckingResult == result {
			touchHandler?(activeTextCheckingResult)
		}

		setNeedsDisplay()
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		beganTextCheckingResult = nil
		activeTextCheckingResult = nil
		setNeedsDisplay()
	}

	// MARK: UIAccessibilityElement

	override var isAccessibilityElement: Bool {
		set {
			// weird, do nothing
		}
		get {
			return false
		}
	}

	private var _accessibilityElements: [Any]?
	override var accessibilityElements: [Any]? {
		set {
			_accessibilityElements = newValue
		}
		get {
			if let accessibilityElements = _accessibilityElements {
				return accessibilityElements
			}

			var newAccessibilityElements = [UIAccessibilityElement]()

			// create default element representing entire label
			newAccessibilityElements.append({
				let e = UIAccessibilityElement(accessibilityContainer: self)

				e.accessibilityLabel = super.accessibilityLabel
				e.accessibilityHint = super.accessibilityHint
				e.accessibilityValue = super.accessibilityValue
				e.accessibilityTraits = super.accessibilityTraits
				e.accessibilityFrameInContainerSpace = bounds
				return e
			}())

			if let string = attributedText?.string, !textCheckingResults.isEmpty {
				let accessibilityFramesByTextCheckingResults = self.accessibilityFramesByTextCheckingResults()

				for result in textCheckingResults {
					guard let resultFrame = accessibilityFramesByTextCheckingResults[result] else {
						continue
					}

					newAccessibilityElements.append({
						let e = UIAccessibilityElement(accessibilityContainer: self)

						e.accessibilityLabel = {
							guard let range = Range(result.range, in: string) else {
								return nil
							}

							return String(string[range])
						}()
						e.accessibilityTraits = .link // could be `.button` also
						e.accessibilityFrameInContainerSpace = resultFrame
						return e
					}())
				}
			}

			_accessibilityElements = newAccessibilityElements
			return _accessibilityElements
		}
	}

	// `drawText(in:)` should be called before this is ever called so that `textFrame` is available
	private func accessibilityFramesByTextCheckingResults() -> [NSTextCheckingResult: CGRect] {
		guard let textFrame = textFrame else {
			return [:]
		}

		var d = [NSTextCheckingResult: CGRect]()
		let textRect = CTFrameGetPath(textFrame).boundingBox
		let lines = CTFrameGetLines(textFrame) as! [CTLine]
		let lineCount = lines.count
		var lineOrigins = [CGPoint](repeating: CGPoint.zero, count: lineCount)
		var lineIndex = 0

		CTFrameGetLineOrigins(textFrame, CFRangeMake(0, lineCount), &lineOrigins)

		for line in lines {
			defer {
				lineIndex += 1
			}

			let runs = CTLineGetGlyphRuns(line) as! [CTRun]
			var lineBounds = CTLineGetImageBounds(line, nil)
			var offset: CGFloat = 0.0

			lineBounds.origin.x += lineOrigins[lineIndex].x
			lineBounds.origin.y += lineOrigins[lineIndex].y

			for run in runs {
				var ascent: CGFloat = 0.0
				var descent: CGFloat = 0.0
				let width = CGFloat(CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, nil))

				defer {
					offset += width
				}

				let attributes = CTRunGetAttributes(run) as! [NSAttributedString.Key: Any]
				let highlight = attributes[.textCheckingResultHighlightAttribute] as? Bool ?? false

				if attributes[.link] != nil || highlight == true {
					let index = CTLineGetStringIndexForPosition(line, CGPoint(x: offset, y: lineOrigins[lineIndex].y))

					guard let textCheckingResult = textCheckingResults.first(where: { (result) -> Bool in
						return result.range.location == index
					}) else {
						continue
					}

					var rect = CGRect(x: lineBounds.minX + offset, y: bounds.height - (lineBounds.minY + textRect.minY + ascent + descent), width: width, height: ascent + descent)

					rect.origin.x -= 2.0
					rect.size.width += 4.0
					d[textCheckingResult] = rect
				}
			}
		}

		return d
	}
}

private extension NSAttributedString.Key {
	static let textCheckingResultHighlightAttribute = NSAttributedString.Key("textCheckingResultHighlightAttribute")
}

// this exists as a work-around in certain situations where `touchesBegan(_:with:)` et al don't fire as expected, likely due to other installed gesture recognizers which you may need to set up an order of operations secenario
private class LabelTapGestureRecognizer: UITapGestureRecognizer {
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
		super.touchesBegan(touches, with: event)
		state = .began
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
		super.touchesEnded(touches, with: event)
		state = .ended
	}
}
