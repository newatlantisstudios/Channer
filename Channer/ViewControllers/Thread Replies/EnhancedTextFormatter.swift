import UIKit

// MARK: - Enhanced Text Formatter
/// An enhanced text formatter that provides rich post rendering with:
/// - Tap-to-reveal spoilers
/// - Improved greentext styling
/// - Code syntax highlighting for programming boards
/// - Math/LaTeX rendering for /sci/
/// - Inline link previews for YouTube/Twitter/external links
class EnhancedTextFormatter {

    // MARK: - Singleton
    static let shared = EnhancedTextFormatter()

    // MARK: - Spoiler State Tracking
    /// Tracks which spoilers have been revealed (by post number and spoiler index)
    private var revealedSpoilers: [String: Set<Int>] = [:]
    private let spoilerQueue = DispatchQueue(label: "com.channer.spoilers", attributes: .concurrent)

    // MARK: - Initialization
    private init() {}

    // MARK: - Main Formatting Method

    /// Formats text with all enhanced rendering features
    /// - Parameters:
    ///   - text: The raw post text to format
    ///   - boardAbv: The board abbreviation (for board-specific rendering)
    ///   - postNumber: The post number (for spoiler state tracking)
    ///   - showAllSpoilers: Whether to reveal all spoilers globally
    /// - Returns: Formatted NSAttributedString with enhanced styling
    func formatText(
        _ text: String,
        boardAbv: String = "",
        postNumber: String = "",
        showAllSpoilers: Bool = false
    ) -> NSAttributedString {
        // Step 1: Basic HTML processing
        let processedText = text
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<wbr>", with: "")

        // Step 2: Tokenize and build attributed string
        let result = NSMutableAttributedString()
        let tokens = tokenize(processedText)

        var spoilerIndex = 0
        var isSpoiler = false
        var isQuote = false
        var isQuotelink = false
        var quotelinkPostNumber: String?
        var isCode = false
        var codeContent = ""

        for token in tokens {
            switch token {
            case .spoilerStart:
                isSpoiler = true
                spoilerIndex += 1

            case .spoilerEnd:
                isSpoiler = false

            case .quoteStart:
                isQuote = true

            case .quoteEnd:
                isQuote = false

            case .quotelinkStart(let postNum):
                isQuotelink = true
                quotelinkPostNumber = postNum

            case .quotelinkEnd:
                isQuotelink = false
                quotelinkPostNumber = nil

            case .codeStart:
                isCode = true
                codeContent = ""

            case .codeEnd:
                isCode = false
                // Apply syntax highlighting if on programming board
                if ProgrammingBoards.isProgrammingBoard(boardAbv) && !codeContent.isEmpty {
                    let highlighted = CodeSyntaxHighlighter.shared.highlight(codeContent, fontSize: 13)
                    result.append(highlighted)
                } else if !codeContent.isEmpty {
                    // Basic code styling for non-programming boards
                    let codeAttrs = getCodeAttributes()
                    result.append(NSAttributedString(string: codeContent, attributes: codeAttrs))
                }
                codeContent = ""

            case .lineBreak:
                if isCode {
                    codeContent += "\n"
                } else {
                    result.append(NSAttributedString(string: "\n"))
                }

            case .text(let textContent):
                if isCode {
                    codeContent += textContent
                } else {
                    let attributes: [NSAttributedString.Key: Any]
                    var processedContent = decodeHTMLEntities(textContent)

                    if isSpoiler {
                        let isRevealed = showAllSpoilers || isSpoilerRevealed(postNumber: postNumber, index: spoilerIndex)
                        attributes = getSpoilerAttributes(revealed: isRevealed, spoilerIndex: spoilerIndex)
                    } else if isQuote {
                        attributes = getGreentextAttributes()
                        // Check if this is the start of the greentext (begins with >)
                        if processedContent.hasPrefix(">") {
                            // Add greentext arrow styling
                            let arrowAttrs = getGreentextArrowAttributes()
                            let arrow = NSAttributedString(string: ">", attributes: arrowAttrs)
                            result.append(arrow)
                            processedContent = String(processedContent.dropFirst())
                        }
                    } else if isQuotelink, let postNum = quotelinkPostNumber {
                        attributes = getQuotelinkAttributes(postNumber: postNum)
                    } else {
                        // Process inline math on math boards
                        if MathBoards.isMathBoard(boardAbv) && MathRenderer.shared.containsMath(processedContent) {
                            let mathFormatted = formatWithMath(processedContent)
                            result.append(mathFormatted)
                            continue
                        }

                        // Process external links
                        let links = LinkPreviewManager.shared.extractLinks(from: processedContent)
                        if !links.isEmpty {
                            let linkedText = LinkPreviewManager.shared.applyLinkStyling(
                                to: processedContent,
                                links: links,
                                baseAttributes: getNormalAttributes()
                            )
                            result.append(linkedText)
                            continue
                        }

                        attributes = getNormalAttributes()
                    }

                    result.append(NSAttributedString(string: processedContent, attributes: attributes))
                }
            }
        }

        return result
    }

