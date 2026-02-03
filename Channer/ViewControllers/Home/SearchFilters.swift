import Foundation

struct SearchFilters: Codable, Equatable {
    var requiresImages: Bool
    var minReplies: Int?
    var fileTypes: [String]

    init(requiresImages: Bool = false, minReplies: Int? = nil, fileTypes: [String] = []) {
        self.requiresImages = requiresImages
        self.minReplies = minReplies
        self.fileTypes = fileTypes
    }

    var isActive: Bool {
        if requiresImages { return true }
        if let minReplies = minReplies, minReplies > 0 { return true }
        return !fileTypes.isEmpty
    }

    func normalized() -> SearchFilters {
        let normalizedTypes = SearchFilters.normalizeFileTypes(fileTypes)
        let normalizedReplies: Int?
        if let minReplies = minReplies, minReplies > 0 {
            normalizedReplies = minReplies
        } else {
            normalizedReplies = nil
        }

        return SearchFilters(
            requiresImages: requiresImages,
            minReplies: normalizedReplies,
            fileTypes: normalizedTypes
        )
    }

    func matches(thread: ThreadData) -> Bool {
        if requiresImages && thread.imageUrl.isEmpty {
            return false
        }

        if let minReplies = minReplies {
            let replyCount = thread.currentReplies ?? thread.replies
            if replyCount < minReplies {
                return false
            }
        }

        if !fileTypes.isEmpty {
            guard let ext = SearchFilters.imageExtension(from: thread.imageUrl) else {
                return false
            }
            let normalizedExt = SearchFilters.normalizeFileType(ext)
            if !fileTypes.contains(normalizedExt) {
                return false
            }
        }

        return true
    }

    private static func imageExtension(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return ext.isEmpty ? nil : ext.lowercased()
    }

    private static func normalizeFileType(_ value: String) -> String {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix(".") {
            normalized.removeFirst()
        }
        if normalized == "jpeg" {
            normalized = "jpg"
        }
        return normalized
    }

    private static func normalizeFileTypes(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var results: [String] = []
        for raw in values {
            let normalized = normalizeFileType(raw)
            if normalized.isEmpty { continue }
            if seen.insert(normalized).inserted {
                results.append(normalized)
            }
        }
        return results
    }
}
