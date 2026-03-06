import SwiftUI
import Photos
import CoreImage
import Vision
import Combine
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

class PhotoManager: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var photos: [PhotoItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var analysisProgress: Double = 0.0
    @Published var isAnalyzing = false
    
    private let photoAnalyzer = PhotoAnalyzer()
    private let analysisCache = AnalysisCache.shared
    
    /// True when we can access photos (full or limited selection).
    var hasPhotoAccess: Bool {
        #if os(iOS)
        return authorizationStatus == .authorized || authorizationStatus == .limited
        #else
        return authorizationStatus == .authorized
        #endif
    }
    
    func requestAuthorization() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        if authorizationStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    if self?.hasPhotoAccess == true {
                        self?.loadPhotos()
                    }
                }
            }
        } else if hasPhotoAccess {
            loadPhotos()
        }
    }
    
    #if os(iOS)
    /// Opens Settings so the user can change to "All Photos" or add more photos. Use when `authorizationStatus == .limited`.
    func openPhotoSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    #endif
    
    func loadPhotos() {
        guard hasPhotoAccess else { return }
        
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
            fetchOptions.fetchLimit = 3000

            let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            var photoItems: [PhotoItem] = []
            allPhotos.enumerateObjects { asset, _, _ in
                let resources = PHAssetResource.assetResources(for: asset)
                let size = resources.first?.value(forKey: "fileSize") as? Int64 ?? 0
                photoItems.append(PhotoItem(asset: asset, fileSize: size))
            }
            
            let screenshotIds = self.loadScreenshotAssetIds()
            
            DispatchQueue.main.async {
                self.photos = photoItems
                self.isLoading = false
                self.isAnalyzing = true
                self.analysisProgress = 0.0
                let cacheStats = self.analysisCache.getCacheStats()
                print("📊 Cache status: \(cacheStats.count) entries at \(cacheStats.location)")
                self.analyzePhotos(screenshotIds: screenshotIds)
            }
        }
    }
    
    private func analyzePhotos(screenshotIds: Set<String>) {
        DispatchQueue.main.async {
            self.isAnalyzing = true
            self.analysisProgress = 0.0
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var analyses: [PhotoAnalysis] = []
            var photosToAnalyze: [(Int, PhotoItem)] = []
            let totalPhotos = self.photos.count
            
            var cachedCount = 0
            for (index, photo) in self.photos.enumerated() {
                if var cached = self.analysisCache.getCachedAnalysis(for: photo.id, asset: photo.asset) {
                    cachedCount += 1
                    cached.isScreenshot = self.photoAnalyzer.isScreenshot(asset: photo.asset, inScreenshotAlbum: screenshotIds)
                    if let hash = self.photoAnalyzer.registerPhotoForDuplicates(photo: photo) {
                        cached.duplicateGroup = hash
                    }
                    analyses.append(cached)
                } else {
                    photosToAnalyze.append((index, photo))
                    analyses.append(PhotoAnalysis())
                }
            }
            
            print("📈 Analysis: \(cachedCount) cached, \(photosToAnalyze.count) need analysis out of \(totalPhotos) total")
            
            for (analyzedIndex, (originalIndex, photo)) in photosToAnalyze.enumerated() {
                let analysis = self.photoAnalyzer.analyze(photo: photo, screenshotAssetIds: screenshotIds)
                analyses[originalIndex] = analysis
                self.analysisCache.setCachedAnalysis(analysis, for: photo.id, asset: photo.asset)

                let last = analyzedIndex == photosToAnalyze.count - 1
                let progressInterval = 200
                if last || (analyzedIndex + 1) % progressInterval == 0 {
                    let progress = photosToAnalyze.isEmpty ? 1.0 : Double(analyzedIndex + 1) / Double(photosToAnalyze.count)
                    DispatchQueue.main.async {
                        self.analysisProgress = progress
                    }
                }
            }

            if photosToAnalyze.isEmpty {
                DispatchQueue.main.async { self.analysisProgress = 1.0 }
            }
            
            // Second pass: mark duplicates properly (all but first in each group)
            // Note: This needs to run even for cached photos to ensure duplicates are marked correctly
            self.photoAnalyzer.markDuplicates(photos: self.photos, analyses: &analyses)
            
            // Update cached analyses with duplicate markings
            for (index, analysis) in analyses.enumerated() {
                if index < self.photos.count {
                    let photo = self.photos[index]
                    // Update cache with final analysis (including duplicate markings)
                    self.analysisCache.setCachedAnalysis(analysis, for: photo.id, asset: photo.asset)
                }
            }
            
            // Final update with all analyses including duplicate markings
            DispatchQueue.main.async {
                for (index, analysis) in analyses.enumerated() {
                    if index < self.photos.count {
                        self.photos[index].analysis = analysis
                    }
                }
                self.isAnalyzing = false
                self.analysisProgress = 1.0
            }
            
            self.photoAnalyzer.clearDuplicateGroups()

            self.analysisCache.forceSave()
            print("💾 Cache saved after analysis completion")
        }
    }
    
    func deletePhotos(_ photos: [PhotoItem], completion: @escaping (Bool, Error?) -> Void) {
        guard hasPhotoAccess else {
            DispatchQueue.main.async {
                completion(false, NSError(domain: "PhotoManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authorized"]))
            }
            return
        }
        
        let assets = photos.map { $0.asset }
        let photoIds = Set(photos.map { $0.id })
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }, completionHandler: { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    // Remove deleted photos from our list
                    self?.photos.removeAll { photoIds.contains($0.id) }
                    // Remove from cache
                    for photoId in photoIds {
                        self?.analysisCache.removeFromCache(photoId: photoId)
                    }
                }
                completion(success, error)
            }
        })
    }
    
    func refreshPhotos() {
        loadPhotos()
    }
    
    /// Fetches asset IDs in the "Screenshots" smart album (and albums named "Screenshots") for detection.
    private func loadScreenshotAssetIds() -> Set<String> {
        var ids = Set<String>()
        
        let screenshots = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil)
        screenshots.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            assets.enumerateObjects { asset, _, _ in
                ids.insert(asset.localIdentifier)
            }
        }
        
        let regular = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
        regular.enumerateObjects { collection, _, _ in
            let title = collection.localizedTitle?.lowercased() ?? ""
            guard title.contains("screenshot") else { return }
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            assets.enumerateObjects { asset, _, _ in
                ids.insert(asset.localIdentifier)
            }
        }
        
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        albums.enumerateObjects { collection, _, _ in
            let title = collection.localizedTitle?.lowercased() ?? ""
            guard title.contains("screenshot") else { return }
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            assets.enumerateObjects { asset, _, _ in
                ids.insert(asset.localIdentifier)
            }
        }
        
        if !ids.isEmpty {
            print("📷 Screenshots album(s): \(ids.count) assets")
        }
        return ids
    }
}