    // MARK: - Token Types

    private enum TokenType {
        case text(String)
        case spoilerStart
        case spoilerEnd
        case quoteStart
        case quoteEnd
        case quotelinkStart(String)
        case quotelinkEnd
        case codeStart
        case codeEnd
        case lineBreak
    }

    // MARK: - Tokenization

    private func tokenize(_ text: String) -> [TokenType] {
        var tokens: [TokenType] = []
        var index = text.startIndex

        // First, strip unwanted HTML tags but preserve our target tags
        let processedText = text
            .replacingOccurrences(
                of: "<(?!/?s>|span class=\"quote\">|/span>|a href=\"#p\\d+\" class=\"quotelink\">|/a>|pre class=\"prettyprint\">|/pre>|code>|/code>).+?>",
                with: "",
                options: .regularExpression
            )

        index = processedText.startIndex

        while index < processedText.endIndex {
            let remaining = processedText[index...]

            if remaining.hasPrefix("<s>") {
                tokens.append(.spoilerStart)
                index = processedText.index(index, offsetBy: 3)
            } else if remaining.hasPrefix("</s>") {
                tokens.append(.spoilerEnd)
                index = processedText.index(index, offsetBy: 4)
            } else if remaining.hasPrefix("<span class=\"quote\">") {
                tokens.append(.quoteStart)
                index = processedText.index(index, offsetBy: 20)
            } else if remaining.hasPrefix("</span>") {
                tokens.append(.quoteEnd)
                index = processedText.index(index, offsetBy: 7)
            } else if remaining.hasPrefix("<pre class=\"prettyprint\">") || remaining.hasPrefix("<code>") {
                tokens.append(.codeStart)
                let offset = remaining.hasPrefix("<pre class=\"prettyprint\">") ? 25 : 6
                index = processedText.index(index, offsetBy: offset)
            } else if remaining.hasPrefix("</pre>") || remaining.hasPrefix("</code>") {
                tokens.append(.codeEnd)
                let offset = remaining.hasPrefix("</pre>") ? 6 : 7
                index = processedText.index(index, offsetBy: offset)
            } else if remaining.hasPrefix("<a href=\"") {
                // Try to match quotelink
                let remainingString = String(remaining)
                let pattern = "^<a href=\"#p(\\d+)\" class=\"quotelink\">"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: remainingString, options: [], range: NSRange(location: 0, length: remainingString.utf16.count)),
                   let postNumberRange = Range(match.range(at: 1), in: remainingString) {
                    let postNumber = String(remainingString[postNumberRange])
                    tokens.append(.quotelinkStart(postNumber))
                    index = processedText.index(index, offsetBy: match.range.length)
                } else {
                    tokens.append(contentsOf: extractTextTokens(from: &index, in: processedText))
                }
            } else if remaining.hasPrefix("</a>") {
                tokens.append(.quotelinkEnd)
                index = processedText.index(index, offsetBy: 4)
            } else if remaining.hasPrefix("\n") {
                tokens.append(.lineBreak)
                index = processedText.index(after: index)
            } else {
                tokens.append(contentsOf: extractTextTokens(from: &index, in: processedText))
            }
        }

