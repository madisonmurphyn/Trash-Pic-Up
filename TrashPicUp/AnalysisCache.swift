import Foundation
import Photos

// Make PhotoAnalysis Codable for persistence
extension PhotoAnalysis: Codable {
    enum CodingKeys: String, CodingKey {
        case isDuplicate
        case isScreenshot
        case isBlurry
        case blurScore
        case duplicateGroup
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isDuplicate = try container.decode(Bool.self, forKey: .isDuplicate)
        isScreenshot = try container.decode(Bool.self, forKey: .isScreenshot)
        isBlurry = try container.decode(Bool.self, forKey: .isBlurry)
        blurScore = try container.decode(Double.self, forKey: .blurScore)
        duplicateGroup = try container.decodeIfPresent(String.self, forKey: .duplicateGroup)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isDuplicate, forKey: .isDuplicate)
        try container.encode(isScreenshot, forKey: .isScreenshot)
        try container.encode(isBlurry, forKey: .isBlurry)
        try container.encode(blurScore, forKey: .blurScore)
        try container.encodeIfPresent(duplicateGroup, forKey: .duplicateGroup)
    }
}

// Cache entry that includes photo metadata to detect changes
struct CachedAnalysis: Codable {
    let analysis: PhotoAnalysis
    let photoModificationDate: Date?
    let photoCreationDate: Date?
    let cachedDate: Date
}

class AnalysisCache {
    static let shared = AnalysisCache()
    
    private let cacheFileName = "photo_analysis_cache.json"
    private var cache: [String: CachedAnalysis] = [:]
    private let cacheQueue = DispatchQueue(label: "com.trashpicup.analysisCache", attributes: .concurrent)
    private let maxCacheSize = 20_000
    private let evictBatchSize = 1_000
    
    private init() {
        loadCache()
    }
    
    private var cacheURL: URL? {
        // Store in Application Support directory
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appFolder = appSupport.appendingPathComponent("TrashPicUp", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        return appFolder.appendingPathComponent(cacheFileName)
    }
    
    func loadCache() {
        guard let url = cacheURL,
              FileManager.default.fileExists(atPath: url.path) else {
            cache = [:]
            print("No cache file found at: \(cacheURL?.path ?? "unknown")")
            return
        }
        
        // Load synchronously to ensure cache is ready before analysis starts
        cacheQueue.sync(flags: .barrier) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                self.cache = try decoder.decode([String: CachedAnalysis].self, from: data)
                print("✅ Loaded \(self.cache.count) cached analysis results from: \(url.path)")
            } catch {
                print("❌ Error loading cache: \(error)")
                self.cache = [:]
            }
        }
    }
    
    func saveCache() {
        guard let url = cacheURL else {
            print("⚠️ Cannot save cache: cacheURL is nil")
            return
        }
        
        cacheQueue.async(flags: .barrier) {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(self.cache)
                try data.write(to: url)
                print("💾 Saved \(self.cache.count) analysis results to cache at: \(url.path)")
            } catch {
                print("❌ Error saving cache: \(error)")
            }
        }
    }
    
    // Get cache statistics for debugging
    func getCacheStats() -> (count: Int, location: String) {
        return cacheQueue.sync {
            (cache.count, cacheURL?.path ?? "unknown")
        }
    }
    
    func getCachedAnalysis(for photoId: String, asset: PHAsset) -> PhotoAnalysis? {
        return cacheQueue.sync {
            guard let cached = cache[photoId] else {
                return nil
            }
            
            // Check if photo has been modified since cache was created
            let assetModificationDate = asset.modificationDate
            let assetCreationDate = asset.creationDate
            
            // If modification dates don't match, invalidate cache
            if cached.photoModificationDate != assetModificationDate ||
               cached.photoCreationDate != assetCreationDate {
                // Photo was modified, remove from cache
                cache.removeValue(forKey: photoId)
                return nil
            }
            
            // Check if cache is too old (e.g., older than 30 days)
            let cacheAge = Date().timeIntervalSince(cached.cachedDate)
            if cacheAge > 30 * 24 * 60 * 60 { // 30 days
                cache.removeValue(forKey: photoId)
                return nil
            }
            
            return cached.analysis
        }
    }
    
    func setCachedAnalysis(_ analysis: PhotoAnalysis, for photoId: String, asset: PHAsset) {
        cacheQueue.async(flags: .barrier) {
            if self.cache.count >= self.maxCacheSize, self.cache[photoId] == nil {
                let byDate = self.cache.sorted { ($0.value.cachedDate) < ($1.value.cachedDate) }
                let toRemove = byDate.prefix(self.evictBatchSize).map { $0.key }
                for k in toRemove { self.cache.removeValue(forKey: k) }
            }
            let cached = CachedAnalysis(
                analysis: analysis,
                photoModificationDate: asset.modificationDate,
                photoCreationDate: asset.creationDate,
                cachedDate: Date()
            )
            self.cache[photoId] = cached
            if self.cache.count % 50 == 0 { self.saveCache() }
        }
    }
    
    // Save cache immediately (for testing/debugging)
    func saveCacheNow() {
        saveCache()
    }
    
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
            self.saveCache()
        }
    }
    
    func removeFromCache(photoId: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeValue(forKey: photoId)
        }
    }
    
    // Force save (call this when app is about to terminate)
    func forceSave() {
        guard let url = cacheURL else { return }
        
        // Use sync to ensure save completes before returning
        cacheQueue.sync(flags: .barrier) {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(self.cache)
                try data.write(to: url)
                print("Force saved \(self.cache.count) analysis results to cache")
            } catch {
                print("Error force saving cache: \(error)")
            }
        }
    }
}
