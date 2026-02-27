import Foundation
import Photos
import CoreImage
import Vision

/// Duplicates must be taken on the same calendar day and within this many seconds of each other.
private let duplicateTimeWindowSeconds: TimeInterval = 300 // 5 minutes
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

class PhotoAnalyzer {
    private var duplicateGroups: [String: [String]] = [:]
    private let duplicateGroupsLock = NSLock()

    func clearDuplicateGroups() {
        duplicateGroupsLock.lock()
        defer { duplicateGroupsLock.unlock() }
        duplicateGroups.removeAll(keepingCapacity: false)
    }

    /// Registers photo in duplicate groups by hash. Call for every photo (including cached) so markDuplicates can find peers. Returns raw hash or nil.
    func registerPhotoForDuplicates(photo: PhotoItem) -> String? {
        guard let image = photo.analysisThumbnail else { return nil }
        let full = createSimpleHash(image: image)
        let hash = full.contains("|") ? String(full.split(separator: "|").first ?? Substring(full)) : full
        duplicateGroupsLock.lock()
        defer { duplicateGroupsLock.unlock() }
        if duplicateGroups[hash] == nil { duplicateGroups[hash] = [] }
        if !duplicateGroups[hash]!.contains(photo.id) { duplicateGroups[hash]!.append(photo.id) }
        return hash
    }

    func analyze(photo: PhotoItem, screenshotAssetIds: Set<String> = []) -> PhotoAnalysis {
        var analysis = PhotoAnalysis()
        
        guard let image = photo.analysisThumbnail else {
            analysis.isScreenshot = isScreenshot(asset: photo.asset, inScreenshotAlbum: screenshotAssetIds)
            return analysis
        }
        
        analysis.isScreenshot = isScreenshot(asset: photo.asset, inScreenshotAlbum: screenshotAssetIds)
        
        let blurResult = detectBlur(image: image)
        analysis.isBlurry = blurResult.isBlurry
        analysis.blurScore = blurResult.score
        
        let duplicateGroup = findDuplicateGroup(photo: photo, image: image)
        analysis.duplicateGroup = duplicateGroup
        
        return analysis
    }
    
    func markDuplicates(photos: [PhotoItem], analyses: inout [PhotoAnalysis]) {
        var groupMap: [String: [Int]] = [:]
        
        duplicateGroupsLock.lock()
        defer { duplicateGroupsLock.unlock() }
        
        for (index, analysis) in analyses.enumerated() {
            guard let groupHash = analysis.duplicateGroup else { continue }
            let count = duplicateGroups[groupHash]?.count ?? 0
            if count <= 1 {
                analyses[index].duplicateGroup = nil
                continue
            }
            if groupMap[groupHash] == nil { groupMap[groupHash] = [] }
            groupMap[groupHash]?.append(index)
        }
        
        let cal = Calendar.current
        
        for (hash, indices) in groupMap {
            // (index, creationDate) sorted by date
            let withDates: [(Int, Date)] = indices.map { i in
                (i, photos[i].asset.creationDate ?? .distantPast)
            }.sorted { $0.1 < $1.1 }
            
            // Cluster by same calendar day + within duplicateTimeWindowSeconds (e.g. 5 min)
            var clusters: [[(Int, Date)]] = []
            var current: [(Int, Date)] = []
            
            for pair in withDates {
                let (_, date) = pair
                if let first = current.first {
                    let firstDate = first.1
                    let sameDay = cal.isDate(date, inSameDayAs: firstDate)
                    let withinWindow = abs(date.timeIntervalSince(firstDate)) <= duplicateTimeWindowSeconds
                    if sameDay, withinWindow {
                        current.append(pair)
                    } else {
                        if current.count > 1 { clusters.append(current) }
                        current = [pair]
                    }
                } else {
                    current = [pair]
                }
            }
            if current.count > 1 { clusters.append(current) }
            
            for cluster in clusters {
                let sortedIndices = cluster.map(\.0)
                let dayId = cal.startOfDay(for: cluster[0].1).timeIntervalSince1970
                let bucket = Int(cluster[0].1.timeIntervalSince1970 / duplicateTimeWindowSeconds)
                let compositeId = "\(hash)_\(Int(dayId))_\(bucket)"
                
                for (_, index) in sortedIndices.enumerated() {
                    analyses[index].duplicateGroup = compositeId
                    analyses[index].isDuplicate = true
                }
            }
            
            // Clear duplicateGroup for indices that weren't placed in any multi-photo cluster
            let inCluster = Set(clusters.flatMap { $0.map(\.0) })
            for idx in indices where !inCluster.contains(idx) {
                analyses[idx].duplicateGroup = nil
            }
        }
    }
    
