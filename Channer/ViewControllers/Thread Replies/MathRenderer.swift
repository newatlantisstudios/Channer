import UIKit

// MARK: - Math-Enabled Boards
/// List of boards where math rendering is enabled
struct MathBoards {
    static let boards: Set<String> = [
        "sci",    // Science & Math
        "g",      // Technology (some math discussions)
        "biz"     // Business (financial math)
    ]

    static func isMathBoard(_ boardAbv: String) -> Bool {
        return boards.contains(boardAbv.lowercased())
    }
}

// MARK: - Math Expression Types
enum MathExpressionType {
    case inline       // Single $ delimiters
    case display      // Double $$ delimiters
    case bracket      // \[ \] delimiters
    case paren        // \( \) delimiters
}

// MARK: - Math Token
struct MathToken {
    let content: String
    let type: MathExpressionType
    let range: NSRange
}

// MARK: - Math Renderer
/// Renders LaTeX-style math expressions for /sci/ and other math boards
class MathRenderer {

    // MARK: - Singleton
    static let shared = MathRenderer()

    // MARK: - Patterns
    private let displayMathPattern: NSRegularExpression? = {
        // Match $$...$$ or \[...\]
        let pattern = "(?:\\$\\$([^$]+)\\$\\$|\\\\\\[(.+?)\\\\\\])"
        return try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }()

    private let inlineMathPattern: NSRegularExpression? = {
        // Match $...$ or \(...\)
        let pattern = "(?:(?<!\\$)\\$(?!\\$)([^$]+)\\$(?!\\$)|\\\\\\((.+?)\\\\\\))"
        return try? NSRegularExpression(pattern: pattern, options: [])
    }()

    // MARK: - Symbol Mappings
    /// Greek letters
    private let greekLetters: [String: String] = [
        "\\alpha": "α", "\\beta": "β", "\\gamma": "γ", "\\delta": "δ",
        "\\epsilon": "ε", "\\zeta": "ζ", "\\eta": "η", "\\theta": "θ",
        "\\iota": "ι", "\\kappa": "κ", "\\lambda": "λ", "\\mu": "μ",
        "\\nu": "ν", "\\xi": "ξ", "\\pi": "π", "\\rho": "ρ",
        "\\sigma": "σ", "\\tau": "τ", "\\upsilon": "υ", "\\phi": "φ",
        "\\chi": "χ", "\\psi": "ψ", "\\omega": "ω",
        "\\Alpha": "Α", "\\Beta": "Β", "\\Gamma": "Γ", "\\Delta": "Δ",
        "\\Epsilon": "Ε", "\\Zeta": "Ζ", "\\Eta": "Η", "\\Theta": "Θ",
        "\\Iota": "Ι", "\\Kappa": "Κ", "\\Lambda": "Λ", "\\Mu": "Μ",
        "\\Nu": "Ν", "\\Xi": "Ξ", "\\Pi": "Π", "\\Rho": "Ρ",
        "\\Sigma": "Σ", "\\Tau": "Τ", "\\Upsilon": "Υ", "\\Phi": "Φ",
        "\\Chi": "Χ", "\\Psi": "Ψ", "\\Omega": "Ω",
        "\\varepsilon": "ε", "\\vartheta": "ϑ", "\\varpi": "ϖ",
        "\\varrho": "ϱ", "\\varsigma": "ς", "\\varphi": "φ"
    ]

