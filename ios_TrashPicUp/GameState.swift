import SwiftUI
import Combine

/// Duration for cleanup goals (day / week / month).
enum GoalDuration: String, CaseIterable, Codable {
    case day
    case week
    case month
    
    var displayName: String { rawValue.capitalized }
}

/// Whether the goal is measured by number of photos or amount of space.
enum GoalMetric: String, CaseIterable, Codable {
    case photos
    case space
    
    var displayName: String {
        switch self {
        case .photos: return "Number of photos"
        case .space: return "Space to clear"
        }
    }
}

class GameState: ObservableObject {
    private static let keptPhotoIdsKey = "TrashPicUp.keptPhotoIds"
    private static let scoreKey = "TrashPicUp.score"
    private static let levelKey = "TrashPicUp.level"
    private static let photosDeletedKey = "TrashPicUp.photosDeleted"
    private static let spaceFreedKey = "TrashPicUp.spaceFreed"
    private static let streakKey = "TrashPicUp.streak"
    private static let bestStreakKey = "TrashPicUp.bestStreak"
    private static let goalByPhotosKey = "TrashPicUp.goalByPhotos"
    private static let goalTargetPhotosKey = "TrashPicUp.goalTargetPhotos"
    private static let goalTargetBytesKey = "TrashPicUp.goalTargetBytes"
    private static let goalDurationKey = "TrashPicUp.goalDuration"
    private static let goalPeriodStartKey = "TrashPicUp.goalPeriodStart"
    private static let photosDeletedAtPeriodStartKey = "TrashPicUp.photosDeletedAtPeriodStart"
    private static let spaceFreedAtPeriodStartKey = "TrashPicUp.spaceFreedAtPeriodStart"
    
    @Published var score: Int = 0
    @Published var level: Int = 1
    @Published var photosDeleted: Int = 0
    @Published var spaceFreed: Int64 = 0
    @Published var streak: Int = 0
    @Published var bestStreak: Int = 0
    @Published var keptPhotoIds: Set<String> = [] {
        didSet { saveKeptPhotoIds() }
    }
    
    // MARK: - Goals (default: 100 photos per month)
    @Published var goalByPhotos: Bool = true {
        didSet { saveGoals() }
    }
    @Published var goalTargetPhotos: Int = 100 {
        didSet { saveGoals() }
    }
    @Published var goalTargetBytes: Int64 = 1_073_741_824 {
        didSet { saveGoals() }
    }
    @Published var goalDuration: GoalDuration = .month {
        didSet { saveGoals() }
    }
    @Published var goalPeriodStartDate: Date = Date()
    @Published var photosDeletedAtPeriodStart: Int = 0
    @Published var spaceFreedAtPeriodStart: Int64 = 0
    
    private let calendar = Calendar.current
    
    init() {
        let d = UserDefaults.standard
        keptPhotoIds = Set(d.stringArray(forKey: Self.keptPhotoIdsKey) ?? [])
        score = d.integer(forKey: Self.scoreKey)
        level = max(1, d.integer(forKey: Self.levelKey))
        photosDeleted = d.integer(forKey: Self.photosDeletedKey)
        spaceFreed = Int64(d.integer(forKey: Self.spaceFreedKey))
        streak = d.integer(forKey: Self.streakKey)
        bestStreak = d.integer(forKey: Self.bestStreakKey)
        goalByPhotos = d.object(forKey: Self.goalByPhotosKey) as? Bool ?? true
        goalTargetPhotos = max(1, d.integer(forKey: Self.goalTargetPhotosKey))
        if goalTargetPhotos == 1 && d.object(forKey: Self.goalTargetPhotosKey) == nil {
            goalTargetPhotos = 100
        }
        goalTargetBytes = Int64(d.integer(forKey: Self.goalTargetBytesKey))
        if goalTargetBytes == 0 { goalTargetBytes = 1_073_741_824 }
        if let raw = d.string(forKey: Self.goalDurationKey),
           let dur = GoalDuration(rawValue: raw) {
            goalDuration = dur
        }
        goalPeriodStartDate = d.object(forKey: Self.goalPeriodStartKey) as? Date ?? Date()
        photosDeletedAtPeriodStart = d.integer(forKey: Self.photosDeletedAtPeriodStartKey)
        spaceFreedAtPeriodStart = Int64(d.integer(forKey: Self.spaceFreedAtPeriodStartKey))
    }
    
    private func saveKeptPhotoIds() {
        UserDefaults.standard.set(Array(keptPhotoIds), forKey: Self.keptPhotoIdsKey)
    }
    
