//
//  WatchedRequestsManager.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import Foundation
import Combine

class WatchedRequestsManager: ObservableObject {
    static let shared = WatchedRequestsManager()
    
    @Published private(set) var watchedRequestIds: Set<String> = []
    
    private let userDefaultsKey = "watchedRequestIds"
    
    private init() {
        loadWatchedRequests()
    }
    
    func isWatched(requestId: String) -> Bool {
        return watchedRequestIds.contains(requestId)
    }
    
    func toggleWatched(requestId: String) {
        if watchedRequestIds.contains(requestId) {
            watchedRequestIds.remove(requestId)
        } else {
            watchedRequestIds.insert(requestId)
        }
        saveWatchedRequests()
    }
    
    func setWatched(requestId: String, isWatched: Bool) {
        if isWatched {
            watchedRequestIds.insert(requestId)
        } else {
            watchedRequestIds.remove(requestId)
        }
        saveWatchedRequests()
    }
    
    private func loadWatchedRequests() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            watchedRequestIds = Set(ids)
        }
    }
    
    private func saveWatchedRequests() {
        let idsArray = Array(watchedRequestIds)
        if let data = try? JSONEncoder().encode(idsArray) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