    /// Mathematical operators and symbols
    private let mathSymbols: [String: String] = [
        // Operators
        "\\times": "×", "\\div": "÷", "\\pm": "±", "\\mp": "∓",
        "\\cdot": "·", "\\ast": "∗", "\\star": "⋆", "\\circ": "∘",
        "\\bullet": "•", "\\oplus": "⊕", "\\ominus": "⊖", "\\otimes": "⊗",

        // Relations
        "\\leq": "≤", "\\geq": "≥", "\\neq": "≠", "\\approx": "≈",
        "\\equiv": "≡", "\\sim": "∼", "\\simeq": "≃", "\\cong": "≅",
        "\\propto": "∝", "\\ll": "≪", "\\gg": "≫", "\\prec": "≺",
        "\\succ": "≻", "\\subset": "⊂", "\\supset": "⊃", "\\subseteq": "⊆",
        "\\supseteq": "⊇", "\\in": "∈", "\\ni": "∋", "\\notin": "∉",

        // Arrows
        "\\leftarrow": "←", "\\rightarrow": "→", "\\leftrightarrow": "↔",
        "\\Leftarrow": "⇐", "\\Rightarrow": "⇒", "\\Leftrightarrow": "⇔",
        "\\uparrow": "↑", "\\downarrow": "↓", "\\updownarrow": "↕",
        "\\mapsto": "↦", "\\to": "→", "\\gets": "←",
        "\\longrightarrow": "⟶", "\\longleftarrow": "⟵",

        // Set theory
        "\\emptyset": "∅", "\\varnothing": "∅", "\\cap": "∩", "\\cup": "∪",
        "\\setminus": "∖", "\\land": "∧", "\\lor": "∨", "\\neg": "¬",

        // Calculus
        "\\partial": "∂", "\\nabla": "∇", "\\infty": "∞", "\\aleph": "ℵ",
        "\\forall": "∀", "\\exists": "∃", "\\nexists": "∄",

        // Big operators
        "\\sum": "∑", "\\prod": "∏", "\\coprod": "∐", "\\int": "∫",
        "\\oint": "∮", "\\iint": "∬", "\\iiint": "∭",
        "\\bigcap": "⋂", "\\bigcup": "⋃", "\\bigvee": "⋁", "\\bigwedge": "⋀",

        // Delimiters
        "\\langle": "⟨", "\\rangle": "⟩", "\\lceil": "⌈", "\\rceil": "⌉",
        "\\lfloor": "⌊", "\\rfloor": "⌋", "\\lbrace": "{", "\\rbrace": "}",

        // Misc
        "\\therefore": "∴", "\\because": "∵", "\\ldots": "…", "\\cdots": "⋯",
        "\\vdots": "⋮", "\\ddots": "⋱", "\\prime": "′", "\\angle": "∠",
        "\\perp": "⊥", "\\parallel": "∥", "\\triangle": "△", "\\square": "□",
        "\\diamond": "◇", "\\hbar": "ℏ", "\\ell": "ℓ", "\\wp": "℘",
        "\\Re": "ℜ", "\\Im": "ℑ"
    ]

    /// Functions (rendered in upright text)
    private let functions: Set<String> = [
        "\\sin", "\\cos", "\\tan", "\\cot", "\\sec", "\\csc",
        "\\sinh", "\\cosh", "\\tanh", "\\coth",
        "\\arcsin", "\\arccos", "\\arctan",
        "\\log", "\\ln", "\\lg", "\\exp",
        "\\lim", "\\liminf", "\\limsup",
        "\\min", "\\max", "\\inf", "\\sup",
        "\\det", "\\dim", "\\ker", "\\hom",
        "\\arg", "\\deg", "\\gcd", "\\mod"
    ]

    // MARK: - Initialization
    private init() {}

    // MARK: - Math Detection

    /// Checks if text contains math expressions
    func containsMath(_ text: String) -> Bool {
        let range = NSRange(location: 0, length: text.utf16.count)

        if let pattern = displayMathPattern,
           pattern.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }

