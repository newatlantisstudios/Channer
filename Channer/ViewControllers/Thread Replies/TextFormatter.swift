import UIKit
import Foundation

struct QuoteReference: Equatable {
    let boardAbv: String?
    let threadNumber: String?
    let postNumber: String
}

struct QuoteFormattingContext {
    let boardAbv: String
    let threadNumber: String
    let opPostNumber: String?
    let availablePostNumbers: Set<String>
    let userPostNumbers: Set<String>
    let filteredPostNumbers: Set<String>
    let includeHashNavigation: Bool

    func isSameThread(_ reference: QuoteReference) -> Bool {
        if let board = reference.boardAbv, board != boardAbv { return false }
        if let thread = reference.threadNumber, !thread.isEmpty, thread != threadNumber { return false }
        return true
    }

    func isCrossThread(_ reference: QuoteReference) -> Bool {
        if let board = reference.boardAbv, board != boardAbv { return true }
        if let thread = reference.threadNumber, !thread.isEmpty, thread != threadNumber { return true }
        return false
    }

    func annotations(for reference: QuoteReference) -> String {
        var markers: [String] = []
        let sameThread = isSameThread(reference)

        if sameThread && userPostNumbers.contains(reference.postNumber) {
            markers.append("(You)")
        }
        if sameThread && reference.postNumber == opPostNumber {
            markers.append("(OP)")
        }
        if isCrossThread(reference) {
            markers.append("(Cross-thread)")
        }
        if sameThread && !availablePostNumbers.isEmpty && !availablePostNumbers.contains(reference.postNumber) {
            markers.append("(Dead)")
        }

        return markers.isEmpty ? "" : " " + markers.joined(separator: " ")
    }

    func quoteURL(for reference: QuoteReference) -> URL? {
        if isSameThread(reference) {
            return URL(string: "post://\(reference.postNumber)")
        }

        guard let board = reference.boardAbv else { return nil }
        if let thread = reference.threadNumber, !thread.isEmpty {
            return URL(string: "https://boards.4chan.org/\(board)/thread/\(thread)#p\(reference.postNumber)")
        }
        return URL(string: "https://archived.moe/\(board)/search/text/%3E%3E\(reference.postNumber)/")
    }

    func hashURL(for reference: QuoteReference) -> URL? {
        guard includeHashNavigation, isSameThread(reference) else { return nil }
        return URL(string: "postjump://\(reference.postNumber)")
    }
}

// MARK: - TextFormatter Class
/// A utility class for formatting text with special styling like spoilers and quotes.
/// Now with enhanced features including:
/// - Improved greentext styling with theme support
/// - Tap-to-reveal spoilers
/// - Code syntax highlighting for programming boards
/// - Math/LaTeX rendering for /sci/
/// - Inline link previews for YouTube/Twitter/external links
class TextFormatter {

    // MARK: - Board Context
    /// Current board abbreviation for board-specific rendering
    static var currentBoard: String = ""

    // MARK: - Formatting Function
    /// Formats the given text into an `NSAttributedString` with styling for spoilers, quotes, and quote links.
    /// - Parameters:
    ///   - text: The raw text to format.
    ///   - showSpoilers: A Boolean value indicating whether to reveal spoilers.
    ///   - postNumber: Optional post number for spoiler state tracking.
    /// - Returns: An `NSAttributedString` with the formatted text.
    static func formatText(
        _ text: String,
        showSpoilers: Bool = false,
        postNumber: String = "",
        quoteContext: QuoteFormattingContext? = nil
    ) -> NSAttributedString {
        // Use enhanced formatter for boards that benefit from it
        if shouldUseEnhancedFormatting() {
            return EnhancedTextFormatter.shared.formatText(
                text,
                boardAbv: currentBoard,
                postNumber: postNumber,
                showAllSpoilers: showSpoilers,
                quoteContext: quoteContext
            )
        }

        // Decode HTML entities and remove unnecessary tags, but keep <s>, </s>, <span class="quote">, </span>, <a href=... class="quotelink">, and </a>
        let processedText = text
            .replacingOccurrences(of: "<br>", with: "\n")
            // Remove all HTML tags except allowed ones
            .replacingOccurrences(of: "<(?!/?s>|span class=\"quote\">|span class=\"deadlink\">|/span>|a href=\"[^\"]+\" class=\"quotelink\">|/a>).+?>", with: "", options: .regularExpression)

        // Tokenize the processed text
        let tokens = tokenize(processedText)
        let attributedText = NSMutableAttributedString()
        var isSpoiler = false
        var isQuote = false
        var isQuotelink = false
        var isDeadlink = false
        var quotelinkReference: QuoteReference?

        // Define text attributes using ThemeManager for consistent theming
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: ThemeManager.shared.primaryTextColor,
            .font: UIFont.systemFont(ofSize: 14)
        ]