        return tokens
    }

    private func extractTextTokens(from index: inout String.Index, in text: String) -> [TokenType] {
        var textContent = ""

        while index < text.endIndex {
            let remaining = text[index...]

            if remaining.hasPrefix("<s>") ||
               remaining.hasPrefix("</s>") ||
               remaining.hasPrefix("<span class=\"quote\">") ||
               remaining.hasPrefix("</span>") ||
               remaining.hasPrefix("<a href=\"") ||
               remaining.hasPrefix("</a>") ||
               remaining.hasPrefix("<pre class=\"prettyprint\">") ||
               remaining.hasPrefix("</pre>") ||
               remaining.hasPrefix("<code>") ||
               remaining.hasPrefix("</code>") ||
               remaining.hasPrefix("\n") {
                break
            }

            textContent.append(text[index])
            index = text.index(after: index)
        }

        return textContent.isEmpty ? [] : [.text(textContent)]
    }

    // MARK: - HTML Entity Decoding

    private func decodeHTMLEntities(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#44;", with: ",")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    // MARK: - Text Attributes

    private func getNormalAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .foregroundColor: ThemeManager.shared.primaryTextColor,
            .font: UIFont.systemFont(ofSize: 14)
        ]
    }

    /// Enhanced greentext styling with a subtle quote bar effect
    private func getGreentextAttributes() -> [NSAttributedString.Key: Any] {
        let greentextColor = ThemeManager.shared.greentextColor

        // Create paragraph style with quote-like indentation
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 0
        paragraphStyle.headIndent = 0

        return [
            .foregroundColor: greentextColor,
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .paragraphStyle: paragraphStyle
        ]
    }

    /// Special styling for the > arrow in greentext
    private func getGreentextArrowAttributes() -> [NSAttributedString.Key: Any] {
        let greentextColor = ThemeManager.shared.greentextColor

        return [
            .foregroundColor: greentextColor,
            .font: UIFont.systemFont(ofSize: 14, weight: .bold)
        ]
    }

    /// Enhanced spoiler attributes with tap-to-reveal support
    private func getSpoilerAttributes(revealed: Bool, spoilerIndex: Int) -> [NSAttributedString.Key: Any] {
        let spoilerBgColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.15, alpha: 1.0)
                : UIColor(white: 0.1, alpha: 1.0)
        }

        let spoilerTextColor = UIColor { traitCollection in
            if revealed {
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor.white
                    : UIColor(white: 0.9, alpha: 1.0)
            } else {
                return UIColor.clear
            }
        }

        return [
            .foregroundColor: spoilerTextColor,
            .backgroundColor: spoilerBgColor,
            .font: UIFont.systemFont(ofSize: 14),
            .spoilerIndex: spoilerIndex,
            .isSpoiler: true
        ]
    }

    private func getQuotelinkAttributes(postNumber: String) -> [NSAttributedString.Key: Any] {
        let linkColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
                : UIColor.systemBlue
        }

        return [
            .foregroundColor: linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .link: URL(string: "post://\(postNumber)")!
        ]
    }

    private func getCodeAttributes() -> [NSAttributedString.Key: Any] {
        let codeBgColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.15, alpha: 1.0)
                : UIColor(white: 0.92, alpha: 1.0)
        }

        return [
            .foregroundColor: UIColor.label,
            .backgroundColor: codeBgColor,
            .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ]
    }

    // MARK: - Math Formatting

    private func formatWithMath(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let mathTokens = MathRenderer.shared.extractMathExpressions(from: text)

        if mathTokens.isEmpty {
            return NSAttributedString(string: text, attributes: getNormalAttributes())
        }

        var lastEnd = 0
        let nsString = text as NSString

        for token in mathTokens {
            // Add text before math
            if token.range.location > lastEnd {
                let beforeRange = NSRange(location: lastEnd, length: token.range.location - lastEnd)
                let beforeText = nsString.substring(with: beforeRange)
                result.append(NSAttributedString(string: beforeText, attributes: getNormalAttributes()))
            }

            // Render math
            let isDisplay = token.type == .display
            let rendered = MathRenderer.shared.render(token.content, isDisplay: isDisplay, fontSize: isDisplay ? 16 : 14)
            result.append(rendered)

            lastEnd = token.range.location + token.range.length
        }

        // Add remaining text
        if lastEnd < nsString.length {
            let remainingRange = NSRange(location: lastEnd, length: nsString.length - lastEnd)
            let remainingText = nsString.substring(with: remainingRange)
            result.append(NSAttributedString(string: remainingText, attributes: getNormalAttributes()))
        }

        return result
    }

    // MARK: - Spoiler State Management

    /// Checks if a specific spoiler has been revealed
    func isSpoilerRevealed(postNumber: String, index: Int) -> Bool {
        var result = false
        spoilerQueue.sync {
            result = revealedSpoilers[postNumber]?.contains(index) ?? false
        }
        return result
    }

    /// Toggles the reveal state of a specific spoiler
    func toggleSpoiler(postNumber: String, index: Int) {
        spoilerQueue.async(flags: .barrier) {
            if self.revealedSpoilers[postNumber] == nil {
                self.revealedSpoilers[postNumber] = []
            }

            if self.revealedSpoilers[postNumber]!.contains(index) {
                self.revealedSpoilers[postNumber]!.remove(index)
            } else {
                self.revealedSpoilers[postNumber]!.insert(index)
            }
        }
    }

    /// Reveals all spoilers for a post
    func revealAllSpoilers(postNumber: String, count: Int) {
        spoilerQueue.async(flags: .barrier) {
            self.revealedSpoilers[postNumber] = Set(1...max(1, count))
        }
    }

    /// Hides all spoilers for a post
    func hideAllSpoilers(postNumber: String) {
        spoilerQueue.async(flags: .barrier) {
            self.revealedSpoilers[postNumber] = []
        }
    }

    /// Clears all spoiler state (useful when leaving a thread)
    func clearSpoilerState() {
        spoilerQueue.async(flags: .barrier) {
            self.revealedSpoilers.removeAll()
        }
    }

    // MARK: - Spoiler Detection

    /// Counts the number of spoilers in a post
    func countSpoilers(in text: String) -> Int {
        var count = 0
        var index = text.startIndex

        while index < text.endIndex {
            if text[index...].hasPrefix("<s>") {
                count += 1
                index = text.index(index, offsetBy: 3)
            } else {
                index = text.index(after: index)
            }
        }

        return count
    }

    /// Finds spoiler ranges in attributed string
    func findSpoilerRanges(in attributedString: NSAttributedString) -> [(range: NSRange, index: Int)] {
        var results: [(NSRange, Int)] = []

        attributedString.enumerateAttribute(.isSpoiler, in: NSRange(location: 0, length: attributedString.length)) { value, range, _ in
            if let isSpoiler = value as? Bool, isSpoiler {
                if let spoilerIndex = attributedString.attribute(.spoilerIndex, at: range.location, effectiveRange: nil) as? Int {
                    results.append((range, spoilerIndex))
                }
            }
        }

        return results
    }
}