        if let pattern = inlineMathPattern,
           pattern.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }

        return false
    }

    /// Extracts all math expressions from text
    func extractMathExpressions(from text: String) -> [MathToken] {
        var tokens: [MathToken] = []
        let range = NSRange(location: 0, length: text.utf16.count)

        // Find display math
        if let pattern = displayMathPattern {
            let matches = pattern.matches(in: text, options: [], range: range)
            for match in matches {
                var content: String = ""

                if let contentRange = Range(match.range(at: 1), in: text) {
                    content = String(text[contentRange])
                } else if let contentRange = Range(match.range(at: 2), in: text) {
                    content = String(text[contentRange])
                }

                if !content.isEmpty {
                    tokens.append(MathToken(
                        content: content.trimmingCharacters(in: .whitespaces),
                        type: .display,
                        range: match.range
                    ))
                }
            }
        }

        // Find inline math
        if let pattern = inlineMathPattern {
            let matches = pattern.matches(in: text, options: [], range: range)
            for match in matches {
                // Skip if overlaps with display math
                let overlaps = tokens.contains { NSIntersectionRange($0.range, match.range).length > 0 }
                if overlaps { continue }

                var content: String = ""

                if let contentRange = Range(match.range(at: 1), in: text) {
                    content = String(text[contentRange])
                } else if let contentRange = Range(match.range(at: 2), in: text) {
                    content = String(text[contentRange])
                }

                if !content.isEmpty {
                    tokens.append(MathToken(
                        content: content.trimmingCharacters(in: .whitespaces),
                        type: .inline,
                        range: match.range
                    ))
                }
            }
        }

        return tokens.sorted { $0.range.location < $1.range.location }
    }

    // MARK: - Math Rendering

    /// Converts LaTeX math to styled attributed string
    func render(_ latex: String, isDisplay: Bool = false, fontSize: CGFloat = 14) -> NSAttributedString {
        var processed = latex

        // Process LaTeX commands
        processed = processSubscriptsAndSuperscripts(processed)
        processed = processFractions(processed)
        processed = processSqrt(processed)

        // Replace Greek letters
        for (command, symbol) in greekLetters {
            processed = processed.replacingOccurrences(of: command, with: symbol)
        }

        // Replace math symbols
        for (command, symbol) in mathSymbols {
            processed = processed.replacingOccurrences(of: command, with: symbol)
        }

        // Process functions
        for function in functions {
            let functionName = function.dropFirst() // Remove backslash
            processed = processed.replacingOccurrences(of: function, with: String(functionName))
        }

        // Clean up remaining LaTeX commands
        processed = cleanupRemainingCommands(processed)

        // Create attributed string
        let mathFont = UIFont(name: "Times New Roman", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        let mathItalicFont = UIFont.italicSystemFont(ofSize: fontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: isDisplay ? mathFont : mathItalicFont,
            .foregroundColor: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.85, green: 0.90, blue: 1.0, alpha: 1.0)
                    : UIColor(red: 0.1, green: 0.2, blue: 0.5, alpha: 1.0)
            }
        ]

        let result = NSMutableAttributedString(string: processed, attributes: attributes)

        // Apply styling to operators and numbers
        applyMathStyling(to: result, fontSize: fontSize)

        return result
    }

    // MARK: - LaTeX Processing

    private func processSubscriptsAndSuperscripts(_ text: String) -> String {
        var result = text

        // Superscript numbers mapping
        let superscriptMap: [Character: Character] = [
            "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
            "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
            "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
            "n": "ⁿ", "i": "ⁱ"
        ]

        // Subscript numbers mapping
        let subscriptMap: [Character: Character] = [
            "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
            "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
            "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
            "a": "ₐ", "e": "ₑ", "o": "ₒ", "x": "ₓ",
            "i": "ᵢ", "j": "ⱼ", "n": "ₙ"
        ]

        // Process ^{...} superscripts
        if let regex = try? NSRegularExpression(pattern: "\\^\\{([^}]+)\\}", options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, options: [], range: range).reversed()

            for match in matches {
                if let contentRange = Range(match.range(at: 1), in: result) {
                    let content = String(result[contentRange])
                    var superscripted = ""
                    for char in content {
                        superscripted.append(superscriptMap[char] ?? char)
                    }
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: superscripted)
                    }
                }
            }
        }

        // Process ^x (single character superscript)
        if let regex = try? NSRegularExpression(pattern: "\\^([0-9a-zA-Z])", options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, options: [], range: range).reversed()

            for match in matches {
                if let contentRange = Range(match.range(at: 1), in: result) {
                    let char = result[contentRange].first!
                    let superscripted = String(superscriptMap[char] ?? char)
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: superscripted)
                    }
                }
            }
        }

        // Process _{...} subscripts
        if let regex = try? NSRegularExpression(pattern: "_\\{([^}]+)\\}", options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, options: [], range: range).reversed()

            for match in matches {
                if let contentRange = Range(match.range(at: 1), in: result) {
                    let content = String(result[contentRange])
                    var subscripted = ""
                    for char in content {
                        subscripted.append(subscriptMap[char] ?? char)
                    }
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: subscripted)
                    }
                }
            }
        }

        // Process _x (single character subscript)
        if let regex = try? NSRegularExpression(pattern: "_([0-9a-zA-Z])", options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, options: [], range: range).reversed()

            for match in matches {
                if let contentRange = Range(match.range(at: 1), in: result) {
                    let char = result[contentRange].first!
                    let subscripted = String(subscriptMap[char] ?? char)
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: subscripted)
                    }
                }
            }
        }

        return result
    }

    private func processFractions(_ text: String) -> String {
        var result = text

        // Process \frac{num}{denom}
        if let regex = try? NSRegularExpression(pattern: "\\\\frac\\{([^}]+)\\}\\{([^}]+)\\}", options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, options: [], range: range).reversed()

            for match in matches {
                if let numRange = Range(match.range(at: 1), in: result),
                   let denomRange = Range(match.range(at: 2), in: result) {
                    let numerator = String(result[numRange])
                    let denominator = String(result[denomRange])

                    // Simple fractions use Unicode
                    if let fraction = simpleFraction(numerator: numerator, denominator: denominator) {
                        if let fullRange = Range(match.range, in: result) {
                            result.replaceSubrange(fullRange, with: fraction)
                        }
                    } else {
                        // Complex fractions use parentheses notation
                        let formatted = "(\(numerator))/(\(denominator))"
                        if let fullRange = Range(match.range, in: result) {
                            result.replaceSubrange(fullRange, with: formatted)
                        }
                    }
                }
            }
        }

        return result
    }

    private func simpleFraction(numerator: String, denominator: String) -> String? {
        // Common Unicode fractions
        let fractions: [String: String] = [
            "1/2": "½", "1/3": "⅓", "2/3": "⅔", "1/4": "¼", "3/4": "¾",
            "1/5": "⅕", "2/5": "⅖", "3/5": "⅗", "4/5": "⅘",
            "1/6": "⅙", "5/6": "⅚", "1/7": "⅐", "1/8": "⅛",
            "3/8": "⅜", "5/8": "⅝", "7/8": "⅞", "1/9": "⅑", "1/10": "⅒"
        ]

        let key = "\(numerator)/\(denominator)"
        return fractions[key]
    }

    private func processSqrt(_ text: String) -> String {
        var result = text

        // Process \sqrt{...}
        if let regex = try? NSRegularExpression(pattern: "\\\\sqrt\\{([^}]+)\\}", options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, options: [], range: range).reversed()

            for match in matches {
                if let contentRange = Range(match.range(at: 1), in: result) {
                    let content = String(result[contentRange])
                    let formatted = "√(\(content))"
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: formatted)
                    }
                }
            }
        }

        // Process \sqrt[n]{...}
        if let regex = try? NSRegularExpression(pattern: "\\\\sqrt\\[([^\\]]+)\\]\\{([^}]+)\\}", options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, options: [], range: range).reversed()

            for match in matches {
                if let nRange = Range(match.range(at: 1), in: result),
                   let contentRange = Range(match.range(at: 2), in: result) {
                    let n = String(result[nRange])
                    let content = String(result[contentRange])
                    let formatted = "ⁿ√(\(content))" // n-th root notation
                        .replacingOccurrences(of: "n", with: n)
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: formatted)
                    }
                }
            }
        }

        return result
    }

    private func cleanupRemainingCommands(_ text: String) -> String {
        var result = text

        // Remove \text{...} but keep content
        if let regex = try? NSRegularExpression(pattern: "\\\\text\\{([^}]+)\\}", options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: "$1"
            )
        }

        // Remove \mathrm{...} but keep content
        if let regex = try? NSRegularExpression(pattern: "\\\\mathrm\\{([^}]+)\\}", options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: "$1"
            )
        }

        // Remove spacing commands
        result = result.replacingOccurrences(of: "\\,", with: " ")
        result = result.replacingOccurrences(of: "\\;", with: " ")
        result = result.replacingOccurrences(of: "\\:", with: " ")
        result = result.replacingOccurrences(of: "\\!", with: "")
        result = result.replacingOccurrences(of: "\\ ", with: " ")
        result = result.replacingOccurrences(of: "\\quad", with: "  ")
        result = result.replacingOccurrences(of: "\\qquad", with: "    ")

        // Clean up remaining backslashes before unknown commands
        if let regex = try? NSRegularExpression(pattern: "\\\\([a-zA-Z]+)", options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: "$1"
            )
        }

        // Clean up extra braces
        result = result.replacingOccurrences(of: "{", with: "")
        result = result.replacingOccurrences(of: "}", with: "")

        return result
    }

    private func applyMathStyling(to attributedString: NSMutableAttributedString, fontSize: CGFloat) {
        let text = attributedString.string
        let fullRange = NSRange(location: 0, length: text.utf16.count)

        // Style numbers
        if let numberRegex = try? NSRegularExpression(pattern: "[0-9]+\\.?[0-9]*", options: []) {
            let matches = numberRegex.matches(in: text, options: [], range: fullRange)
            for match in matches {
                attributedString.addAttribute(
                    .foregroundColor,
                    value: UIColor { traitCollection in
                        traitCollection.userInterfaceStyle == .dark
                            ? UIColor(red: 0.95, green: 0.75, blue: 0.55, alpha: 1.0)
                            : UIColor(red: 0.60, green: 0.35, blue: 0.15, alpha: 1.0)
                    },
                    range: match.range
                )
            }
        }

        // Style operators
        let operators = "+-×÷=≠<>≤≥±∓·∗⊕⊖⊗→←↔⇒⇐⇔∈∉⊂⊃∩∪"
        for (index, char) in text.enumerated() {
            if operators.contains(char) {
                attributedString.addAttribute(
                    .foregroundColor,
                    value: UIColor { traitCollection in
                        traitCollection.userInterfaceStyle == .dark
                            ? UIColor(red: 0.70, green: 0.80, blue: 0.95, alpha: 1.0)
                            : UIColor(red: 0.20, green: 0.40, blue: 0.70, alpha: 1.0)
                    },
                    range: NSRange(location: index, length: 1)
                )
            }
        }
    }

    // MARK: - Math View Creation

    /// Creates a view for displaying a math expression
    func createMathView(latex: String, isDisplay: Bool, width: CGFloat) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        if isDisplay {
            // Display math - centered, larger
            container.backgroundColor = UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(white: 0.15, alpha: 1.0)
                    : UIColor(red: 0.97, green: 0.97, blue: 1.0, alpha: 1.0)
            }
            container.layer.cornerRadius = 8
            container.layer.borderWidth = 1
            container.layer.borderColor = UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(white: 0.3, alpha: 1.0).cgColor
                    : UIColor(red: 0.8, green: 0.8, blue: 0.9, alpha: 1.0).cgColor
            }

            let label = UILabel()
            label.attributedText = render(latex, isDisplay: true, fontSize: 18)
            label.textAlignment = .center
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(label)

            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
            ])
        } else {
            // Inline math - flows with text
            let label = UILabel()
            label.attributedText = render(latex, isDisplay: false, fontSize: 14)
            label.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(label)

            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: container.topAnchor),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }

        return container
    }
}

// MARK: - Attributed String Keys for Math
extension NSAttributedString.Key {
    static let mathExpression = NSAttributedString.Key("mathExpression")
    static let mathDisplayMode = NSAttributedString.Key("mathDisplayMode")
}
