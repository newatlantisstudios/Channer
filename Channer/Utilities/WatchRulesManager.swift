import Foundation

// MARK: - Watch Rule Types

enum WatchRuleType: String, Codable, CaseIterable {
    case keyword = "keyword"
    case posterId = "poster_id"
    case fileHash = "file_hash"

    var displayName: String {
        switch self {
        case .keyword:
            return "Keyword"
        case .posterId:
            return "Poster ID"
        case .fileHash:
            return "File Hash"
        }
    }

    var description: String {
        switch self {
        case .keyword:
            return "Notify when posts contain matching text"
        case .posterId:
            return "Notify when posts are from a specific poster ID"
        case .fileHash:
            return "Notify when posts include a matching file hash"
        }
    }
}

// MARK: - Watch Rule Model

struct WatchRule: Codable, Identifiable, Equatable {
    let id: String
    var type: WatchRuleType
    var value: String
    var isEnabled: Bool
    var isCaseSensitive: Bool
    var createdAt: Date
    var updatedAt: Date
    var throttleMinutes: Int?

    init(
        type: WatchRuleType,
        value: String,
        isEnabled: Bool = true,
        isCaseSensitive: Bool = false,
        throttleMinutes: Int? = nil
    ) {
        self.id = UUID().uuidString
        self.type = type
        self.value = value
        self.isEnabled = isEnabled
        self.isCaseSensitive = isCaseSensitive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.throttleMinutes = throttleMinutes
    }

    var displayName: String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch type {
        case .keyword:
            return "Keyword: \(trimmed)"
        case .posterId:
            return "Poster ID: \(trimmed)"
        case .fileHash:
            return "File Hash: \(trimmed)"
        }
    }
}

struct WatchRulePost {
    let postNo: String
    let postNoInt: Int
    let comment: String
    let posterId: String?
    let fileHash: String?
}

struct WatchRuleMatch: Codable {
    let boardAbv: String
    let threadNo: String
    let postNo: String
    let previewText: String
}

private struct WatchRuleState: Codable {
    var lastSeenPostNoByThread: [String: Int]
    var pendingMatchCount: Int
    var pendingLatestMatch: WatchRuleMatch?
    var lastNotifiedAt: Date?

    init(
        lastSeenPostNoByThread: [String: Int] = [:],
        pendingMatchCount: Int = 0,
        pendingLatestMatch: WatchRuleMatch? = nil,
        lastNotifiedAt: Date? = nil
    ) {
        self.lastSeenPostNoByThread = lastSeenPostNoByThread
        self.pendingMatchCount = pendingMatchCount
        self.pendingLatestMatch = pendingLatestMatch
        self.lastNotifiedAt = lastNotifiedAt
    }
}

struct WatchRuleAlert {
    let rule: WatchRule
    let matchCount: Int
    let latestMatch: WatchRuleMatch
    let threadTitle: String?
}

// MARK: - Watch Rules Manager

final class WatchRulesManager {
    static let shared = WatchRulesManager()
    static let defaultThrottleMinutes = 15

    private let enabledKey = "channer_watch_rules_enabled"
    private let rulesKey = "channer_watch_rules"
    private let statesKey = "channer_watch_rule_states"
    private let syncQueue = DispatchQueue(label: "com.channer.watchrules.sync", attributes: .concurrent)

    private var rules: [WatchRule] = []
    private var states: [String: WatchRuleState] = [:]

