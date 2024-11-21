import UIKit

class TextFormatter {
    static func formatText(_ text: String, showSpoilers: Bool = false) -> NSAttributedString {
        // Decode HTML entities and remove unnecessary tags, but keep <s>, </s>, <span class="quote">, </span>, <a href=... class="quotelink">, and </a>
        let processedText = text
            .replacingOccurrences(of: "<br>", with: "\n")
            // Remove all HTML tags except allowed ones
            .replacingOccurrences(of: "<(?!/?s>|span class=\"quote\">|/span>|a href=\"#p\\d+\" class=\"quotelink\">|/a>).+?>", with: "", options: .regularExpression)

        let tokens = tokenize(processedText)
        let attributedText = NSMutableAttributedString()
        var isSpoiler = false
        var isQuote = false
        var isQuotelink = false
        var quotelinkPostNumber: String?

        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.black,
            .font: UIFont.systemFont(ofSize: 14)
        ]

        let greenAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(red: 0.47, green: 0.6, blue: 0.13, alpha: 1.0),
            .font: UIFont.systemFont(ofSize: 14)
        ]

        let spoilerAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: showSpoilers ? UIColor.white : UIColor.clear,
            .backgroundColor: showSpoilers ? UIColor.darkGray : UIColor.black,
            .font: UIFont.systemFont(ofSize: 14)
        ]

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
            case .text(let text):
                let attributes: [NSAttributedString.Key: Any]
                if isSpoiler {
                    attributes = spoilerAttributes
                } else if isQuote {
                    attributes = greenAttributes
                } else if isQuotelink, let postNumber = quotelinkPostNumber {
                    attributes = [
                        .foregroundColor: UIColor.blue,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .font: UIFont.systemFont(ofSize: 14),
                        .link: URL(string: "post://\(postNumber)")! // Custom URL scheme
                    ]
                } else {
                    attributes = normalAttributes
                }
                attributedText.append(NSAttributedString(string: text, attributes: attributes))
            }
        }

        return attributedText
    }

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