    func isScreenshot(asset: PHAsset, inScreenshotAlbum: Set<String> = []) -> Bool {
        // 1. In Screenshots album (smart album or folder named "Screenshots") — most reliable
        if inScreenshotAlbum.contains(asset.localIdentifier) {
            return true
        }
        
        // 2. System screenshot subtype (iOS/macOS marks screenshots when taken)
        if asset.mediaSubtypes.contains(.photoScreenshot) {
            return true
        }
        
        // 3. Filename explicitly contains "screenshot" or "screen shot" only (no aspect-ratio or other heuristics)
        let resources = PHAssetResource.assetResources(for: asset)
        for resource in resources {
            let lower = resource.originalFilename.lowercased()
            if lower.contains("screenshot") || lower.contains("screen shot") {
                return true
            }
        }
        
        return false
    }
    
    private func detectBlur(image: PlatformImage) -> (isBlurry: Bool, score: Double) {
        guard let cgImage = image.cgImageForAnalysis else {
            return (false, 0.0)
        }
        
        let variance = calculateLaplacianVariance(cgImage: cgImage)
        // Lower variance = blurrier. Use higher threshold to catch more blurry photos.
        // Sharp images often 500–3000+; blurry < 200–400.
        let isBlurry = variance < 400
        let normalizedScore = min(1.0, variance / 800.0)
        
        return (isBlurry, normalizedScore)
    }
    
    /// Laplacian variance: grayscale → Laplacian kernel → variance of result.
    private func calculateLaplacianVariance(cgImage: CGImage) -> Double {
        let w = cgImage.width
        let h = cgImage.height
        guard let provider = cgImage.dataProvider,
              let data = provider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0.0
        }
        
        let len = CFDataGetLength(data)
        let bytesPerPixel = 4
        let step = 4
        
        var lapValues: [Double] = []
        lapValues.reserveCapacity((w / step) * (h / step))
        
        for y in stride(from: 1, to: h - 1, by: step) {
            for x in stride(from: 1, to: w - 1, by: step) {
                let i = (y * w + x) * bytesPerPixel
                guard i + bytesPerPixel * 2 < len else { continue }
                
                func g(_ dy: Int, _ dx: Int) -> Double {
                    let j = ((y + dy) * w + (x + dx)) * bytesPerPixel
                    let r = Double(bytes[j])
                    let g = Double(bytes[j + 1])
                    let b = Double(bytes[j + 2])
                    return (r + g + b) / 3.0
                }
                
                // 3x3 Laplacian kernel (center -4, neighbors +1)
                let center = g(0, 0)
                let n = g(-1, 0) + g(1, 0) + g(0, -1) + g(0, 1)
                let lap = abs(4 * center - n)
                lapValues.append(lap)
            }
        }
        
        guard !lapValues.isEmpty else { return 0.0 }
        
        let mean = lapValues.reduce(0, +) / Double(lapValues.count)
        let variance = lapValues.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(lapValues.count)
        return variance
    }
    
    private func findDuplicateGroup(photo: PhotoItem, image: PlatformImage) -> String? {
        let full = createSimpleHash(image: image)
        let hash = full.contains("|") ? String(full.split(separator: "|").first ?? Substring(full)) : full
        
        duplicateGroupsLock.lock()
        defer { duplicateGroupsLock.unlock() }
        
        if duplicateGroups[hash] == nil {
            duplicateGroups[hash] = []
        }
        if !duplicateGroups[hash]!.contains(photo.id) {
            duplicateGroups[hash]!.append(photo.id)
        }
        
        return hash
    }
    
    private func createSimpleHash(image: PlatformImage) -> String {
        // Coarser 4x4 grid + heavy quantization so more images match (fuzzy duplicates)
        let size = CGSize(width: 16, height: 16)
        guard let resized = image.resized(to: size),
              let cgImage = resized.cgImageForAnalysis else {
            return UUID().uuidString
        }
        
        let width = cgImage.width
        let height = cgImage.height
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return UUID().uuidString
        }
        
        var grid: [Int] = []
        let stepX = max(1, width / 4)
        let stepY = max(1, height / 4)
        
        for y in stride(from: 0, to: height, by: stepY) {
            for x in stride(from: 0, to: width, by: stepX) {
                let i = (y * width + x) * 4
                if i + 2 < CFDataGetLength(data) {
                    let avg = (Int(bytes[i]) + Int(bytes[i + 1]) + Int(bytes[i + 2])) / 3
                    grid.append(avg / 64)
                }
            }
        }
        
        // dHash-style: compare each cell to previous, store 0/1; then use coarse string
        var hash = ""
        for (idx, v) in grid.enumerated() {
            let prev = idx > 0 ? grid[idx - 1] : v
            hash += v == prev ? "0" : "1"
        }
        // Also append coarse fingerprint so similar images cluster
        let coarse = grid.map { String($0) }.joined()
        return coarse + "|" + hash
    }
}
