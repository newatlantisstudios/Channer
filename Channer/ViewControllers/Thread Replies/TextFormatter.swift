import UIKit
import Foundation

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
    static func formatText(_ text: String, showSpoilers: Bool = false, postNumber: String = "") -> NSAttributedString {
        // Use enhanced formatter for boards that benefit from it
        if shouldUseEnhancedFormatting() {
            return EnhancedTextFormatter.shared.formatText(
                text,
                boardAbv: currentBoard,
                postNumber: postNumber,
                showAllSpoilers: showSpoilers
            )
        }

        // Decode HTML entities and remove unnecessary tags, but keep <s>, </s>, <span class="quote">, </span>, <a href=... class="quotelink">, and </a>
        let processedText = text
            .replacingOccurrences(of: "<br>", with: "\n")
            // Remove all HTML tags except allowed ones
            .replacingOccurrences(of: "<(?!/?s>|span class=\"quote\">|/span>|a href=\"#p\\d+\" class=\"quotelink\">|/a>).+?>", with: "", options: .regularExpression)

        // Tokenize the processed text
        let tokens = tokenize(processedText)
        let attributedText = NSMutableAttributedString()
        var isSpoiler = false
        var isQuote = false
        var isQuotelink = false
        var quotelinkPostNumber: String?

        // Define text attributes using ThemeManager for consistent theming
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: ThemeManager.shared.primaryTextColor,
            .font: UIFont.systemFont(ofSize: 14)
        ]

        // Enhanced greentext with theme support
        let greenAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: ThemeManager.shared.greentextColor,
            .font: UIFont.systemFont(ofSize: 14)
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
            case .quotelinkStart(let postNumber):
                isQuotelink = true
                quotelinkPostNumber = postNumber
            case .quotelinkEnd:
                isQuotelink = false
                quotelinkPostNumber = nil
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
                            .font: UIFont.systemFont(ofSize: 14, weight: .bold)
                        ]
                        attributedText.append(NSAttributedString(string: ">", attributes: arrowAttrs))
                        processedContent = String(processedContent.dropFirst())
                    }
                } else if isQuotelink, let postNumber = quotelinkPostNumber {
                    attributes = [
                        .foregroundColor: quotelinkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                        .link: URL(string: "post://\(postNumber)")!
                    ]
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
                attributedText.append(NSAttributedString(string: processedContent, attributes: attributes))
            }
        }

        return attributedText
    }

    /// Determines if enhanced formatting should be used based on current board
    private static func shouldUseEnhancedFormatting() -> Bool {
        return ProgrammingBoards.isProgrammingBoard(currentBoard) ||
               MathBoards.isMathBoard(currentBoard)
    }

    /// Decodes common HTML entities
    private static func decodeHTMLEntities(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#44;", with: ",")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    // MARK: - Token Types
    /// An enumeration of possible token types for text parsing.
    private enum TokenType {
        case text(String)
        case spoilerStart
        case spoilerEnd
        case quoteStart
        case quoteEnd
        case lineBreak
        case quotelinkStart(String) // Contains the post number
        case quotelinkEnd
    }

    // MARK: - Tokenization Methods
    /// Tokenizes the given text into an array of `TokenType`.
    /// - Parameter text: The text to tokenize.
    /// - Returns: An array of `TokenType` representing the tokenized text.
    private static func tokenize(_ text: String) -> [TokenType] {
        var tokens: [TokenType] = []
        var index = text.startIndex

        while index < text.endIndex {
            if text[index...].hasPrefix("<s>") {
                tokens.append(.spoilerStart)
                index = text.index(index, offsetBy: 3)
            } else if text[index...].hasPrefix("</s>") {
                tokens.append(.spoilerEnd)
                index = text.index(index, offsetBy: 4)
            } else if text[index...].hasPrefix("<span class=\"quote\">") {
                tokens.append(.quoteStart)
                index = text.index(index, offsetBy: 20)
            } else if text[index...].hasPrefix("</span>") {
                tokens.append(.quoteEnd)
                index = text.index(index, offsetBy: 7)
            } else if text[index...].hasPrefix("<a href=\"") {
                // Try to match <a href="#p\d+" class="quotelink">
                let remainingText = String(text[index...])
                let pattern = "^<a href=\"#p(\\d+)\" class=\"quotelink\">"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: remainingText, options: [], range: NSRange(location: 0, length: remainingText.utf16.count)),
                   let postNumberRange = Range(match.range(at: 1), in: remainingText) {
                    let postNumber = String(remainingText[postNumberRange])
                    tokens.append(.quotelinkStart(postNumber))
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
              !text[index...].hasPrefix("</span>"),
              !text[index...].hasPrefix("<a href=\""),
              !text[index...].hasPrefix("</a>"),
              !text[index...].hasPrefix("\n") {
            textContent.append(text[index])
            index = text.index(after: index)
        }
        // Decode HTML entities
        let decodedText = textContent
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
        return [.text(decodedText)]
    }
}