// MARK: - Custom Attributed String Keys
extension NSAttributedString.Key {
    static let spoilerIndex = NSAttributedString.Key("spoilerIndex")
    static let isSpoiler = NSAttributedString.Key("isSpoiler")
    static let linkPreviewType = NSAttributedString.Key("linkPreviewType")
}

// MARK: - Spoiler Tap Handler Protocol
protocol SpoilerTapHandler: AnyObject {
    func didTapSpoiler(at index: Int, in postNumber: String)
}

// MARK: - Quote Link Hover Delegate Protocol
protocol QuoteLinkHoverDelegate: AnyObject {
    func attributedTextForPost(number: String) -> NSAttributedString?
    func thumbnailURLForPost(number: String) -> URL?
}

// MARK: - Spoiler-Aware Text View
/// A UITextView subclass that handles tap-to-reveal for spoilers
class SpoilerTextView: UITextView {

    weak var spoilerDelegate: SpoilerTapHandler?
    var postNumber: String = ""

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupTapGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTapGesture()
    }

    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)

        // Get the character index at the tap location
        guard let textPosition = closestPosition(to: location),
              let range = tokenizer.rangeEnclosingPosition(textPosition, with: .character, inDirection: .layout(.left)),
              let nsRange = convertToNSRange(range) else {
            return
        }

        // Check if tapped on a spoiler
        if let isSpoiler = attributedText.attribute(.isSpoiler, at: nsRange.location, effectiveRange: nil) as? Bool,
           isSpoiler,
           let spoilerIndex = attributedText.attribute(.spoilerIndex, at: nsRange.location, effectiveRange: nil) as? Int {
            spoilerDelegate?.didTapSpoiler(at: spoilerIndex, in: postNumber)
        }
    }

    private func convertToNSRange(_ range: UITextRange) -> NSRange? {
        let location = offset(from: beginningOfDocument, to: range.start)
        let length = offset(from: range.start, to: range.end)
        return NSRange(location: location, length: length)
    }
}

extension SpoilerTextView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Check if tap is on a spoiler
        let location = gestureRecognizer.location(in: self)

        guard let textPosition = closestPosition(to: location),
              let range = tokenizer.rangeEnclosingPosition(textPosition, with: .character, inDirection: .layout(.left)),
              let nsRange = convertToNSRange(range),
              nsRange.location < attributedText.length else {
            return true
        }

        // If it's a spoiler, handle it
        if let isSpoiler = attributedText.attribute(.isSpoiler, at: nsRange.location, effectiveRange: nil) as? Bool,
           isSpoiler {
            return true
        }

        // Let default behavior handle links
        return true
    }
}
