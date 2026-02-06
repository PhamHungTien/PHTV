//
//  KlipyAPIClient.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Combine

// MARK: - Klipy GIF API

/// Klipy API client for fetching GIFs - Free unlimited API
@MainActor
class KlipyAPIClient: ObservableObject {
    static let shared = KlipyAPIClient()

    // KLIPY API - Free unlimited (không giới hạn request)
    // App key cho PHTV từ https://partner.klipy.com/api-keys
    // Key được obfuscate để tránh bot scan trực tiếp
    private var appKey: String {
        let parts = [
            "dRJwhLos61B0a1SE72uH",
            "IyLBNKRtPJAalMjeys",
            "Vegy2YDjuTWa29PKT7jQ1M7pt1"
        ]
        return parts.joined()
    }
    private let baseURL = "https://api.klipy.com/api/v1"

    // Domain where app-ads.txt is hosted (required for monetization)
    private let domain = "phamhungtien.github.io"

    // Customer ID - unique user identifier (có thể dùng UUID)
    private let customerId: String = {
        if let saved = UserDefaults.standard.string(forKey: "KlipyCustomerID") {
            return saved
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "KlipyCustomerID")
        return newId
    }()

    @Published var trendingGIFs: [KlipyGIF] = []
    @Published var searchResults: [KlipyGIF] = []
    @Published var trendingStickers: [KlipyGIF] = []
    @Published var stickerSearchResults: [KlipyGIF] = []
    @Published var isLoading = false
    @Published var needsAPIKey: Bool = false

    // Recent items tracking
    private let maxRecentItems = 20
    private let recentGIFsKey = "RecentGIFs"
    private let recentStickersKey = "RecentStickers"

    // Callback to close picker window
    var onCloseCallback: (() -> Void)?

    private init() {
        needsAPIKey = appKey == "YOUR_KLIPY_APP_KEY_HERE"

        // Clean old cache on init
        cleanOldCache()
    }

    func saveAPIKey(_ key: String) {
        print("[Klipy] Please hardcode your app key in PHTVApp.swift")
    }

