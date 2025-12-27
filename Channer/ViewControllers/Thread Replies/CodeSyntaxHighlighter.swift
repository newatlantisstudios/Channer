import UIKit

// MARK: - Programming Boards
/// List of programming-related boards that should have syntax highlighting enabled
struct ProgrammingBoards {
    static let boards: Set<String> = [
        "g",      // Technology
        "sci",    // Science & Math
        "diy",    // Do It Yourself
        "wsr",    // Worksafe Requests
        "po"      // Papercraft & Origami (sometimes has coding)
    ]

    static func isProgrammingBoard(_ boardAbv: String) -> Bool {
        return boards.contains(boardAbv.lowercased())
    }
}

// MARK: - Token Type
/// Represents different syntax elements that can be highlighted
enum SyntaxTokenType {
    case keyword
    case string
    case number
    case comment
    case function
    case type
    case preprocessor
    case operator_
    case punctuation
    case variable
    case constant
    case plain

    var color: UIColor {
        switch self {
        case .keyword:
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.78, green: 0.55, blue: 0.95, alpha: 1.0)  // Purple
                    : UIColor(red: 0.55, green: 0.24, blue: 0.68, alpha: 1.0)
            }
        case .string:
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.80, green: 0.58, blue: 0.46, alpha: 1.0)  // Orange-ish
                    : UIColor(red: 0.76, green: 0.26, blue: 0.16, alpha: 1.0)
            }
        case .number:
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.85, green: 0.73, blue: 0.55, alpha: 1.0)  // Gold
                    : UIColor(red: 0.11, green: 0.44, blue: 0.72, alpha: 1.0)
            }
        case .comment:
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.42, green: 0.50, blue: 0.42, alpha: 1.0)  // Gray-green
                    : UIColor(red: 0.35, green: 0.43, blue: 0.35, alpha: 1.0)
            }
        case .function:
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.40, green: 0.75, blue: 0.95, alpha: 1.0)  // Cyan
                    : UIColor(red: 0.16, green: 0.50, blue: 0.73, alpha: 1.0)
            }
        case .type:
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.35, green: 0.78, blue: 0.60, alpha: 1.0)  // Teal
                    : UIColor(red: 0.15, green: 0.55, blue: 0.42, alpha: 1.0)
            }
        case .preprocessor:
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.95, green: 0.60, blue: 0.45, alpha: 1.0)  // Coral
                    : UIColor(red: 0.58, green: 0.30, blue: 0.18, alpha: 1.0)
            }
        case .operator_:
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
                    : UIColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1.0)
            }
        case .punctuation:
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.70, green: 0.70, blue: 0.70, alpha: 1.0)
                    : UIColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1.0)
            }
        case .variable:
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.90, green: 0.80, blue: 0.60, alpha: 1.0)  // Light gold
                    : UIColor(red: 0.50, green: 0.40, blue: 0.20, alpha: 1.0)
            }
        case .constant:
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.45, green: 0.85, blue: 0.75, alpha: 1.0)  // Aqua
                    : UIColor(red: 0.05, green: 0.50, blue: 0.50, alpha: 1.0)
            }
        case .plain:
            return UIColor.label
        }
    }
}

// MARK: - Code Syntax Highlighter
/// Provides syntax highlighting for code blocks in posts on programming boards
class CodeSyntaxHighlighter {

    // MARK: - Singleton
    static let shared = CodeSyntaxHighlighter()

    // MARK: - Patterns
    /// Pattern to detect code blocks (text wrapped in [code] tags or using backticks)
    private let codeBlockPattern: NSRegularExpression? = {
        // Match [code]...[/code] or ```...``` or `...`
        let pattern = "(?:\\[code\\](.*?)\\[/code\\]|```([\\s\\S]*?)```|`([^`]+)`)"
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    }()

