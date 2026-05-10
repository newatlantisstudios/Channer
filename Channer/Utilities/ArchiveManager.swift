import Foundation
import SwiftyJSON

struct ArchiveEndpoint: Codable, Equatable {
    let uid: Int?
    let name: String
    let domain: String
    let http: Bool?
    let https: Bool?
    let software: String
    let boards: [String]?
    let files: [String]?
    let search: [String]?
    let reports: Bool?

    var identifier: String {
        uid.map(String.init) ?? name
    }
}

struct ArchiveReportResult {
    let archiveName: String
    let successMessage: String?
    let errorMessage: String?
}

final class ArchiveManager {
    static let shared = ArchiveManager()

    private enum Capability {
        case thread
        case threadJSON
        case post
        case file
        case report
    }

    private enum Constants {
        static let archiveListURL = URL(string: "https://4chenz.github.io/archives.json/archives.json")!
        static let archivesKey = "channer_archive_endpoints"
        static let lastArchiveCheckKey = "channer_archive_last_check"
        static let autoUpdateKey = "channer_archive_auto_update"
        static let updateInterval: TimeInterval = 2 * 24 * 60 * 60
    }

    private let queue = DispatchQueue(label: "com.channer.archive-manager", attributes: .concurrent)
    private var archives: [ArchiveEndpoint]

    private init() {
        if UserDefaults.standard.object(forKey: Constants.autoUpdateKey) == nil {
            UserDefaults.standard.set(true, forKey: Constants.autoUpdateKey)
        }

        if let data = UserDefaults.standard.data(forKey: Constants.archivesKey),
           let decoded = try? JSONDecoder().decode([ArchiveEndpoint].self, from: data),
           !decoded.isEmpty {
            archives = decoded
        } else {
            archives = ArchiveManager.defaultArchives
        }

        updateArchiveListIfNeeded()
    }

    func supportedArchives(for boardAbv: String) -> [ArchiveEndpoint] {
        archives(for: boardAbv, capability: .thread)
    }

    func archiveThreadURLs(boardAbv: String, threadNumber: String, postNumber: String? = nil) -> [(ArchiveEndpoint, URL)] {
        archives(for: boardAbv, capability: .thread).compactMap { archive in
            guard let url = threadURL(archive: archive, boardAbv: boardAbv, threadNumber: threadNumber, postNumber: postNumber) else {
                return nil
            }
            return (archive, url)
        }
    }

    func canFetchArchivedThread(boardAbv: String) -> Bool {
        preferredArchive(for: boardAbv, capability: .threadJSON) != nil
    }

    func canFetchArchivedPost(boardAbv: String) -> Bool {
        preferredArchive(for: boardAbv, capability: .post) != nil
    }