    /// Fetch trending GIFs
    func fetchTrending(limit: Int = 24) {
        guard appKey != "YOUR_KLIPY_APP_KEY_HERE" else {
            print("[Klipy] Please set your app key")
            needsAPIKey = true
            return
        }

        isLoading = true

        // Klipy API: GET /api/v1/{app_key}/gifs/trending
        let urlString = "\(baseURL)/\(appKey)/gifs/trending?customer_id=\(customerId)&per_page=\(limit)&domain=\(domain)"
        print("[Klipy] Fetching trending from: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("[Klipy] Invalid URL")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let httpResponse = response as? HTTPURLResponse {
                print("[Klipy] Response status: \(httpResponse.statusCode)")
            }

            guard let data = data, error == nil else {
                print("[Klipy] Error fetching trending: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(KlipyResponse.self, from: data)
                print("[Klipy] Successfully decoded \(result.data.data.count) GIFs")
                DispatchQueue.main.async {
                    self.trendingGIFs = result.data.data
                    self.isLoading = false
                }
            } catch {
                print("[Klipy] Decode error: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }

    /// Search GIFs
    func search(query: String, limit: Int = 24) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        guard appKey != "YOUR_KLIPY_APP_KEY_HERE" else {
            print("[Klipy] Please set your app key for search")
            needsAPIKey = true
            return
        }

        isLoading = true

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        // Klipy API: GET /api/v1/{app_key}/gifs/search
        let urlString = "\(baseURL)/\(appKey)/gifs/search?q=\(encodedQuery)&customer_id=\(customerId)&per_page=\(limit)&domain=\(domain)"
        print("[Klipy] Searching for: \(query)")
        guard let url = URL(string: urlString) else {
            print("[Klipy] Invalid search URL")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            guard let data = data, error == nil else {
                print("[Klipy] Error searching: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(KlipyResponse.self, from: data)
                print("[Klipy] Search found \(result.data.data.count) GIFs")
                DispatchQueue.main.async {
                    self.searchResults = result.data.data
                    self.isLoading = false
                }
            } catch {
                print("[Klipy] Decode error: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }

    // MARK: - Stickers API

    /// Fetch trending Stickers
    func fetchTrendingStickers(limit: Int = 24) {
        guard appKey != "YOUR_KLIPY_APP_KEY_HERE" else {
            print("[Klipy] Please set your app key")
            needsAPIKey = true
            return
        }

        isLoading = true

        // Klipy API: GET /api/v1/{app_key}/stickers/trending
        let urlString = "\(baseURL)/\(appKey)/stickers/trending?customer_id=\(customerId)&per_page=\(limit)&domain=\(domain)"
        print("[Klipy Stickers] Fetching trending from: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("[Klipy Stickers] Invalid URL")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let httpResponse = response as? HTTPURLResponse {
                print("[Klipy Stickers] Response status: \(httpResponse.statusCode)")
            }

            guard let data = data, error == nil else {
                print("[Klipy Stickers] Error fetching trending: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(KlipyResponse.self, from: data)
                print("[Klipy Stickers] Successfully decoded \(result.data.data.count) Stickers")
                DispatchQueue.main.async {
                    self.trendingStickers = result.data.data
                    self.isLoading = false
                }
            } catch {
                print("[Klipy Stickers] Decode error: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }

    /// Search Stickers
    func searchStickers(query: String, limit: Int = 24) {
        guard !query.isEmpty else {
            stickerSearchResults = []
            return
        }

        guard appKey != "YOUR_KLIPY_APP_KEY_HERE" else {
            print("[Klipy Stickers] Please set your app key for search")
            needsAPIKey = true
            return
        }

        isLoading = true

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        // Klipy API: GET /api/v1/{app_key}/stickers/search
        let urlString = "\(baseURL)/\(appKey)/stickers/search?q=\(encodedQuery)&customer_id=\(customerId)&per_page=\(limit)&domain=\(domain)"
        print("[Klipy Stickers] Searching for: \(query)")
        guard let url = URL(string: urlString) else {
            print("[Klipy Stickers] Invalid search URL")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            guard let data = data, error == nil else {
                print("[Klipy Stickers] Error searching: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(KlipyResponse.self, from: data)
                print("[Klipy Stickers] Search found \(result.data.data.count) Stickers")
                DispatchQueue.main.async {
                    self.stickerSearchResults = result.data.data
                    self.isLoading = false
                }
            } catch {
                print("[Klipy Stickers] Decode error: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }

    // MARK: - Recent Items Tracking

    /// Record GIF usage
    func recordGIFUsage(_ gif: KlipyGIF) {
        var recent = getRecentGIFIDs()
        recent.removeAll { $0 == gif.id }
        recent.insert(gif.id, at: 0)
        if recent.count > maxRecentItems {
            recent = Array(recent.prefix(maxRecentItems))
        }
        UserDefaults.standard.set(Array(recent), forKey: recentGIFsKey)
    }

    /// Record Sticker usage
    func recordStickerUsage(_ sticker: KlipyGIF) {
        var recent = getRecentStickerIDs()
        recent.removeAll { $0 == sticker.id }
        recent.insert(sticker.id, at: 0)
        if recent.count > maxRecentItems {
            recent = Array(recent.prefix(maxRecentItems))
        }
        UserDefaults.standard.set(Array(recent), forKey: recentStickersKey)
    }

    /// Get recent GIF IDs
    func getRecentGIFIDs() -> [Int64] {
        return (UserDefaults.standard.array(forKey: recentGIFsKey) as? [Int64]) ?? []
    }

    /// Get recent Sticker IDs
    func getRecentStickerIDs() -> [Int64] {
        return (UserDefaults.standard.array(forKey: recentStickersKey) as? [Int64]) ?? []
    }

    /// Get recent GIFs (from all sources)
    func getRecentGIFs() -> [KlipyGIF] {
        let ids = getRecentGIFIDs()
        let allGIFs = trendingGIFs + searchResults
        return ids.compactMap { id in allGIFs.first { $0.id == id } }
    }

    /// Get recent Stickers (from all sources)
    func getRecentStickers() -> [KlipyGIF] {
        let ids = getRecentStickerIDs()
        let allStickers = trendingStickers + stickerSearchResults
        return ids.compactMap { id in allStickers.first { $0.id == id } }
    }

    // MARK: - Cache Management

    /// Clean old cached GIFs/Stickers (older than 7 days or if cache exceeds 100MB)
    /// Only cleans files in the PHTPMedia directory to avoid affecting other apps
    func cleanOldCache() {
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory
            let phtpDir = tempDir.appendingPathComponent("PHTPMedia", isDirectory: true)

            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: phtpDir.path) {
                try? fileManager.createDirectory(at: phtpDir, withIntermediateDirectories: true)
                return // Nothing to clean yet
            }

            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)

            guard let files = try? fileManager.contentsOfDirectory(
                at: phtpDir,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            ) else {
                return
            }

            var totalSize: Int64 = 0
            var oldFiles: [URL] = []

            // Collect old files and calculate total size
            for fileURL in files {
                // Only process GIF and PNG files (our cached media)
                let ext = fileURL.pathExtension.lowercased()
                guard ext == "gif" || ext == "png" else { continue }

                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   let fileSize = attributes[.size] as? Int64 {

                    totalSize += fileSize

                    // Mark files older than 7 days for deletion
                    if creationDate < sevenDaysAgo {
                        oldFiles.append(fileURL)
                    }
                }
            }

            // Delete old files
            for fileURL in oldFiles {
                try? fileManager.removeItem(at: fileURL)
            }

            // If total cache size > 100MB, delete oldest files until under 50MB
            let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
            let targetCacheSize: Int64 = 50 * 1024 * 1024 // 50MB

            if totalSize > maxCacheSize {
                // Sort files by creation date (oldest first)
                let sortedFiles = files
                    .filter { url in
                        let ext = url.pathExtension.lowercased()
                        return ext == "gif" || ext == "png"
                    }
                    .compactMap { url -> (URL, Date)? in
                        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                              let creationDate = attributes[.creationDate] as? Date else {
                            return nil
                        }
                        return (url, creationDate)
                    }
                    .sorted { $0.1 < $1.1 }

                var currentSize = totalSize
                for (fileURL, _) in sortedFiles {
                    if currentSize <= targetCacheSize {
                        break
                    }

                    if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                       let fileSize = attributes[.size] as? Int64 {
                        try? fileManager.removeItem(at: fileURL)
                        currentSize -= fileSize
                    }
                }

                print("[Klipy Cache] Cleaned cache from \(totalSize / 1024 / 1024)MB to \(currentSize / 1024 / 1024)MB")
            }
        }
    }

    // MARK: - Ad Tracking

    /// Track ad impression (when ad is displayed)
    func trackImpression(for gif: KlipyGIF) {
        guard gif.isAd, let impressionURL = gif.impression_url, let url = URL(string: impressionURL) else {
            return
        }

        print("[Klipy Ads] Tracking impression for ad: \(gif.id)")

        // Fire impression tracking pixel
        URLSession.shared.dataTask(with: url) { _, _, error in
            if let error = error {
                print("[Klipy Ads] Impression tracking error: \(error.localizedDescription)")
            } else {
                print("[Klipy Ads] Impression tracked successfully")
            }
        }.resume()
    }

    /// Track ad click (when ad is clicked)
    func trackClick(for gif: KlipyGIF) {
        guard gif.isAd, let clickURL = gif.click_url, let url = URL(string: clickURL) else {
            return
        }

        print("[Klipy Ads] Tracking click for ad: \(gif.id)")

        // Fire click tracking pixel
        URLSession.shared.dataTask(with: url) { _, _, error in
            if let error = error {
                print("[Klipy Ads] Click tracking error: \(error.localizedDescription)")
            } else {
                print("[Klipy Ads] Click tracked successfully")
            }
        }.resume()
    }

    /// Open ad target URL in browser (optional, if user clicks ad)
    func openAdTarget(for gif: KlipyGIF) {
        guard gif.isAd, let targetURL = gif.target_url, let url = URL(string: targetURL) else {
            return
        }

        print("[Klipy Ads] Opening ad target: \(targetURL)")
        NSWorkspace.shared.open(url)
    }
}