    // Common programming keywords across multiple languages
    private let keywords: Set<String> = [
        // Control flow
        "if", "else", "elif", "switch", "case", "default", "for", "while", "do", "break",
        "continue", "return", "goto", "try", "catch", "throw", "throws", "finally", "except",
        "raise", "pass", "yield", "async", "await", "defer", "guard",

        // Declarations
        "var", "let", "const", "static", "final", "volatile", "mutable", "extern",
        "public", "private", "protected", "internal", "open", "fileprivate",
        "class", "struct", "enum", "interface", "trait", "protocol", "extension",
        "func", "function", "fn", "def", "sub", "method", "constructor",
        "import", "export", "module", "package", "namespace", "using", "include", "require",
        "typedef", "typealias", "type", "alias",

        // Types
        "int", "float", "double", "char", "string", "bool", "boolean", "void", "null",
        "nil", "none", "undefined", "any", "object", "array", "list", "dict", "map",
        "set", "tuple", "vector", "long", "short", "byte", "uint", "int8", "int16",
        "int32", "int64", "uint8", "uint16", "uint32", "uint64", "size_t", "auto",

        // Boolean
        "true", "false", "True", "False", "TRUE", "FALSE",

        // Object-oriented
        "new", "delete", "this", "self", "super", "init", "deinit", "override",
        "virtual", "abstract", "sealed", "readonly", "mutating", "nonmutating",
        "lazy", "weak", "unowned", "strong", "copy",

        // Other
        "in", "is", "as", "of", "with", "from", "where", "when", "match",
        "lambda", "closure", "inline", "noinline", "constexpr", "sizeof", "typeof",
        "instanceof", "implements", "extends"
    ]

    // Built-in types and classes
    private let types: Set<String> = [
        "String", "Int", "Integer", "Float", "Double", "Bool", "Boolean", "Array",
        "Dictionary", "Set", "List", "Map", "HashMap", "ArrayList", "Vector",
        "Object", "Class", "Function", "Promise", "Optional", "Result", "Error",
        "Exception", "NSObject", "UIView", "UIViewController", "Date", "URL",
        "Data", "Number", "BigInt", "Symbol", "RegExp", "Math", "JSON", "Console"
    ]

    // Common constants
    private let constants: Set<String> = [
        "NULL", "nullptr", "NaN", "Infinity", "undefined", "PI", "E",
        "MAX_VALUE", "MIN_VALUE", "MAX_INT", "MIN_INT", "EPSILON",
        "stdin", "stdout", "stderr", "argc", "argv", "errno"
    ]

    // MARK: - Initialization
    private init() {}

    // MARK: - Code Detection

    /// Checks if the text contains code blocks
    func containsCode(_ text: String) -> Bool {
        guard let pattern = codeBlockPattern else { return false }
        let range = NSRange(location: 0, length: text.utf16.count)
        return pattern.firstMatch(in: text, options: [], range: range) != nil
    }

    /// Extracts code blocks from text
    func extractCodeBlocks(from text: String) -> [(code: String, range: NSRange, isInline: Bool)] {
        guard let pattern = codeBlockPattern else { return [] }
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = pattern.matches(in: text, options: [], range: range)

        var results: [(String, NSRange, Bool)] = []

        for match in matches {
            var codeContent: String = ""
            var isInline = false

            // Check which capture group matched
            if let codeRange = Range(match.range(at: 1), in: text) {
                // [code]...[/code]
                codeContent = String(text[codeRange])
            } else if let codeRange = Range(match.range(at: 2), in: text) {
                // ```...```
                codeContent = String(text[codeRange])
            } else if let codeRange = Range(match.range(at: 3), in: text) {
                // `...` (inline)
                codeContent = String(text[codeRange])
                isInline = true
            }

            if !codeContent.isEmpty {
                results.append((codeContent.trimmingCharacters(in: .whitespacesAndNewlines), match.range, isInline))
            }
        }

        return results
    }

    // MARK: - Syntax Highlighting