struct PhotoItem: Identifiable {
    let id: String
    let asset: PHAsset
    var analysis: PhotoAnalysis?
    /// Cached file size (bytes). Populated during load on background queue so sort-by-size doesn't block main.
    private(set) var fileSizeCache: Int64?

    init(asset: PHAsset, fileSize: Int64? = nil) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.fileSizeCache = fileSize
    }
    
    var image: PlatformImage? {
        var result: PlatformImage?
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        #if os(iOS)
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 300, height: 300),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            result = image
        }
        #else
        // Use requestImageDataAndOrientation for macOS
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { imageData, _, _, _ in
            if let imageData = imageData, let image = PlatformImage(data: imageData) {
                result = image
            }
        }
        #endif
        
        return result
    }
    
    func getThumbnail(completion: @escaping (PlatformImage?) -> Void) {
        getImage(targetSize: CGSize(width: 150, height: 150), deliveryMode: .fastFormat) { completion($0) }
    }

    /// Small thumbnail for analysis only (blur/duplicate). Reduces I/O and memory.
    func getAnalysisThumbnail(completion: @escaping (PlatformImage?) -> Void) {
        getImage(targetSize: CGSize(width: 96, height: 96), deliveryMode: .fastFormat) { completion($0) }
    }
    
    /// Load image at given size (e.g. full-screen). Use for detail/fullscreen view.
    func getImage(targetSize: CGSize, deliveryMode: PHImageRequestOptionsDeliveryMode = .highQualityFormat, completion: @escaping (PlatformImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = deliveryMode
        options.resizeMode = targetSize.width >= 800 ? .none : .fast
        options.isNetworkAccessAllowed = true

        #if os(iOS)
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async { completion(image) }
        }
        #else
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { imageData, _, _, _ in
            var result: PlatformImage?
            if let imageData = imageData, let fullImage = PlatformImage(data: imageData) {
                if targetSize.width >= 800 || targetSize.height >= 800 {
                    result = fullImage
                } else {
                    result = fullImage.resized(to: targetSize)
                }
            }
            DispatchQueue.main.async { completion(result) }
        }
        #endif
    }
    
    var thumbnail: PlatformImage? {
        var result: PlatformImage?
        let semaphore = DispatchSemaphore(value: 0)
        getThumbnail { image in result = image; semaphore.signal() }
        _ = semaphore.wait(timeout: .now() + 0.5)
        return result
    }

    /// Small sync thumbnail for analysis (96×96). Faster and lighter than thumbnail.
    var analysisThumbnail: PlatformImage? {
        var result: PlatformImage?
        let semaphore = DispatchSemaphore(value: 0)
        getAnalysisThumbnail { image in result = image; semaphore.signal() }
        _ = semaphore.wait(timeout: .now() + 0.5)
        return result
    }
    
    var fileSize: Int64 {
        if let c = fileSizeCache { return c }
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.first?.value(forKey: "fileSize") as? Int64 ?? 0
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

struct PhotoAnalysis {
    var isDuplicate: Bool = false
    var isScreenshot: Bool = false
    var isBlurry: Bool = false
    var blurScore: Double = 0.0
    var duplicateGroup: String?
    
    var shouldDelete: Bool {
        isDuplicate || isScreenshot || isBlurry
    }
    
    var reason: String {
        var reasons: [String] = []
        if isDuplicate { reasons.append("Duplicate") }
        if isScreenshot { reasons.append("Screenshot") }
        if isBlurry { reasons.append("Blurry") }
        return reasons.joined(separator: ", ")
    }
    
    var points: Int {
        var total = 0
        if isDuplicate { total += 10 }
        if isScreenshot { total += 5 }
        if isBlurry { total += 15 }
        return total
    }
}
