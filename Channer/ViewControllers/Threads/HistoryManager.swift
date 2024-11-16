import Foundation
import Alamofire
import SwiftyJSON

class HistoryManager {
    static let shared = HistoryManager()
    
    private let historyKey = "threadHistory"
    
    private(set) var history: [ThreadData] = []
    
    private init() {
        loadHistory()
    }
    
    func addThreadToHistory(_ thread: ThreadData) {
        // Avoid duplicates
        if !history.contains(where: { $0.number == thread.number && $0.boardAbv == thread.boardAbv }) {
            history.append(thread)
            saveHistory()
        }
    }
    
    func removeThreadFromHistory(_ thread: ThreadData) {
        history.removeAll { $0.number == thread.number && $0.boardAbv == thread.boardAbv }
        saveHistory()
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let savedHistory = try? JSONDecoder().decode([ThreadData].self, from: data) {
            history = savedHistory
        }
    }
    
    func getHistoryThreads() -> [ThreadData] {
            return history
    }
    
    func verifyAndRemoveInvalidHistory(completion: @escaping ([ThreadData]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var validHistory: [ThreadData] = []

        for thread in history {
            dispatchGroup.enter()
            let url = "https://a.4cdn.org/\(thread.boardAbv)/thread/\(thread.number).json"
            
            AF.request(url).responseData { response in
                defer { dispatchGroup.leave() }
                switch response.result {
                case .success(let data):
                    if let json = try? JSON(data: data), let _ = json["posts"].array?.first {
                        validHistory.append(thread)
                    } else {
                        self.removeThreadFromHistory(thread)
                    }
                case .failure:
                    self.removeThreadFromHistory(thread)
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(validHistory)
        }
    }
}