    /// Applies syntax highlighting to a code string
    /// - Parameters:
    ///   - code: The code to highlight
    ///   - fontSize: Font size for the code
    /// - Returns: Attributed string with syntax highlighting
    func highlight(_ code: String, fontSize: CGFloat = 13) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Base code font
        let codeFont = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let boldCodeFont = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)

        // Process line by line
        let lines = code.components(separatedBy: "\n")

        for (lineIndex, line) in lines.enumerated() {
            let highlightedLine = highlightLine(line, codeFont: codeFont, boldFont: boldCodeFont)
            result.append(highlightedLine)

            if lineIndex < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
    }

    private func highlightLine(_ line: String, codeFont: UIFont, boldFont: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Check for comments first
        if let commentRange = findComment(in: line) {
            // Add code before comment
            if commentRange.location > 0 {
                let beforeComment = String(line.prefix(commentRange.location))
                result.append(tokenizeLine(beforeComment, codeFont: codeFont, boldFont: boldFont))
            }

            // Add comment
            let commentStart = line.index(line.startIndex, offsetBy: commentRange.location)
            let comment = String(line[commentStart...])
            let commentAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: SyntaxTokenType.comment.color,
                .font: codeFont
            ]
            result.append(NSAttributedString(string: comment, attributes: commentAttrs))
        } else {
            result.append(tokenizeLine(line, codeFont: codeFont, boldFont: boldFont))
        }

        return result
    }

    private func tokenizeLine(_ line: String, codeFont: UIFont, boldFont: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString()

        var currentIndex = line.startIndex
        let endIndex = line.endIndex

        while currentIndex < endIndex {
            let remaining = String(line[currentIndex...])

            // Check for strings
            if let stringMatch = matchString(in: remaining) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: SyntaxTokenType.string.color,
                    .font: codeFont
                ]
                result.append(NSAttributedString(string: stringMatch, attributes: attrs))
                currentIndex = line.index(currentIndex, offsetBy: stringMatch.count)
                continue
            }

            // Check for numbers
            if let numberMatch = matchNumber(in: remaining) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: SyntaxTokenType.number.color,
                    .font: codeFont
                ]
                result.append(NSAttributedString(string: numberMatch, attributes: attrs))
                currentIndex = line.index(currentIndex, offsetBy: numberMatch.count)
                continue
            }

            // Check for preprocessor directives
            if remaining.hasPrefix("#") {
                let directive = extractUntilWhitespace(from: remaining)
                let attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: SyntaxTokenType.preprocessor.color,
                    .font: boldFont
                ]
                result.append(NSAttributedString(string: directive, attributes: attrs))
                currentIndex = line.index(currentIndex, offsetBy: directive.count)
                continue
            }

            // Check for identifiers (keywords, types, etc.)
            if let identifier = matchIdentifier(in: remaining) {
                let tokenType = classifyIdentifier(identifier)
                let font = (tokenType == .keyword || tokenType == .type) ? boldFont : codeFont
                let attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: tokenType.color,
                    .font: font
                ]
                result.append(NSAttributedString(string: identifier, attributes: attrs))
                currentIndex = line.index(currentIndex, offsetBy: identifier.count)
                continue
            }

            // Check for operators
            if let operatorMatch = matchOperator(in: remaining) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: SyntaxTokenType.operator_.color,
                    .font: codeFont
                ]
                result.append(NSAttributedString(string: operatorMatch, attributes: attrs))
                currentIndex = line.index(currentIndex, offsetBy: operatorMatch.count)
                continue
            }

            // Default: single character
            let char = String(line[currentIndex])
            let tokenType: SyntaxTokenType = "(){}[]<>,.;:".contains(char) ? .punctuation : .plain
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: tokenType.color,
                .font: codeFont
            ]
            result.append(NSAttributedString(string: char, attributes: attrs))
            currentIndex = line.index(after: currentIndex)
        }

        return result
    }

    // MARK: - Token Matching

    private func findComment(in line: String) -> NSRange? {
        // Single-line comment patterns
        let patterns = ["//", "#", "--", ";", "//"]

        for pattern in patterns {
            if let range = line.range(of: pattern) {
                // Make sure it's not inside a string
                let prefix = String(line[..<range.lowerBound])
                if !isInsideString(prefix) {
                    let location = line.distance(from: line.startIndex, to: range.lowerBound)
                    return NSRange(location: location, length: line.count - location)
                }
            }
        }
        return nil
    }

    private func isInsideString(_ text: String) -> Bool {
        var inString = false
        var stringChar: Character = "\""

        for char in text {
            if !inString && (char == "\"" || char == "'") {
                inString = true
                stringChar = char
            } else if inString && char == stringChar {
                inString = false
            }
        }

        return inString
    }

    private func matchString(in text: String) -> String? {
        guard let firstChar = text.first, firstChar == "\"" || firstChar == "'" || firstChar == "`" else {
            return nil
        }

        let delimiter = firstChar
        var result = String(delimiter)
        var escaped = false

        for char in text.dropFirst() {
            result.append(char)

            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == delimiter {
                return result
            }
        }

        // Unclosed string - return what we have
        return result
    }

    private func matchNumber(in text: String) -> String? {
        guard let firstChar = text.first else { return nil }

        // Check for hex, octal, binary
        if firstChar == "0" && text.count > 1 {
            let second = text[text.index(after: text.startIndex)]
            if second == "x" || second == "X" {
                return matchPattern(in: text, pattern: "0[xX][0-9a-fA-F]+")
            }
            if second == "b" || second == "B" {
                return matchPattern(in: text, pattern: "0[bB][01]+")
            }
            if second == "o" || second == "O" {
                return matchPattern(in: text, pattern: "0[oO][0-7]+")
            }
        }

        // Regular number (including floats)
        if firstChar.isNumber || (firstChar == "." && text.count > 1 && text[text.index(after: text.startIndex)].isNumber) {
            return matchPattern(in: text, pattern: "[0-9]*\\.?[0-9]+([eE][+-]?[0-9]+)?[fFdDlL]?")
        }

        return nil
    }

    private func matchIdentifier(in text: String) -> String? {
        guard let firstChar = text.first,
              firstChar.isLetter || firstChar == "_" || firstChar == "$" else {
            return nil
        }

        var result = ""
        for char in text {
            if char.isLetter || char.isNumber || char == "_" || char == "$" {
                result.append(char)
            } else {
                break
            }
        }

        return result.isEmpty ? nil : result
    }

    private func matchOperator(in text: String) -> String? {
        let operators = ["===", "!==", "==", "!=", "<=", ">=", "&&", "||", "<<", ">>",
                         "++", "--", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=",
                         "->", "=>", "::", "??", "?.", "...", "..", "::"]

        for op in operators {
            if text.hasPrefix(op) {
                return op
            }
        }

        if let first = text.first, "+-*/%&|^!~<>=?:".contains(first) {
            return String(first)
        }

        return nil
    }

    private func matchPattern(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "^\(pattern)", options: []) else {
            return nil
        }

        let range = NSRange(location: 0, length: text.utf16.count)
        if let match = regex.firstMatch(in: text, options: [], range: range) {
            if let swiftRange = Range(match.range, in: text) {
                return String(text[swiftRange])
            }
        }
        return nil
    }

    private func extractUntilWhitespace(from text: String) -> String {
        var result = ""
        for char in text {
            if char.isWhitespace {
                break
            }
            result.append(char)
        }
        return result
    }

    private func classifyIdentifier(_ identifier: String) -> SyntaxTokenType {
        if keywords.contains(identifier) {
            return .keyword
        }
        if types.contains(identifier) {
            return .type
        }
        if constants.contains(identifier) {
            return .constant
        }
        // Check if it looks like a type (PascalCase)
        if identifier.first?.isUppercase == true {
            return .type
        }
        // Check if followed by ( - likely a function
        return .plain
    }

    // MARK: - Code Block View Creation

    /// Creates a styled view for displaying a code block
    func createCodeBlockView(code: String, width: CGFloat, isInline: Bool = false) -> UIView {
        if isInline {
            return createInlineCodeView(code: code)
        } else {
            return createBlockCodeView(code: code, width: width)
        }
    }

    private func createInlineCodeView(code: String) -> UIView {
        let label = UILabel()
        label.attributedText = highlight(code, fontSize: 12)
        label.backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.2, alpha: 1.0)
                : UIColor(white: 0.92, alpha: 1.0)
        }
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.textAlignment = .center

        // Add padding
        let container = UIView()
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2)
        ])

        return container
    }

    private func createBlockCodeView(code: String, width: CGFloat) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.12, alpha: 1.0)
                : UIColor(white: 0.95, alpha: 1.0)
        }
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.separator.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false

        // Header with "Code" label
        let headerView = UIView()
        headerView.backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.18, alpha: 1.0)
                : UIColor(white: 0.88, alpha: 1.0)
        }
        headerView.translatesAutoresizingMaskIntoConstraints = false

        let codeLabel = UILabel()
        codeLabel.text = "Code"
        codeLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        codeLabel.textColor = .secondaryLabel
        codeLabel.translatesAutoresizingMaskIntoConstraints = false

        let copyButton = UIButton(type: .system)
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.tintColor = .secondaryLabel
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.accessibilityValue = code // Store code for copying

        headerView.addSubview(codeLabel)
        headerView.addSubview(copyButton)

        // Code text view
        let textView = UITextView()
        textView.attributedText = highlight(code, fontSize: 13)
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(headerView)
        container.addSubview(textView)

        // Calculate height based on content
        let lineCount = code.components(separatedBy: "\n").count
        let estimatedHeight = min(CGFloat(lineCount * 18) + 16, 300) // Max 300pt height

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: container.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 28),

            codeLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 10),
            codeLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            copyButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -8),
            copyButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 24),
            copyButton.heightAnchor.constraint(equalToConstant: 24),

            textView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            textView.heightAnchor.constraint(equalToConstant: estimatedHeight)
        ])

        return container
    }
}

// MARK: - Code Block Attributed String Key
extension NSAttributedString.Key {
    static let codeBlock = NSAttributedString.Key("codeBlock")
    static let inlineCode = NSAttributedString.Key("inlineCode")
}
