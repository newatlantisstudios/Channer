import Foundation

extension String {
    /// Decodes HTML entities in the string, including named entities and numeric character references.
    ///
    /// Handles:
    /// - Named entities: `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&nbsp;`
    /// - Numeric decimal references: `&#039;`, `&#44;`, `&#8217;`, etc.
    /// - Numeric hex references: `&#x27;`, `&#x2019;`, etc.
    func decodingHTMLEntities() -> String {
        // First handle numeric character references (&#NNN; and &#xHHH;)
        // This must come before named entity replacement to avoid double-decoding
        var result = self

        // Replace numeric decimal references: &#NNN;
        if let decimalRegex = try? NSRegularExpression(pattern: "&#(\\d+);", options: []) {
            let nsRange = NSRange(result.startIndex..<result.endIndex, in: result)
            let matches = decimalRegex.matches(in: result, options: [], range: nsRange)
            // Process matches in reverse order to preserve string indices
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: result),
                      let codeRange = Range(match.range(at: 1), in: result),
                      let codePoint = UInt32(result[codeRange]),
                      let scalar = Unicode.Scalar(codePoint) else { continue }
                result.replaceSubrange(fullRange, with: String(Character(scalar)))
            }
        }

        // Replace numeric hex references: &#xHHH;
        if let hexRegex = try? NSRegularExpression(pattern: "&#x([0-9a-fA-F]+);", options: []) {
            let nsRange = NSRange(result.startIndex..<result.endIndex, in: result)
            let matches = hexRegex.matches(in: result, options: [], range: nsRange)
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: result),
                      let codeRange = Range(match.range(at: 1), in: result),
                      let codePoint = UInt32(result[codeRange], radix: 16),
                      let scalar = Unicode.Scalar(codePoint) else { continue }
                result.replaceSubrange(fullRange, with: String(Character(scalar)))
            }
        }

        // Replace named entities (order matters: &amp; must be last to avoid double-decoding)
        result = result
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")

        return result
    }
}
