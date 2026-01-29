//
//  MapboxCacheManager.swift
//  Shipit
//
//  Created on 30.12.2025.
//

import Foundation
import MapboxMaps

class MapboxCacheManager {
    static let shared = MapboxCacheManager()
    
    private init() {}
    
    /// Clears the Mapbox cache (tiles, styles, and other cached resources)
    func clearCache() {
        // Get the cache directory path
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        
        guard let cacheDir = cacheDirectory else {
            print("❌ Mapbox Cache: Could not find cache directory")
            return
        }
        
        // Mapbox typically stores cache in a subdirectory
        // The exact path may vary by SDK version, but we'll try common locations
        let mapboxCachePaths = [
            cacheDir.appendingPathComponent("com.mapbox.maps"),
            cacheDir.appendingPathComponent("mapbox"),
            cacheDir.appendingPathComponent(".mapbox")
        ]
        
        var clearedCount = 0
        for cachePath in mapboxCachePaths {
            if FileManager.default.fileExists(atPath: cachePath.path) {
                do {
                    try FileManager.default.removeItem(at: cachePath)
                    clearedCount += 1
                    print("✅ Mapbox Cache: Cleared cache at \(cachePath.lastPathComponent)")
                } catch {
                    print("⚠️ Mapbox Cache: Could not clear \(cachePath.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        
        if clearedCount > 0 {
            print("✅ Mapbox Cache: Successfully cleared \(clearedCount) cache location(s)")
        } else {
            print("ℹ️ Mapbox Cache: No cache locations found to clear")
        }
    }
    
    /// Clears cache and returns a completion handler
    func clearCache(completion: @escaping (Bool, String) -> Void) {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        
        guard let cacheDir = cacheDirectory else {
            completion(false, "Could not find cache directory")
            return
        }
        
        let mapboxCachePaths = [
            cacheDir.appendingPathComponent("com.mapbox.maps"),
            cacheDir.appendingPathComponent("mapbox"),
            cacheDir.appendingPathComponent(".mapbox")
        ]
        
        var clearedCount = 0
        var errors: [String] = []
        
        for cachePath in mapboxCachePaths {
            if FileManager.default.fileExists(atPath: cachePath.path) {
                do {
                    try FileManager.default.removeItem(at: cachePath)
                    clearedCount += 1
                } catch {
                    errors.append("\(cachePath.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        
        if clearedCount > 0 {
            let message = "Cleared \(clearedCount) cache location(s)"
            completion(true, message)
        } else if errors.isEmpty {
            completion(true, "No cache found to clear")
        } else {
            completion(false, errors.joined(separator: "; "))
        }
    }
}