        // Enhanced greentext with theme support
        let greenAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: ThemeManager.shared.greentextColor,
            .font: UIFont.systemFont(ofSize: 14),
            .isGreentext: true
        ]

        // Enhanced spoiler attributes
        let spoilerBgColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.15, alpha: 1.0)
                : UIColor(white: 0.1, alpha: 1.0)
        }

        let spoilerTextColor = UIColor { traitCollection in
            if showSpoilers {
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor.white
                    : UIColor(white: 0.9, alpha: 1.0)
            } else {
                return UIColor.clear
            }
        }

        let spoilerAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: spoilerTextColor,
            .backgroundColor: spoilerBgColor,
            .font: UIFont.systemFont(ofSize: 14)
        ]

        // Enhanced quotelink with better visibility
        let quotelinkColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
                : UIColor.systemBlue
        }

        // Process tokens and build the attributed string
        for token in tokens {
            switch token {
            case .spoilerStart:
                isSpoiler = true
            case .spoilerEnd:
                isSpoiler = false
            case .quoteStart:
                isQuote = true
            case .quoteEnd:
                isQuote = false
            case .quotelinkStart(let reference):
                isQuotelink = true
                quotelinkReference = reference
            case .quotelinkEnd:
                isQuotelink = false
                quotelinkReference = nil
            case .deadlinkStart:
                isDeadlink = true
            case .deadlinkEnd:
                isDeadlink = false
            case .lineBreak:
                attributedText.append(NSAttributedString(string: "\n"))
            case .text(let textContent):
                var attributes: [NSAttributedString.Key: Any]
                var processedContent = decodeHTMLEntities(textContent)

                if isSpoiler {
                    attributes = spoilerAttributes
                } else if isQuote {
                    attributes = greenAttributes
                    // Bold the > character for better visual distinction
                    if processedContent.hasPrefix(">") {
                        let arrowAttrs: [NSAttributedString.Key: Any] = [
                            .foregroundColor: ThemeManager.shared.greentextColor,
                            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                            .isGreentext: true
                        ]
                        attributedText.append(NSAttributedString(string: ">", attributes: arrowAttrs))
                        processedContent = String(processedContent.dropFirst())
                    }
                } else if isQuotelink, let reference = quotelinkReference {
                    attributes = [
                        .foregroundColor: quotelinkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                        .link: quoteContext?.quoteURL(for: reference) ?? URL(string: "post://\(reference.postNumber)")!
                    ]
                    appendQuoteLink(displayText: processedContent, reference: reference, context: quoteContext, attributes: attributes, to: attributedText)
                    continue
                } else if isDeadlink, let reference = reference(fromQuoteText: processedContent) {
                    attributes = [
                        .foregroundColor: quotelinkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                        .link: quoteContext?.quoteURL(for: reference) ?? URL(string: "post://\(reference.postNumber)")!
                    ]
                    appendQuoteLink(displayText: processedContent, reference: reference, context: quoteContext, attributes: attributes, to: attributedText)
                    continue
                } else {
                    // Check for external links in regular text
                    let links = LinkPreviewManager.shared.extractLinks(from: processedContent)
                    if !links.isEmpty {
                        let linkedText = LinkPreviewManager.shared.applyLinkStyling(
                            to: processedContent,
                            links: links,
                            baseAttributes: normalAttributes
                        )
                        attributedText.append(linkedText)
                        continue
                    }
                    attributes = normalAttributes
                }
                appendTextWithQuoteLinks(processedContent, attributes: attributes, context: quoteContext, to: attributedText)
            }
        }

        return attributedText
    }

    /// Determines if enhanced formatting should be used based on current board
    private static func shouldUseEnhancedFormatting() -> Bool {
        return ProgrammingBoards.isProgrammingBoard(currentBoard) ||
               MathBoards.isMathBoard(currentBoard)
    }

    /// Decodes HTML entities using the centralized String extension
    private static func decodeHTMLEntities(_ text: String) -> String {
        return text.decodingHTMLEntities()
    }

    // MARK: - Token Types
    /// An enumeration of possible token types for text parsing.
    private enum TokenType: Equatable {
        case text(String)
        case spoilerStart
        case spoilerEnd
        case quoteStart
        case quoteEnd
        case lineBreak
        case quotelinkStart(QuoteReference)
        case quotelinkEnd
        case deadlinkStart
        case deadlinkEnd
    }

    // MARK: - Tokenization Methods
    /// Tokenizes the given text into an array of `TokenType`.
    /// - Parameter text: The text to tokenize.
    /// - Returns: An array of `TokenType` representing the tokenized text.
    private static func tokenize(_ text: String) -> [TokenType] {
        var tokens: [TokenType] = []
        var index = text.startIndex
        var openSpan: TokenType?

        while index < text.endIndex {
            if text[index...].hasPrefix("<s>") {
                tokens.append(.spoilerStart)
                index = text.index(index, offsetBy: 3)
            } else if text[index...].hasPrefix("</s>") {
                tokens.append(.spoilerEnd)
                index = text.index(index, offsetBy: 4)
            } else if text[index...].hasPrefix("<span class=\"quote\">") {
                tokens.append(.quoteStart)
                openSpan = .quoteStart
                index = text.index(index, offsetBy: 20)
            } else if text[index...].hasPrefix("<span class=\"deadlink\">") {
                tokens.append(.deadlinkStart)
                openSpan = .deadlinkStart
                index = text.index(index, offsetBy: 23)
            } else if text[index...].hasPrefix("</span>") {
                if openSpan == .deadlinkStart {
                    tokens.append(.deadlinkEnd)
                } else {
                    tokens.append(.quoteEnd)
                }
                openSpan = nil
                index = text.index(index, offsetBy: 7)
            } else if text[index...].hasPrefix("<a href=\"") {
                // Try to match same-thread or cross-thread quote links.
                let remainingText = String(text[index...])
                let pattern = "^<a href=\"([^\"]+)\" class=\"quotelink\">"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: remainingText, options: [], range: NSRange(location: 0, length: remainingText.utf16.count)),
                   let hrefRange = Range(match.range(at: 1), in: remainingText) {
                    let href = String(remainingText[hrefRange])
                    tokens.append(.quotelinkStart(reference(fromHref: href)))
                    index = text.index(index, offsetBy: match.range.length)
                } else {
                    // Not a quotelink, process as normal text
                    tokens.append(contentsOf: extractTextTokens(from: &index, in: text))
                }
            } else if text[index...].hasPrefix("</a>") {
                tokens.append(.quotelinkEnd)
                index = text.index(index, offsetBy: 4)
            } else if text[index...].hasPrefix("\n") {
                tokens.append(.lineBreak)
                index = text.index(after: index)
            } else {
                // Collect text until the next tag or line break
                tokens.append(contentsOf: extractTextTokens(from: &index, in: text))
            }
        }

        return tokens
    }

    /// Extracts text tokens from the given index in the text.
    /// - Parameters:
    ///   - index: The current index in the text (will be updated).
    ///   - text: The full text.
    /// - Returns: An array of `TokenType` representing the extracted text tokens.
    private static func extractTextTokens(from index: inout String.Index, in text: String) -> [TokenType] {
        var textContent = ""
        while index < text.endIndex,
              !text[index...].hasPrefix("<s>"),
              !text[index...].hasPrefix("</s>"),
              !text[index...].hasPrefix("<span class=\"quote\">"),
              !text[index...].hasPrefix("<span class=\"deadlink\">"),
              !text[index...].hasPrefix("</span>"),
              !text[index...].hasPrefix("<a href=\""),
              !text[index...].hasPrefix("</a>"),
              !text[index...].hasPrefix("\n") {
            textContent.append(text[index])
            index = text.index(after: index)
        }
        return [.text(textContent.decodingHTMLEntities())]
    }

    static func appendBacklinks(
        to text: NSAttributedString,
        replyNumbers: [String],
        quoteContext: QuoteFormattingContext?
    ) -> NSAttributedString {
        guard !replyNumbers.isEmpty else { return text }

        let result = NSMutableAttributedString(attributedString: text)
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: ThemeManager.shared.secondaryTextColor,
            .font: UIFont.systemFont(ofSize: 13, weight: .medium)
        ]
        let linkAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ]

        result.append(NSAttributedString(string: "\nReplies: ", attributes: labelAttributes))
        for (index, replyNumber) in replyNumbers.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: " ", attributes: labelAttributes))
            }
            let reference = QuoteReference(boardAbv: nil, threadNumber: nil, postNumber: replyNumber)
            appendQuoteLink(
                displayText: ">>\(replyNumber)",
                reference: reference,
                context: quoteContext,
                attributes: linkAttributes,
                to: result
            )
        }

        return result
    }

    private static func appendTextWithQuoteLinks(
        _ text: String,
        attributes: [NSAttributedString.Key: Any],
        context: QuoteFormattingContext?,
        to result: NSMutableAttributedString
    ) {
        let pattern = #">>>/[A-Za-z0-9]+/thread/\d+(?:#p\d+)?|>>>/[A-Za-z0-9]+/\d+|>>\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            result.append(NSAttributedString(string: text, attributes: attributes))
            return
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var cursor = 0

        for match in regex.matches(in: text, range: fullRange) {
            if match.range.location > cursor {
                let range = NSRange(location: cursor, length: match.range.location - cursor)
                result.append(NSAttributedString(string: nsText.substring(with: range), attributes: attributes))
            }

            let quoteText = nsText.substring(with: match.range)
            if let reference = reference(fromQuoteText: quoteText) {
                var linkAttributes = attributes
                linkAttributes[.foregroundColor] = UIColor.systemBlue
                linkAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                linkAttributes[.link] = context?.quoteURL(for: reference) ?? URL(string: "post://\(reference.postNumber)")
                appendQuoteLink(
                    displayText: quoteText,
                    reference: reference,
                    context: context,
                    attributes: linkAttributes,
                    to: result
                )
            } else {
                result.append(NSAttributedString(string: quoteText, attributes: attributes))
            }

            cursor = match.range.location + match.range.length
        }

        if cursor < nsText.length {
            result.append(NSAttributedString(string: nsText.substring(from: cursor), attributes: attributes))
        }
    }

    private static func appendQuoteLink(
        displayText: String,
        reference: QuoteReference,
        context: QuoteFormattingContext?,
        attributes: [NSAttributedString.Key: Any],
        to result: NSMutableAttributedString
    ) {
        result.append(NSAttributedString(
            string: displayText + (context?.annotations(for: reference) ?? ""),
            attributes: attributes
        ))

        guard let hashURL = context?.hashURL(for: reference) else { return }
        let hashAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemTeal,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: attributes[.font] ?? UIFont.systemFont(ofSize: 14),
            .link: hashURL
        ]
        result.append(NSAttributedString(string: " #", attributes: hashAttributes))
    }

    private static func reference(fromHref href: String) -> QuoteReference {
        if let post = href.firstMatch(#"#p?(\d+)$"#, group: 1) {
            return QuoteReference(boardAbv: nil, threadNumber: nil, postNumber: post)
        }

        if let groups = href.firstMatchGroups(#"/([A-Za-z0-9]+)/thread/(\d+)(?:#p(\d+))?"#) {
            let post = groups[safe: 2]?.isEmpty == false ? groups[2] : groups[1]
            return QuoteReference(boardAbv: groups[0], threadNumber: groups[1], postNumber: post)
        }

        if let post = href.firstMatch(#"(\d+)$"#, group: 1) {
            return QuoteReference(boardAbv: nil, threadNumber: nil, postNumber: post)
        }

        return QuoteReference(boardAbv: nil, threadNumber: nil, postNumber: "")
    }

    private static func reference(fromQuoteText text: String) -> QuoteReference? {
        if let post = text.firstMatch(#"^>>(\d+)$"#, group: 1) {
            return QuoteReference(boardAbv: nil, threadNumber: nil, postNumber: post)
        }

        if let groups = text.firstMatchGroups(#"^>>>/([A-Za-z0-9]+)/thread/(\d+)(?:#p(\d+))?$"#) {
            let post = groups[safe: 2]?.isEmpty == false ? groups[2] : groups[1]
            return QuoteReference(boardAbv: groups[0], threadNumber: groups[1], postNumber: post)
        }

        if let groups = text.firstMatchGroups(#"^>>>/([A-Za-z0-9]+)/(\d+)$"#) {
            return QuoteReference(boardAbv: groups[0], threadNumber: nil, postNumber: groups[1])
        }

        return nil
    }
}

private extension String {
    func firstMatch(_ pattern: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, range: range),
              match.numberOfRanges > group,
              let swiftRange = Range(match.range(at: group), in: self) else { return nil }
        return String(self[swiftRange])
    }

    func firstMatchGroups(_ pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, range: range) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            guard let swiftRange = Range(match.range(at: index), in: self) else { return "" }
            return String(self[swiftRange])
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