    private let htmlStripRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: [])
    private let whitespaceRegex = try? NSRegularExpression(pattern: "\\s+", options: [])

    private init() {
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            UserDefaults.standard.set(true, forKey: enabledKey)
        }
        loadRules()
        loadStates()
        pruneStates()
    }

    // MARK: - Enable/Disable

    func isWatchRulesEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    func setWatchRulesEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        NotificationCenter.default.post(name: .watchRulesDidChange, object: nil)
    }

    // MARK: - Rule Management

    func getRules() -> [WatchRule] {
        var result: [WatchRule] = []
        syncQueue.sync {
            result = rules
        }
        return result
    }

    func getEnabledRules() -> [WatchRule] {
        return getRules().filter { $0.isEnabled }
    }

    func findRule(type: WatchRuleType, value: String) -> WatchRule? {
        let normalized = normalizedValue(for: type, value: value)
        return getRules().first {
            $0.type == type && normalizedValue(for: $0.type, value: $0.value) == normalized
        }
    }

    @discardableResult
    func addRule(type: WatchRuleType, value: String, isCaseSensitive: Bool = false) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let normalized = normalizedValue(for: type, value: trimmed)

        var added = false
        syncQueue.sync(flags: .barrier) {
            let exists = rules.contains {
                $0.type == type && normalizedValue(for: $0.type, value: $0.value) == normalized
            }
            guard !exists else { return }

            let rule = WatchRule(type: type, value: trimmed, isCaseSensitive: isCaseSensitive)
            rules.append(rule)
            saveRules()
            added = true
        }

        if added {
            if !isWatchRulesEnabled() {
                UserDefaults.standard.set(true, forKey: enabledKey)
            }
            NotificationCenter.default.post(name: .watchRulesDidChange, object: nil)
        }

        return added
    }

    func removeRule(id: String) {
        syncQueue.sync(flags: .barrier) {
            rules.removeAll { $0.id == id }
            states.removeValue(forKey: id)
            saveRules()
            saveStates()
        }

        NotificationCenter.default.post(name: .watchRulesDidChange, object: nil)
    }

    func toggleRuleEnabled(id: String) {
        syncQueue.sync(flags: .barrier) {
            guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
            rules[index].isEnabled.toggle()
            rules[index].updatedAt = Date()
            saveRules()
        }

        NotificationCenter.default.post(name: .watchRulesDidChange, object: nil)
    }

    func updateRuleValue(id: String, newValue: String) -> Bool {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        var updated = false
        syncQueue.sync(flags: .barrier) {
            guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
            let type = rules[index].type
            let normalized = normalizedValue(for: type, value: trimmed)
            let duplicate = rules.contains {
                $0.id != id && $0.type == type && normalizedValue(for: $0.type, value: $0.value) == normalized
            }
            guard !duplicate else { return }

            rules[index].value = trimmed
            rules[index].updatedAt = Date()
            saveRules()
            updated = true
        }

        if updated {
            NotificationCenter.default.post(name: .watchRulesDidChange, object: nil)
        }

        return updated
    }

    // MARK: - Matching

    func processThread(
        boardAbv: String,
        threadNo: String,
        threadTitle: String?,
        posts: [WatchRulePost]
    ) -> [WatchRuleAlert] {
        guard isWatchRulesEnabled() else { return [] }
        let enabledRules = getEnabledRules()
        guard !enabledRules.isEmpty else { return [] }

        let threadKey = "\(boardAbv)/\(threadNo)"
        let now = Date()
        var alerts: [WatchRuleAlert] = []
        var cachedComments: [String: String] = [:]

        syncQueue.sync(flags: .barrier) {
            for rule in enabledRules {
                var state = states[rule.id] ?? WatchRuleState()
                let lastSeen = state.lastSeenPostNoByThread[threadKey]
                let maxPostNo = posts.map { $0.postNoInt }.max() ?? 0

                if let lastSeen = lastSeen {
                    let newPosts = posts.filter { $0.postNoInt > lastSeen }

                    if !newPosts.isEmpty {
                        var newMatchCount = 0
                        var latestMatch: WatchRuleMatch? = nil

                        for post in newPosts {
                            if matches(rule: rule, post: post, cachedComments: &cachedComments) {
                                newMatchCount += 1
                                latestMatch = WatchRuleMatch(
                                    boardAbv: boardAbv,
                                    threadNo: threadNo,
                                    postNo: post.postNo,
                                    previewText: buildPreview(from: post.comment)
                                )
                            }
                        }

                        if newMatchCount > 0 {
                            state.pendingMatchCount += newMatchCount
                            if let latestMatch = latestMatch {
                                state.pendingLatestMatch = latestMatch
                            }
                        }

                        state.lastSeenPostNoByThread[threadKey] = max(lastSeen, maxPostNo)
                    } else if maxPostNo > lastSeen {
                        state.lastSeenPostNoByThread[threadKey] = maxPostNo
                    }
                } else if maxPostNo > 0 {
                    // Prime this thread so existing posts don't trigger alerts
                    state.lastSeenPostNoByThread[threadKey] = maxPostNo
                }

                if state.pendingMatchCount > 0, shouldNotify(state: state, rule: rule, now: now),
                   let latestMatch = state.pendingLatestMatch {
                    alerts.append(
                        WatchRuleAlert(
                            rule: rule,
                            matchCount: state.pendingMatchCount,
                            latestMatch: latestMatch,
                            threadTitle: threadTitle
                        )
                    )
                    state.pendingMatchCount = 0
                    state.pendingLatestMatch = nil
                    state.lastNotifiedAt = now
                }

                states[rule.id] = state
            }

            saveStates()
        }

        return alerts
    }

    // MARK: - Private Helpers

    private func normalizedValue(for type: WatchRuleType, value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch type {
        case .keyword:
            return trimmed.lowercased()
        case .posterId, .fileHash:
            return trimmed.lowercased()
        }
    }

    private func matches(
        rule: WatchRule,
        post: WatchRulePost,
        cachedComments: inout [String: String]
    ) -> Bool {
        switch rule.type {
        case .keyword:
            let comment = normalizedComment(post: post, cachedComments: &cachedComments)
            if rule.isCaseSensitive {
                return comment.contains(rule.value)
            }
            return comment.lowercased().contains(rule.value.lowercased())

        case .posterId:
            guard let posterId = post.posterId, !posterId.isEmpty else { return false }
            if rule.isCaseSensitive {
                return posterId == rule.value
            }
            return posterId.lowercased() == rule.value.lowercased()

        case .fileHash:
            guard let fileHash = post.fileHash, !fileHash.isEmpty else { return false }
            if rule.isCaseSensitive {
                return fileHash == rule.value
            }
            return fileHash.lowercased() == rule.value.lowercased()
        }
    }

    private func normalizedComment(post: WatchRulePost, cachedComments: inout [String: String]) -> String {
        if let cached = cachedComments[post.postNo] {
            return cached
        }

        let cleaned = cleanComment(post.comment)
        cachedComments[post.postNo] = cleaned
        return cleaned
    }

    private func cleanComment(_ comment: String) -> String {
        let preprocessed = comment.replacingOccurrences(of: "<br>", with: " ")
        let stripped: String
        if let regex = htmlStripRegex {
            let range = NSRange(preprocessed.startIndex..<preprocessed.endIndex, in: preprocessed)
            stripped = regex.stringByReplacingMatches(in: preprocessed, options: [], range: range, withTemplate: " ")
        } else {
            stripped = preprocessed
        }

        let decoded = stripped
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&amp;", with: "&")

        let normalized: String
        if let whitespaceRegex = whitespaceRegex {
            let range = NSRange(decoded.startIndex..<decoded.endIndex, in: decoded)
            normalized = whitespaceRegex.stringByReplacingMatches(in: decoded, options: [], range: range, withTemplate: " ")
        } else {
            normalized = decoded
        }

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildPreview(from comment: String) -> String {
        let cleaned = cleanComment(comment)
        if cleaned.isEmpty {
            return "New matching post"
        }
        let preview = String(cleaned.prefix(140))
        return cleaned.count > 140 ? preview + "..." : preview
    }

    private func shouldNotify(state: WatchRuleState, rule: WatchRule, now: Date) -> Bool {
        let minutes = rule.throttleMinutes ?? Self.defaultThrottleMinutes
        let interval = TimeInterval(minutes * 60)

        guard interval > 0 else { return true }
        guard let lastNotified = state.lastNotifiedAt else { return true }
        return now.timeIntervalSince(lastNotified) >= interval
    }

    private func pruneStates() {
        let ruleIds = Set(rules.map { $0.id })
        states = states.filter { ruleIds.contains($0.key) }
        saveStates()
    }

    private func loadRules() {
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([WatchRule].self, from: data) {
            rules = decoded
        } else {
            rules = []
        }
    }

    private func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: rulesKey)
        }
    }

    private func loadStates() {
        if let data = UserDefaults.standard.data(forKey: statesKey),
           let decoded = try? JSONDecoder().decode([String: WatchRuleState].self, from: data) {
            states = decoded
        } else {
            states = [:]
        }
    }

    private func saveStates() {
        if let encoded = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(encoded, forKey: statesKey)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchRulesDidChange = Notification.Name("watchRulesDidChange")
}