    private func saveStats() {
        let d = UserDefaults.standard
        d.set(score, forKey: Self.scoreKey)
        d.set(level, forKey: Self.levelKey)
        d.set(photosDeleted, forKey: Self.photosDeletedKey)
        d.set(Int(spaceFreed), forKey: Self.spaceFreedKey)
        d.set(streak, forKey: Self.streakKey)
        d.set(bestStreak, forKey: Self.bestStreakKey)
    }
    
    private func saveGoals() {
        let d = UserDefaults.standard
        d.set(goalByPhotos, forKey: Self.goalByPhotosKey)
        d.set(goalTargetPhotos, forKey: Self.goalTargetPhotosKey)
        d.set(Int(goalTargetBytes), forKey: Self.goalTargetBytesKey)
        d.set(goalDuration.rawValue, forKey: Self.goalDurationKey)
        d.set(goalPeriodStartDate, forKey: Self.goalPeriodStartKey)
        d.set(photosDeletedAtPeriodStart, forKey: Self.photosDeletedAtPeriodStartKey)
        d.set(Int(spaceFreedAtPeriodStart), forKey: Self.spaceFreedAtPeriodStartKey)
    }
    
    func refreshGoalPeriodIfNeeded() {
        let now = Date()
        let currentPeriodStart = startOfCurrentPeriod(from: now)
        let storedPeriodStart = startOfCurrentPeriod(from: goalPeriodStartDate)
        if currentPeriodStart != storedPeriodStart {
            goalPeriodStartDate = currentPeriodStart
            photosDeletedAtPeriodStart = photosDeleted
            spaceFreedAtPeriodStart = spaceFreed
            saveGoals()
        }
    }
    
    private func startOfCurrentPeriod(from date: Date) -> Date {
        switch goalDuration {
        case .day: return calendar.startOfDay(for: date)
        case .week: return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        case .month: return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        }
    }
    
    var goalProgressPhotos: Int {
        max(0, photosDeleted - photosDeletedAtPeriodStart)
    }
    
    var goalProgressBytes: Int64 {
        max(0, spaceFreed - spaceFreedAtPeriodStart)
    }
    
    var goalProgressFraction: Double {
        if goalByPhotos {
            guard goalTargetPhotos > 0 else { return 0 }
            return Double(goalProgressPhotos) / Double(goalTargetPhotos)
        } else {
            guard goalTargetBytes > 0 else { return 0 }
            return Double(goalProgressBytes) / Double(goalTargetBytes)
        }
    }
    
    var goalProgressDescription: String {
        let periodLabel: String
        switch goalDuration {
        case .day: periodLabel = "today"
        case .week: periodLabel = "this week"
        case .month: periodLabel = "this month"
        }
        if goalByPhotos {
            return "\(goalProgressPhotos) / \(goalTargetPhotos) photos \(periodLabel)"
        } else {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB]
            formatter.countStyle = .file
            let progressStr = formatter.string(fromByteCount: goalProgressBytes)
            let targetStr = formatter.string(fromByteCount: goalTargetBytes)
            return "\(progressStr) / \(targetStr) \(periodLabel)"
        }
    }
    
    @Published var deletedPhotos: [PhotoItem] = []
    
    private let scorePerLevel = 100
    
    func addPoints(_ points: Int) {
        score += points
        checkLevelUp()
    }
    
    func deletePhoto(_ photo: PhotoItem) {
        deletePhoto(photo, fileSize: photo.fileSize)
    }

    func deletePhoto(_ photo: PhotoItem, fileSize: Int64) {
        photosDeleted += 1
        spaceFreed += fileSize

        if let analysis = photo.analysis {
            addPoints(analysis.points)
            streak += 1
            if streak > bestStreak {
                bestStreak = streak
            }
        }

        deletedPhotos.append(photo)
        saveStats()
    }
    
    func undoLastDelete() {
        guard let lastPhoto = deletedPhotos.popLast() else { return }
        
        photosDeleted = max(0, photosDeleted - 1)
        spaceFreed = max(0, spaceFreed - lastPhoto.fileSize)
        
        if let analysis = lastPhoto.analysis {
            score = max(0, score - analysis.points)
        }
        
        streak = max(0, streak - 1)
        saveStats()
    }
    
    private func checkLevelUp() {
        let newLevel = (score / scorePerLevel) + 1
        if newLevel > level {
            level = newLevel
        }
    }
    
    var formattedSpaceFreed: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: spaceFreed)
    }
    
    func addKeptPhotoIds(_ ids: Set<String>) {
        keptPhotoIds.formUnion(ids)
        saveKeptPhotoIds()
    }

    func reset() {
        score = 0
        level = 1
        photosDeleted = 0
        spaceFreed = 0
        streak = 0
        deletedPhotos = []
        keptPhotoIds = []
        goalPeriodStartDate = Date()
        photosDeletedAtPeriodStart = 0
        spaceFreedAtPeriodStart = 0
        saveStats()
        saveGoals()
    }
}