    func fetchArchivedThread(boardAbv: String, threadNumber: String, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let archive = preferredArchive(for: boardAbv, capability: .threadJSON),
              let url = threadJSONURL(archive: archive, boardAbv: boardAbv, threadNumber: threadNumber) else {
            completion(.failure(ArchiveError.noArchiveAvailable))
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let statusCode = (response as? HTTPURLResponse)?.statusCode,
               !(200..<300).contains(statusCode) {
                completion(.failure(ArchiveError.httpStatus(statusCode)))
                return
            }

            guard let self, let data else {
                completion(.failure(ArchiveError.emptyResponse))
                return
            }

            do {
                let converted = try self.convertArchivedThreadData(data, boardAbv: boardAbv, threadNumber: threadNumber)
                completion(.success(converted))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchArchivedPost(boardAbv: String, postNumber: String, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let archive = preferredArchive(for: boardAbv, capability: .post),
              let url = postJSONURL(archive: archive, boardAbv: boardAbv, postNumber: postNumber) else {
            completion(.failure(ArchiveError.noArchiveAvailable))
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let statusCode = (response as? HTTPURLResponse)?.statusCode,
               !(200..<300).contains(statusCode) {
                completion(.failure(ArchiveError.httpStatus(statusCode)))
                return
            }

            guard let self, let data else {
                completion(.failure(ArchiveError.emptyResponse))
                return
            }

            do {
                let raw = try JSON(data: data)
                if let error = raw["error"].string, !error.isEmpty {
                    throw ArchiveError.archiveMessage(error)
                }
                let converted = self.convertArchivePost(raw, boardAbv: boardAbv)
                let wrapped = JSON(["posts": [converted]])
                completion(.success(try wrapped.rawData()))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func reportPost(boardAbv: String, postNumber: String, reason: String, completion: @escaping ([ArchiveReportResult]) -> Void) {
        let endpoints = reportEndpoints(boardAbv: boardAbv)
        guard !endpoints.isEmpty else {
            completion([])
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var results: [ArchiveReportResult] = []

        for (archive, url) in endpoints {
            group.enter()
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = formBody([
                "board": boardAbv,
                "num": postNumber,
                "reason": reason
            ])

            URLSession.shared.dataTask(with: request) { data, response, error in
                defer { group.leave() }

                let result: ArchiveReportResult
                if let error = error {
                    result = ArchiveReportResult(archiveName: archive.name, successMessage: nil, errorMessage: error.localizedDescription)
                } else if let statusCode = (response as? HTTPURLResponse)?.statusCode,
                          !(200..<300).contains(statusCode) {
                    result = ArchiveReportResult(archiveName: archive.name, successMessage: nil, errorMessage: "HTTP \(statusCode)")
                } else if let data,
                          let json = try? JSON(data: data),
                          let success = json["success"].string {
                    result = ArchiveReportResult(archiveName: archive.name, successMessage: success, errorMessage: nil)
                } else if let data,
                          let json = try? JSON(data: data),
                          let message = json["error"].string {
                    result = ArchiveReportResult(archiveName: archive.name, successMessage: nil, errorMessage: message)
                } else {
                    result = ArchiveReportResult(archiveName: archive.name, successMessage: "Report submitted", errorMessage: nil)
                }

                lock.lock()
                results.append(result)
                lock.unlock()
            }.resume()
        }

        group.notify(queue: .main) {
            completion(results.sorted { $0.archiveName < $1.archiveName })
        }
    }

    func updateArchiveList(completion: ((Bool) -> Void)? = nil) {
        URLSession.shared.dataTask(with: Constants.archiveListURL) { [weak self] data, response, _ in
            guard let self,
                  let data,
                  let statusCode = (response as? HTTPURLResponse)?.statusCode,
                  (200..<300).contains(statusCode),
                  let decoded = try? JSONDecoder().decode([ArchiveEndpoint].self, from: data),
                  !decoded.isEmpty else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            self.queue.async(flags: .barrier) {
                self.archives = decoded
                if let encoded = try? JSONEncoder().encode(decoded) {
                    UserDefaults.standard.set(encoded, forKey: Constants.archivesKey)
                }
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Constants.lastArchiveCheckKey)
                DispatchQueue.main.async { completion?(true) }
            }
        }.resume()
    }

    private func updateArchiveListIfNeeded() {
        guard UserDefaults.standard.bool(forKey: Constants.autoUpdateKey) else { return }

        let lastCheck = UserDefaults.standard.double(forKey: Constants.lastArchiveCheckKey)
        let now = Date().timeIntervalSince1970
        guard lastCheck == 0 || now - lastCheck >= Constants.updateInterval || lastCheck > now else { return }

        updateArchiveList()
    }

    private func archives(for boardAbv: String, capability: Capability) -> [ArchiveEndpoint] {
        let board = boardAbv.lowercased()
        return queue.sync {
            archives.filter { archive in
                supports(archive: archive, boardAbv: board, capability: capability)
            }
        }
    }

    private func preferredArchive(for boardAbv: String, capability: Capability) -> ArchiveEndpoint? {
        archives(for: boardAbv, capability: capability).first
    }

    private func supports(archive: ArchiveEndpoint, boardAbv: String, capability: Capability) -> Bool {
        let software = archive.software.lowercased()
        guard software == "fuuka" || software == "foolfuuka" else { return false }

        switch capability {
        case .thread:
            return contains(boardAbv, in: archive.boards)
        case .threadJSON, .post:
            return software == "foolfuuka" && contains(boardAbv, in: archive.boards)
        case .file:
            return contains(boardAbv, in: archive.files)
        case .report:
            return software == "foolfuuka" && archive.https == true && archive.reports == true && contains(boardAbv, in: archive.boards)
        }
    }

    private func contains(_ boardAbv: String, in boards: [String]?) -> Bool {
        boards?.contains { $0.caseInsensitiveCompare(boardAbv) == .orderedSame } == true
    }

    private func preferredProtocol(for archive: ArchiveEndpoint) -> String? {
        if archive.https == true { return "https" }
        if archive.http == true { return "http" }
        return nil
    }

    private func threadURL(archive: ArchiveEndpoint, boardAbv: String, threadNumber: String, postNumber: String?) -> URL? {
        guard let proto = preferredProtocol(for: archive) else { return nil }

        let software = archive.software.lowercased()
        let basePath: String
        if threadNumber.isEmpty || threadNumber == "0" {
            basePath = "\(boardAbv)/post/\(postNumber ?? "")"
        } else {
            basePath = "\(boardAbv)/thread/\(threadNumber)"
        }

        var path = software == "foolfuuka" ? "\(basePath)/" : basePath
        if !threadNumber.isEmpty, threadNumber != "0", let postNumber {
            path += software == "foolfuuka" ? "#\(postNumber)" : "#p\(postNumber)"
        }

        return URL(string: "\(proto)://\(archive.domain)/\(path)")
    }

    private func threadJSONURL(archive: ArchiveEndpoint, boardAbv: String, threadNumber: String) -> URL? {
        guard let proto = preferredProtocol(for: archive) else { return nil }
        var components = URLComponents(string: "\(proto)://\(archive.domain)/_/api/chan/thread/")
        components?.queryItems = [
            URLQueryItem(name: "board", value: boardAbv),
            URLQueryItem(name: "num", value: threadNumber)
        ]
        return components?.url
    }

    private func postJSONURL(archive: ArchiveEndpoint, boardAbv: String, postNumber: String) -> URL? {
        guard let proto = preferredProtocol(for: archive) else { return nil }
        var components = URLComponents(string: "\(proto)://\(archive.domain)/_/api/chan/post/")
        components?.queryItems = [
            URLQueryItem(name: "board", value: boardAbv),
            URLQueryItem(name: "num", value: postNumber)
        ]
        return components?.url
    }

    private func fileURL(boardAbv: String, filename: String) -> String? {
        guard let archive = preferredArchive(for: boardAbv, capability: .file),
              let proto = preferredProtocol(for: archive),
              !filename.isEmpty,
              !filename.hasSuffix("s.jpg"),
              !filename.hasSuffix("m.jpg") else {
            return nil
        }

        var archiveFilename = filename
        if archive.name.hasSuffix("arch.b4k.co") || archive.name.hasSuffix("palanq.win") || archive.domain.hasSuffix("palanq.win") {
            let parts = filename.split(separator: ".", maxSplits: 1).map(String.init)
            if parts.count == 2, parts[0].count > 13 {
                archiveFilename = "\(String(parts[0].dropLast(3))).\(parts[1])"
            }
        }

        return "\(proto)://\(archive.domain)/\(boardAbv)/full_image/\(archiveFilename)"
    }

    private func reportEndpoints(boardAbv: String) -> [(ArchiveEndpoint, URL)] {
        archives(for: boardAbv, capability: .report).compactMap { archive in
            URL(string: "https://\(archive.domain)/_/api/chan/offsite_report/").map { (archive, $0) }
        }
    }

    private func convertArchivedThreadData(_ data: Data, boardAbv: String, threadNumber: String) throws -> Data {
        let json = try JSON(data: data)
        let candidates = [
            json[threadNumber]["posts"],
            json["posts"],
            json
        ]

        var rawPosts: [JSON] = []
        for candidate in candidates {
            if let dictionary = candidate.dictionary, !dictionary.isEmpty {
                rawPosts = dictionary.values.map { $0 }
                break
            }

            if let array = candidate.array, !array.isEmpty {
                rawPosts = array
                break
            }
        }

        guard !rawPosts.isEmpty else {
            throw ArchiveError.emptyResponse
        }

        let convertedPosts = rawPosts
            .sorted { postNumber(from: $0) < postNumber(from: $1) }
            .map { convertArchivePost($0, boardAbv: boardAbv) }

        var adjustedPosts = convertedPosts
        if var op = adjustedPosts.first {
            op["replies"] = max(adjustedPosts.count - 1, 0)
            op["images"] = adjustedPosts.filter { $0["tim"] != nil }.count
            adjustedPosts[0] = op
        }

        return try JSON(["posts": adjustedPosts]).rawData()
    }

    private func convertArchivePost(_ raw: JSON, boardAbv: String) -> [String: Any] {
        let postNo = postNumber(from: raw)
        let threadNo = raw["thread_num"].int ?? Int(raw["thread_num"].stringValue) ?? postNo
        let media = raw["media"]
        let mediaOriginal = media["media_orig"].stringValue
        let mediaFilename = media["media_filename"].stringValue
        let mediaExt = extensionFromFilename(mediaOriginal)
        var post: [String: Any] = [
            "no": postNo,
            "resto": postNo == threadNo ? 0 : threadNo,
            "com": archiveCommentHTML(raw["comment"].stringValue),
            "sub": raw["title"].stringValue,
            "name": raw["name"].stringValue,
            "trip": raw["trip"].stringValue,
            "id": raw["poster_hash"].stringValue,
            "country": raw["poster_country"].stringValue,
            "country_name": raw["poster_country_name"].stringValue,
            "time": raw["timestamp"].int ?? Int(raw["timestamp"].stringValue) ?? 0,
            "now": raw["fourchan_date"].stringValue
        ]

        if !mediaOriginal.isEmpty, media["banned"].intValue == 0 {
            let stem = mediaOriginal.split(separator: ".", maxSplits: 1).first.map(String.init) ?? mediaOriginal
            if let tim = Int64(stem) {
                post["tim"] = tim
            } else {
                post["tim"] = stem
            }

            post["ext"] = mediaExt
            post["filename"] = filenameWithoutExtension(mediaFilename)
            post["md5"] = media["media_hash"].stringValue

            if let archiveImageURL = fileURL(boardAbv: boardAbv, filename: mediaOriginal) {
                post["archive_image_url"] = archiveImageURL
            }
        }

        return post
    }

    private func postNumber(from raw: JSON) -> Int {
        raw["num"].int ?? Int(raw["num"].stringValue) ?? 0
    }

    private func archiveCommentHTML(_ comment: String) -> String {
        comment.components(separatedBy: "\n").map { rawLine in
            var line = escapeHTML(rawLine)
            line = replaceArchiveMarkup(in: line)
            line = linkifyQuoteReferences(in: line)
            if rawLine.hasPrefix(">"), !rawLine.hasPrefix(">>") {
                line = "<span class=\"quote\">\(line)</span>"
            }
            return line
        }.joined(separator: "<br>")
    }

    private func replaceArchiveMarkup(in line: String) -> String {
        line
            .replacingOccurrences(of: "[spoiler]", with: "<s>")
            .replacingOccurrences(of: "[/spoiler]", with: "</s>")
            .replacingOccurrences(of: "[b]", with: "")
            .replacingOccurrences(of: "[/b]", with: "")
            .replacingOccurrences(of: "[i]", with: "")
            .replacingOccurrences(of: "[/i]", with: "")
            .replacingOccurrences(of: "[code]", with: "<code>")
            .replacingOccurrences(of: "[/code]", with: "</code>")
    }

    private func linkifyQuoteReferences(in line: String) -> String {
        let pattern = #"&gt;&gt;(?:/[a-z\d]+/)?(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return line
        }

        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.stringByReplacingMatches(in: line, options: [], range: nsRange, withTemplate: ##"<a href="#p$1" class="quotelink">&gt;&gt;$1</a>"##)
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#039;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func extensionFromFilename(_ filename: String) -> String {
        guard let dotIndex = filename.lastIndex(of: ".") else { return "" }
        return String(filename[dotIndex...])
    }

    private func filenameWithoutExtension(_ filename: String) -> String {
        guard let dotIndex = filename.lastIndex(of: ".") else { return filename }
        return String(filename[..<dotIndex])
    }

    private func formBody(_ values: [String: String]) -> Data {
        values.map { key, value in
            "\(formEncode(key))=\(formEncode(value))"
        }
        .joined(separator: "&")
        .data(using: .utf8) ?? Data()
    }

    private func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "+", with: "%2B") ?? value
    }
}

enum ArchiveError: LocalizedError {
    case noArchiveAvailable
    case emptyResponse
    case httpStatus(Int)
    case archiveMessage(String)

    var errorDescription: String? {
        switch self {
        case .noArchiveAvailable:
            return "No archive supports this board."
        case .emptyResponse:
            return "The archive did not return any posts."
        case .httpStatus(let status):
            return "The archive returned HTTP \(status)."
        case .archiveMessage(let message):
            return message
        }
    }
}

private extension ArchiveManager {
    static let defaultArchives: [ArchiveEndpoint] = {
        let data = Data("""
        [{"uid":3,"name":"4plebs","domain":"archive.4plebs.org","http":true,"https":true,"software":"foolfuuka","boards":["adv","f","hr","mlpol","mo","o","pol","s4s","sp","tg","trv","tv","x"],"files":["adv","f","hr","mlpol","mo","o","pol","s4s","sp","tg","trv","tv","x"],"reports":true},{"uid":10,"name":"warosu","domain":"warosu.org","http":false,"https":true,"software":"fuuka","boards":["3","biz","cgl","ck","diy","fa","ic","jp","lit","sci","vr","vt"],"files":["3","biz","cgl","ck","diy","fa","ic","jp","lit","sci","vr","vt"],"search":["biz","cgl","ck","diy","fa","ic","jp","lit","sci","vr","vt"]},{"uid":23,"name":"Desuarchive","domain":"desuarchive.org","http":true,"https":true,"software":"foolfuuka","boards":["a","aco","an","c","cgl","co","d","fit","g","his","int","k","m","mlp","mu","q","qa","r9k","tg","trash","vr","wsg"],"files":["a","aco","an","c","cgl","co","d","fit","g","his","int","k","m","mlp","mu","q","qa","r9k","tg","trash","vr"],"reports":true},{"uid":24,"name":"fireden.net","domain":"boards.fireden.net","http":false,"https":true,"software":"foolfuuka","boards":["cm","co","ic","sci","vip","y"],"files":["cm","co","ic","sci","vip","y"],"search":["cm","co","ic","sci","y"]},{"uid":25,"name":"not arch.b4k.co","domain":"arch.b4k.dev","http":true,"https":true,"software":"foolfuuka","boards":["g","mlp","qb","v","vg","vm","vmg","vp","vrpg","vst"],"files":["qb","v","vg","vm","vmg","vp","vrpg","vst"],"search":["qb","v","vg","vm","vmg","vp","vrpg","vst"]},{"uid":29,"name":"Archived.Moe","domain":"archived.moe","http":true,"https":true,"software":"foolfuuka","boards":["3","a","aco","adv","an","asp","b","bant","biz","c","can","cgl","ck","cm","co","cock","con","d","diy","e","f","fa","fap","fit","fitlit","g","gd","gif","h","hc","his","hm","hr","i","ic","int","jp","k","lgbt","lit","m","mlp","mlpol","mo","mtv","mu","n","news","o","out","outsoc","p","po","pol","pw","q","qa","qb","qst","r","r9k","s","s4s","sci","soc","sp","spa","t","tg","toy","trash","trv","tv","u","v","vg","vint","vip","vm","vmg","vp","vr","vrpg","vst","vt","w","wg","wsg","wsr","x","xs","y"],"files":["can","cock","con","fap","fitlit","gd","mlpol","mo","mtv","outsoc","po","q","qb","qst","spa","vint","vip"],"search":["aco","adv","an","asp","b","bant","biz","c","can","cgl","ck","cm","cock","con","d","diy","e","f","fap","fitlit","gd","gif","h","hc","his","hm","hr","i","ic","lgbt","lit","mlpol","mo","mtv","n","news","o","out","outsoc","p","po","pw","q","qa","qst","r","s","soc","spa","trv","u","vint","vip","vrpg","w","wg","wsg","wsr","x","y"],"reports":true},{"uid":30,"name":"TheBArchive.com","domain":"thebarchive.com","http":true,"https":true,"software":"foolfuuka","boards":["b","bant"],"files":["b","bant"],"reports":true},{"uid":31,"name":"Archive Of Sins","domain":"archiveofsins.com","http":true,"https":true,"software":"foolfuuka","boards":["h","hc","hm","i","lgbt","r","s","soc","t","u"],"files":["h","hc","hm","i","lgbt","r","s","soc","t","u"],"reports":true},{"uid":36,"name":"palanq.win","domain":"archive.palanq.win","http":false,"https":true,"software":"foolfuuka","boards":["bant","c","con","e","i","n","news","out","p","pw","qst","toy","vip","vp","vt","w","wg","wsr"],"files":["bant","c","e","i","n","news","out","p","pw","qst","toy","vip","vp","vt","w","wg","wsr"],"reports":true},{"uid":37,"name":"Eientei","domain":"eientei.xyz","http":false,"https":true,"software":"Eientei","boards":["3","i","sci","xs"],"files":["3","i","sci","xs"],"reports":true}]
        """.utf8)
        return (try? JSONDecoder().decode([ArchiveEndpoint].self, from: data)) ?? []
    }()
}
