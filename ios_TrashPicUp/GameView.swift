import SwiftUI
import Photos
import CoreLocation
import Combine
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

struct GameView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var photoManager: PhotoManager
    @State private var activeFilters: Set<PhotoFilter> = []
    @State private var sortOrder: SortOrder = .newest
    @State private var currentIndex: Int = 0
    @State private var showingFullScreen: PhotoItem?
    @State private var pendingDeletes: [PhotoItem] = []
    @State private var showCelebration = false
    #if os(iOS)
    @State private var showingStats = false
    #endif

    enum PhotoFilter: String, CaseIterable, Hashable {
        case all = "All Photos"
        case screenshots = "Screenshots"
        case blurry = "Blurry"
        case duplicates = "Duplicates"
        static var filterableCases: [PhotoFilter] { [.screenshots, .blurry, .duplicates] }
    }

    enum SortOrder: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case largest = "Largest First"
        case smallest = "Smallest First"
    }

    var filteredPhotos: [PhotoItem] {
        var photos = photoManager.photos
        if !activeFilters.isEmpty {
            photos = photos.filter { p in
                (activeFilters.contains(.screenshots) && (p.analysis?.isScreenshot == true))
                || (activeFilters.contains(.blurry) && (p.analysis?.isBlurry == true))
                || (activeFilters.contains(.duplicates) && (p.analysis?.isDuplicate == true))
            }
        }
        switch sortOrder {
        case .newest: photos.sort { ($0.asset.creationDate ?? .distantPast) > ($1.asset.creationDate ?? .distantPast) }
        case .oldest: photos.sort { ($0.asset.creationDate ?? .distantPast) < ($1.asset.creationDate ?? .distantPast) }
        case .largest: photos.sort { $0.fileSize > $1.fileSize }
        case .smallest: photos.sort { $0.fileSize < $1.fileSize }
        }
        return photos
    }

    var displayedPhotos: [PhotoItem] {
        let pendingIds = Set(pendingDeletes.map(\.id))
        return filteredPhotos.filter { p in
            !pendingIds.contains(p.id) && !gameState.keptPhotoIds.contains(p.id)
        }
    }

    var currentPhoto: PhotoItem? {
        let list = displayedPhotos
        guard currentIndex >= 0, currentIndex < list.count else { return nil }
        return list[currentIndex]
    }

    var body: some View {
        Group {
            #if os(iOS)
            NavigationView {
                mainContent
                    .navigationBarHidden(true)
                    .sheet(isPresented: $showingStats) { mobileStatsView }
            }
            .navigationViewStyle(.stack)
            #else
            HSplitView {
                sidebar
                mainContent
            }
            #endif
        }
        .background(TrashPicUpTheme.backgroundGradient)
        .modifier(FullScreenPhotoModifier(
            showingFullScreen: $showingFullScreen,
            allPhotos: photoManager.photos,
            pendingDeletes: $pendingDeletes,
            onAddToPending: { batch in
                pendingDeletes.append(contentsOf: batch)
            },
            onKeep: { ids in
                gameState.addKeptPhotoIds(ids)
            },
            onDismissAndAdvance: {
                showingFullScreen = nil
                keepCurrent()
            }
        ))
    }

    // MARK: - Main content (Tinder-style card)

    private var mainContent: some View {
        ZStack {
            TrashPicUpTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                titleBar
                toolbarRow
                ZStack {
                    if let photo = currentPhoto {
                        TinderCardView(
                            photo: photo,
                            onKeep: { SoundManager.playKeep(); keepCurrent() },
                            onDelete: { SoundManager.playDelete(); deleteCurrent(photo) },
                            onTapPhoto: { showingFullScreen = photo }
                        )
                        .id(photo.id)
                    } else {
                        emptyState
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                if currentPhoto != nil || !pendingDeletes.isEmpty {
                    bottomBar
                }
            }
            .overlay {
                if showCelebration {
                    ConfettiView(duration: SoundManager.celebrationDuration) { showCelebration = false }
                        .ignoresSafeArea()
                }
            }
        }
    }

    private var titleBar: some View {
        HStack(spacing: 10) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text("Trash Pic Up")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(TrashPicUpTheme.accentMagenta)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
    }

    private var toolbarRow: some View {
        HStack {
            #if os(iOS)
            Button { showingStats = true } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundStyle(TrashPicUpTheme.accentMagenta)
            }
            .buttonStyle(.plain)
            #endif
            if photoManager.isLoading {
                ProgressView().scaleEffect(0.8)
                    .tint(TrashPicUpTheme.accentMagenta)
            } else if photoManager.isAnalyzing {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: photoManager.analysisProgress)
                        .frame(width: 80)
                        .tint(TrashPicUpTheme.accentCyan)
                    Text("Analyzing... \(Int(photoManager.analysisProgress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(TrashPicUpTheme.textSecondary)
                }
            }
            Spacer()
            Text("\(max(0, displayedPhotos.count - currentIndex)) Photos")
                .font(.subheadline)
                .foregroundStyle(TrashPicUpTheme.textSecondary)
            Menu {
                Section("Filters") {
                    ForEach(PhotoFilter.filterableCases, id: \.self) { f in
                        Toggle(isOn: Binding(
                            get: { activeFilters.contains(f) },
                            set: { if $0 { activeFilters.insert(f) } else { activeFilters.remove(f) } }
                        )) {
                            HStack(spacing: 6) {
                                Circle().fill(chipColor(for: f)).frame(width: 8, height: 8)
                                Text(f.rawValue)
                            }
                        }
                    }
                }
                Section("Sort") {
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundStyle(TrashPicUpTheme.accentCyan)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.92))
    }

    private func chipColor(for f: PhotoFilter) -> Color {
        switch f {
        case .screenshots: return TrashPicUpTheme.accentMagenta
        case .blurry: return TrashPicUpTheme.accentOrange
        case .duplicates: return TrashPicUpTheme.accentCyan
        case .all: return TrashPicUpTheme.accentCyan
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: filteredPhotos.isEmpty ? "photo.on.rectangle.angled" : "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(TrashPicUpTheme.accentCyan.opacity(0.8))
            Text(filteredPhotos.isEmpty ? "No photos to review" : "All done!")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(TrashPicUpTheme.textPrimary)
                .shadow(color: TrashPicUpTheme.textShadowColor, radius: 0.5, x: 0, y: 1)
            Text(filteredPhotos.isEmpty ? "Add photos or change filters." : "You’ve reviewed all photos in this set.")
                .font(.subheadline)
                .foregroundStyle(TrashPicUpTheme.textSecondary)
                .multilineTextAlignment(.center)
                .shadow(color: TrashPicUpTheme.textShadowColor, radius: 0.5, x: 0, y: 1)
        }
        .padding(40)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if currentPhoto != nil {
                HStack {
                    Button {
                        if let p = currentPhoto { addToPendingAndAdvance(p) }
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(TrashPicUpTheme.deleteRed)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        keepCurrent()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(TrashPicUpTheme.keepGreen)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }

            if !pendingDeletes.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        confirmDeleteBatch()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.circle.fill")
                                .font(.subheadline)
                            Text("Delete \(pendingDeletes.count) from library")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(TrashPicUpTheme.accentCyan)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
                .padding(.top, currentPhoto != nil ? 0 : 12)
            }
        }
        .background(TrashPicUpTheme.cardBackground)
    }

    private func keepCurrent() {
        guard let p = currentPhoto else { return }
        gameState.addKeptPhotoIds([p.id])
        withAnimation(.easeOut(duration: 0.2)) {
            currentIndex = min(currentIndex, max(0, displayedPhotos.count - 1))
        }
    }

    private func addToPendingAndAdvance(_ photo: PhotoItem) {
        pendingDeletes.append(photo)
        withAnimation(.easeOut(duration: 0.2)) {
            currentIndex = min(currentIndex, max(0, displayedPhotos.count - 1))
        }
    }

    private func deleteCurrent(_ photo: PhotoItem) {
        addToPendingAndAdvance(photo)
    }

    private func confirmDeleteBatch() {
        guard !pendingDeletes.isEmpty else { return }
        let batch = pendingDeletes
        let sizes = batch.map { ($0, $0.fileSize) }
        photoManager.deletePhotos(batch) { [self] success, _ in
            if success {
                pendingDeletes.removeAll()
                for (photo, size) in sizes {
                    gameState.deletePhoto(photo, fileSize: size)
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    currentIndex = min(currentIndex, max(0, displayedPhotos.count - 1))
                }
                SoundManager.playCelebration()
                showCelebration = true
            }
        }
    }

    // MARK: - Stats / sidebar

    #if os(iOS)
    private var mobileStatsView: some View {
        NavigationView {
            statsContent
                .navigationTitle("Stats & Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { showingStats = false }
                            .foregroundStyle(TrashPicUpTheme.accentMagenta)
                    }
                }
        }
    }
    #endif

    #if os(macOS)
    private var sidebar: some View {
        statsContent
            .frame(width: 260)
            .padding()
    }
    #endif

    private var statsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Stats")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(TrashPicUpTheme.textPrimary)
                    StatRow(label: "Score", value: "\(gameState.score)")
                    StatRow(label: "Level", value: "\(gameState.level)")
                    StatRow(label: "Photos Deleted", value: "\(gameState.photosDeleted)")
                    StatRow(label: "Space Freed", value: gameState.formattedSpaceFreed)
                    StatRow(label: "Streak", value: "\(gameState.streak)")
                    StatRow(label: "Best Streak", value: "\(gameState.bestStreak)")
                }
                .padding()
                .background(TrashPicUpTheme.cardBackground)
                .cornerRadius(12)

                // Goals card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Goals")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(TrashPicUpTheme.textPrimary)
                    Text("Set how much you want to clear and how often.")
                        .font(.caption)
                        .foregroundStyle(TrashPicUpTheme.textSecondary)
                    goalMetricPicker
                    if gameState.goalByPhotos {
                        goalPhotosStepper
                    } else {
                        goalSpacePicker
                    }
                    goalDurationPicker
                    goalProgressView
                }
                .padding()
                .background(TrashPicUpTheme.cardBackground)
                .cornerRadius(12)
                .onAppear { gameState.refreshGoalPeriodIfNeeded() }

                #if os(iOS)
                if photoManager.authorizationStatus == .limited {
                    Text("You're viewing selected photos only. Use \"Open Photo Settings\" to add more or switch to All Photos.")
                        .font(.caption)
                        .foregroundStyle(TrashPicUpTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Button("Open Photo Settings") { photoManager.openPhotoSettings() }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(TrashPicUpTheme.accentMagenta)
                        .cornerRadius(10)
                        .buttonStyle(.plain)
                }
                #endif
                Button("Refresh Photos") { photoManager.refreshPhotos() }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(TrashPicUpTheme.accentCyan)
                    .cornerRadius(10)
                    .buttonStyle(.plain)
                Text("Showing newest 3,000 photos to keep the app responsive.")
                    .font(.caption2)
                    .foregroundStyle(TrashPicUpTheme.textSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    Button("Reset App") {
                        gameState.reset()
                        pendingDeletes = []
                        currentIndex = 0
                        #if os(iOS)
                        showingStats = false
                        #endif
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(TrashPicUpTheme.accentOrange)
                    .cornerRadius(10)
                    .buttonStyle(.plain)
                    Text("Clears your kept-photos list and resets stats. Previously kept photos will re-enter the rotation.")
                        .font(.caption2)
                        .foregroundStyle(TrashPicUpTheme.textSecondary)
                }
            }
            .padding()
        }
        .background(TrashPicUpTheme.backgroundGradient)
    }

    // MARK: - Goal subviews
    private var goalMetricPicker: some View {
        HStack {
            Text("Goal by")
                .foregroundStyle(TrashPicUpTheme.textSecondary)
            Picker("Goal by", selection: Binding(
                get: { gameState.goalByPhotos },
                set: { gameState.goalByPhotos = $0 }
            )) {
                Text("Photos").tag(true)
                Text("Space").tag(false)
            }
            .pickerStyle(.segmented)
        }
    }

    private var goalPhotosStepper: some View {
        HStack {
            Text("Target")
                .foregroundStyle(TrashPicUpTheme.textSecondary)
            Stepper(value: Binding(
                get: { gameState.goalTargetPhotos },
                set: { gameState.goalTargetPhotos = max(1, $0) }
            ), in: 1...10_000, step: 10) {
                Text("\(gameState.goalTargetPhotos) photos")
                    .fontWeight(.medium)
                    .foregroundStyle(TrashPicUpTheme.textPrimary)
            }
        }
    }

    private var goalSpacePicker: some View {
        let options: [(String, Int64)] = [
            ("500 MB", 500 * 1_024 * 1_024),
            ("1 GB", 1_073_741_824),
            ("2 GB", 2 * 1_073_741_824),
            ("5 GB", 5 * 1_073_741_824),
            ("10 GB", 10 * 1_073_741_824)
        ]
        return Picker("Space target", selection: Binding(
            get: { gameState.goalTargetBytes },
            set: { gameState.goalTargetBytes = $0 }
        )) {
            ForEach(options, id: \.1) { label, bytes in
                Text(label).tag(bytes)
            }
        }
        .pickerStyle(.menu)
    }

    private var goalDurationPicker: some View {
        HStack {
            Text("Duration")
                .foregroundStyle(TrashPicUpTheme.textSecondary)
            Picker("Duration", selection: $gameState.goalDuration) {
                ForEach(GoalDuration.allCases, id: \.self) { duration in
                    Text(duration.displayName).tag(duration)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var goalProgressView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(gameState.goalProgressDescription)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(TrashPicUpTheme.textPrimary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(TrashPicUpTheme.textSecondary.opacity(0.2))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(TrashPicUpTheme.accentCyan)
                        .frame(width: min(CGFloat(gameState.goalProgressFraction) * geo.size.width, geo.size.width), height: 10)
                }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Tinder-style card

struct TinderCardView: View {
    let photo: PhotoItem
    let onKeep: () -> Void
    let onDelete: () -> Void
    let onTapPhoto: () -> Void

    @State private var image: PlatformImage?
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var loadingPhotoId: String = ""

    private let swipeThreshold: CGFloat = 120
    private let cardPadding: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let innerW = max(0, w - 2 * cardPadding)
            let innerH = max(0, h - 2 * cardPadding)
            let (cardW, cardH) = fittedCardSize(width: innerW, height: innerH)
            ZStack {
                cardContent(width: cardW, height: cardH)
                    .offset(x: dragOffset.width, y: dragOffset.height)
                    .rotation3DEffect(
                        .degrees(Double(dragOffset.width) / 20),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { g in
                                dragOffset = g.translation
                                isDragging = true
                            }
                            .onEnded { g in
                                let dx = g.translation.width
                                let dy = g.translation.height
                                if abs(dx) > abs(dy) {
                                    if dx < -swipeThreshold {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            dragOffset = .zero
                                        }
                                        onDelete()
                                    } else if dx > swipeThreshold {
                                        swipeAway(direction: 1, width: cardW) { onKeep() }
                                    } else {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            dragOffset = .zero
                                        }
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        dragOffset = .zero
                                    }
                                }
                                isDragging = false
                            }
                    )
                    .onTapGesture {
                        if !isDragging { onTapPhoto() }
                    }

                if isDragging {
                    HStack {
                        if dragOffset.width < -60 {
                            swipeLabel("DELETE", color: TrashPicUpTheme.deleteRed)
                                .opacity(min(1, -dragOffset.width / swipeThreshold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 32)
                        }
                        Spacer()
                        if dragOffset.width > 60 {
                            swipeLabel("KEEP", color: TrashPicUpTheme.keepGreen)
                                .opacity(min(1, dragOffset.width / swipeThreshold))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.trailing, 32)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { loadImage(size: CGSize(width: min(800, w * 2), height: min(800, h * 2))) }
            .onChange(of: photo.id) { _, _ in
                image = nil
                loadingPhotoId = photo.id
                loadImage(size: CGSize(width: min(800, w * 2), height: min(800, h * 2)))
            }
        }
    }

    private func fittedCardSize(width w: CGFloat, height h: CGFloat) -> (CGFloat, CGFloat) {
        guard let img = image, img.size.width > 0, img.size.height > 0 else { return (w, h) }
        guard w > 0, h > 0 else { return (w, h) }
        let aspect = img.size.width / img.size.height
        let containerAspect = w / h
        if aspect > containerAspect {
            return (w, w / aspect)
        } else {
            return (h * aspect, h)
        }
    }

    private func cardContent(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20)
                .fill(TrashPicUpTheme.cardBackground)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)

            if let img = image {
                platformImage(img)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .cornerRadius(20)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.secondary.opacity(0.2))
                    .overlay { ProgressView().scaleEffect(1.2) }
            }

            HStack(spacing: 6) {
                if photo.analysis?.isScreenshot == true {
                    Text("Screenshot")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(TrashPicUpTheme.accentMagenta)
                        .cornerRadius(8)
                }
                if photo.analysis?.isBlurry == true {
                    Text("Blurry")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(TrashPicUpTheme.accentOrange)
                        .cornerRadius(8)
                }
                if photo.analysis?.isDuplicate == true {
                    Text("Duplicate")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(TrashPicUpTheme.accentCyan)
                        .cornerRadius(8)
                }
            }
            .padding(12)
        }
        .frame(width: width, height: height)
    }

    @ViewBuilder
    private func platformImage(_ img: PlatformImage) -> some View {
        #if os(iOS)
        Image(uiImage: img)
            .resizable()
        #else
        Image(nsImage: img)
            .resizable()
        #endif
    }

    private func swipeLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(color)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 3)
            )
    }

    private func swipeAway(direction: Int, width: CGFloat, action: @escaping () -> Void) {
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = CGSize(width: CGFloat(direction) * (width + 100), height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            action()
            dragOffset = .zero
        }
    }

    private func loadImage(size: CGSize) {
        let requestedId = photo.id
        loadingPhotoId = requestedId
        photo.getImage(targetSize: size, deliveryMode: .highQualityFormat) { img in
            DispatchQueue.main.async {
                if loadingPhotoId == requestedId {
                    image = img
                }
            }
        }
    }
}

// MARK: - Full-screen photo (photo top, info below; scroll only when content overflows)

private struct FullScreenContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct FullScreenPhotoView: View {
    let photo: PhotoItem
    let allPhotos: [PhotoItem]
    @Binding var pendingDeletes: [PhotoItem]
    let onAddToPending: ([PhotoItem]) -> Void
    let onKeep: (Set<String>) -> Void
    let onDismiss: () -> Void
    let onDismissAndAdvance: () -> Void

    @State private var displayedPhoto: PhotoItem?
    @State private var image: PlatformImage?
    @State private var contentHeight: CGFloat = 0
    @State private var isDuplicateSelectMode: Bool = false
    @State private var selectedDuplicateIds: Set<String> = []
    @State private var keptDuplicateIds: Set<String> = []
    /// Reserve space so photo starts below the close (X) button.
    private let closeButtonTop: CGFloat = 24
    private let closeButtonHeight: CGFloat = 44
    private var photoStartPadding: CGFloat { closeButtonTop + closeButtonHeight + 12 }

    /// The photo shown in the main area (initial or last-tapped duplicate).
    private var activePhoto: PhotoItem { displayedPhoto ?? photo }

    private let duplicatePanelReservedHeight: CGFloat = 200

    var body: some View {
        GeometryReader { geo in
            let viewportHeight = geo.size.height
            let showScrollHint = contentHeight > viewportHeight + 1
            let group = duplicateGroupPhotos
            let hasDuplicates = !group.isEmpty
            let maxPhotoHeight: CGFloat? = hasDuplicates
                ? max(120, viewportHeight - photoStartPadding - duplicatePanelReservedHeight - 16)
                : nil

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    topExtensionView(width: geo.size.width, hasDuplicates: hasDuplicates)
                    photoSection(width: geo.size.width, showHint: showScrollHint, hasDuplicates: hasDuplicates, maxPhotoHeight: maxPhotoHeight)
                    duplicatePanel(width: geo.size.width)
                    fullScreenInfoSection
                }
                .background(
                    GeometryReader { g in
                        Color.clear.preference(key: FullScreenContentHeightKey.self, value: g.size.height)
                    }
                )
            }
            .onPreferenceChange(FullScreenContentHeightKey.self) { contentHeight = $0 }
            .background(TrashPicUpTheme.fullScreenInfoBg)
            .overlay(alignment: .topTrailing) {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(TrashPicUpTheme.fullScreenInfoText)
                        .symbolRenderingMode(.hierarchical)
                        .frame(minWidth: 56, minHeight: 56)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, closeButtonTop - 6)
                .padding(.trailing, 16)
                .padding(.bottom, 8)
                .padding(.leading, 16)
            }
        }
        .background(TrashPicUpTheme.fullScreenInfoBg)
        .onAppear {
            displayedPhoto = photo
            loadMainImage(for: photo, preserveCurrent: false)
        }
        .onChange(of: displayedPhoto?.id) { _, _ in
            loadMainImage(for: activePhoto, preserveCurrent: true)
        }
    }

    /// Load main image. When `preserveCurrent` is true, keep showing current image until new one loads (avoids scroll jump).
    private func loadMainImage(for p: PhotoItem, preserveCurrent: Bool = false) {
        let requestedId = p.id
        if !preserveCurrent { image = nil }
        let size = CGSize(width: 1600, height: 1600)
        p.getImage(targetSize: size, deliveryMode: .highQualityFormat) { img in
            DispatchQueue.main.async {
                guard activePhoto.id == requestedId else { return }
                image = img
            }
        }
    }

    /// Edge-aware extension: blurred ambient fills the band above the photo.
    private func topExtensionView(width: CGFloat, hasDuplicates: Bool) -> some View {
        Group {
            if let img = image {
                GeometryReader { g in
                    fullScreenPlatformImage(img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: g.size.width, height: max(g.size.height * 2, 200))
                        .frame(width: g.size.width, height: g.size.height, alignment: .top)
                        .clipped()
                        .blur(radius: 50)
                }
            } else {
                TrashPicUpTheme.fullScreenInfoBg
            }
        }
        .frame(height: photoStartPadding)
        .frame(maxWidth: .infinity)
    }

    private func fullScreenPlatformImage(_ img: PlatformImage) -> Image {
        #if os(iOS)
        return Image(uiImage: img)
        #else
        return Image(nsImage: img)
        #endif
    }

    private func platformImageSize(_ img: PlatformImage) -> CGSize {
        #if os(iOS)
        return (img as! UIImage).size
        #else
        return (img as! NSImage).size
        #endif
    }

    @ViewBuilder
    private func photoSection(width: CGFloat, showHint: Bool, hasDuplicates: Bool, maxPhotoHeight: CGFloat?) -> some View {
        if hasDuplicates, let cap = maxPhotoHeight {
            photoSectionCompact(width: width, showHint: showHint, maxHeight: cap)
        } else {
            photoSectionFullWidth(width: width, showHint: showHint)
        }
    }

    private func photoSectionFullWidth(width: CGFloat, showHint: Bool) -> some View {
        ZStack(alignment: .bottom) {
            TrashPicUpTheme.fullScreenInfoBg
            if let img = image {
                let imgSize = platformImageSize(img)
                let aspectHeight = imgSize.width > 0 ? width * (imgSize.height / imgSize.width) : width
                ZoomablePhotoView(image: img)
                    .id(activePhoto.id)
                    .frame(width: width, height: max(200, aspectHeight))
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(TrashPicUpTheme.fullScreenInfoText)
                    .frame(minHeight: 200)
            }
            if showHint {
                Text("Swipe up for info · Swipe down to return")
                    .font(.caption)
                    .foregroundStyle(TrashPicUpTheme.fullScreenInfoText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(8)
                    .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func photoSectionCompact(width: CGFloat, showHint: Bool, maxHeight: CGFloat) -> some View {
        ZStack {
            ambientBackground(width: width, height: maxHeight)
            if let img = image {
                ZoomablePhotoView(image: img)
                    .id(activePhoto.id)
                    .frame(width: width, height: maxHeight)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(TrashPicUpTheme.fullScreenInfoText)
                    .frame(minHeight: 120)
            }
            if showHint {
                VStack {
                    Spacer()
                    Text("Swipe up for info · Swipe down to return")
                        .font(.caption)
                        .foregroundStyle(TrashPicUpTheme.fullScreenInfoText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.35))
                        .cornerRadius(8)
                        .padding(.bottom, 24)
                }
            }
        }
        .frame(width: width, height: maxHeight)
        .frame(maxWidth: .infinity)
    }

    private func ambientBackground(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let img = image {
                fullScreenPlatformImage(img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .blur(radius: 50)
            } else {
                TrashPicUpTheme.fullScreenInfoBg
            }
        }
        .frame(width: width, height: height)
    }

    private var fullScreenInfoSection: some View {
        let p = activePhoto
        return VStack(alignment: .leading, spacing: 16) {
            Text("Photo info")
                .font(.headline)
                .foregroundStyle(TrashPicUpTheme.fullScreenInfoText)
            VStack(alignment: .leading, spacing: 12) {
                if let date = p.asset.creationDate {
                    fullScreenInfoRow(label: "Date taken") { Text(date, style: .date).foregroundStyle(TrashPicUpTheme.fullScreenInfoText) }
                }
                fullScreenInfoRow(label: "File size") { Text(p.formattedFileSize).foregroundStyle(TrashPicUpTheme.fullScreenInfoText) }
                fullScreenInfoRow(label: "Dimensions") { Text("\(p.asset.pixelWidth) × \(p.asset.pixelHeight)").foregroundStyle(TrashPicUpTheme.fullScreenInfoText) }
                if let loc = p.asset.location {
                    fullScreenInfoRow(label: "Location") {
                        Text(String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude))
                            .font(.caption)
                            .foregroundStyle(TrashPicUpTheme.fullScreenInfoText)
                    }
                } else {
                    fullScreenInfoRow(label: "Location") { Text("None").foregroundStyle(TrashPicUpTheme.fullScreenInfoText) }
                }
                if p.analysis?.isScreenshot == true || p.analysis?.isBlurry == true || p.analysis?.isDuplicate == true {
                    fullScreenInfoRow(label: "Type") {
                        HStack(spacing: 4) {
                            if p.analysis?.isScreenshot == true {
                                Text("Screenshot").foregroundStyle(TrashPicUpTheme.accentMagenta)
                            }
                            if p.analysis?.isScreenshot == true, (p.analysis?.isBlurry == true || p.analysis?.isDuplicate == true) { Text(",").foregroundStyle(TrashPicUpTheme.fullScreenInfoLabel) }
                            if p.analysis?.isBlurry == true {
                                Text("Blurry").foregroundStyle(TrashPicUpTheme.accentOrange)
                            }
                            if p.analysis?.isBlurry == true, p.analysis?.isDuplicate == true { Text(",").foregroundStyle(TrashPicUpTheme.fullScreenInfoLabel) }
                            if p.analysis?.isDuplicate == true {
                                Text("Duplicate").foregroundStyle(TrashPicUpTheme.accentCyan)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(TrashPicUpTheme.fullScreenInfoBg)
    }

    @ViewBuilder
    private func fullScreenInfoRow<V: View>(label: String, @ViewBuilder value: () -> V) -> some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.subheadline)
                .foregroundStyle(TrashPicUpTheme.fullScreenInfoLabel)
            Spacer(minLength: 12)
            value()
                .font(.subheadline)
        }
    }

    /// All photos in the duplicate group (including current), excluding pending/kept, sorted by date.
    /// Uses activePhoto for lookup. Fallback: match by raw hash prefix if exact composite finds none.
    private var duplicateGroupPhotos: [PhotoItem] {
        let anchor = activePhoto
        guard let g = anchor.analysis?.duplicateGroup else { return [] }
        let pendingIds = Set(pendingDeletes.map(\.id))
        var list = allPhotos.filter {
            $0.analysis?.duplicateGroup == g
            && !pendingIds.contains($0.id)
            && !keptDuplicateIds.contains($0.id)
        }
        if list.isEmpty, g.contains("_") {
            let hashPrefix = String(g.split(separator: "_").first ?? Substring(g))
            list = allPhotos.filter {
                guard let dg = $0.analysis?.duplicateGroup else { return false }
                if dg == hashPrefix { return true }
                if dg.contains("_"), dg.hasPrefix(hashPrefix + "_") { return true }
                return false
            }
            .filter { !pendingIds.contains($0.id) && !keptDuplicateIds.contains($0.id) }
        }
        return list.sorted { ($0.asset.creationDate ?? .distantPast) < ($1.asset.creationDate ?? .distantPast) }
    }

    @ViewBuilder
    private func duplicatePanel(width: CGFloat) -> some View {
        let group = duplicateGroupPhotos
        if !group.isEmpty {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duplicates")
                        .font(.headline)
                        .foregroundStyle(TrashPicUpTheme.fullScreenInfoText)
                    if group.count == 1 {
                        Text("No other duplicates in this set")
                            .font(.caption)
                            .foregroundStyle(TrashPicUpTheme.fullScreenInfoLabel)
                    }
                }
                Spacer()
                if isDuplicateSelectMode {
                    if !selectedDuplicateIds.isEmpty {
                        Button("Delete \(selectedDuplicateIds.count)") {
                            let toDelete = group.filter { selectedDuplicateIds.contains($0.id) }
                            let actedOnAll = selectedDuplicateIds.count == group.count
                            onAddToPending(toDelete)
                            selectedDuplicateIds.removeAll()
                            if actedOnAll { onDismissAndAdvance() }
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(TrashPicUpTheme.deleteRed)
                        .cornerRadius(8)
                        Button("Keep \(selectedDuplicateIds.count)") {
                            let toKeep = selectedDuplicateIds
                            let actedOnAll = toKeep.count == group.count
                            onKeep(toKeep)
                            keptDuplicateIds.formUnion(toKeep)
                            selectedDuplicateIds.removeAll()
                            if actedOnAll { onDismissAndAdvance() }
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(TrashPicUpTheme.keepGreen)
                        .cornerRadius(8)
                    }
                    Button("Cancel") {
                        isDuplicateSelectMode = false
                        selectedDuplicateIds.removeAll()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(TrashPicUpTheme.fullScreenInfoText)
                } else {
                    Button("Select") {
                        isDuplicateSelectMode = true
                        selectedDuplicateIds.removeAll()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(TrashPicUpTheme.accentCyan)
                    .cornerRadius(8)
                }
            }
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 12) {
                    ForEach(group) { peer in
                        DuplicateThumbnailView(
                            photo: peer,
                            isCurrent: peer.id == activePhoto.id,
                            isSelected: selectedDuplicateIds.contains(peer.id),
                            onTap: {
                                if isDuplicateSelectMode {
                                    if selectedDuplicateIds.contains(peer.id) {
                                        selectedDuplicateIds.remove(peer.id)
                                    } else {
                                        selectedDuplicateIds.insert(peer.id)
                                    }
                                } else {
                                    displayedPhoto = peer
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(minHeight: 120)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TrashPicUpTheme.fullScreenInfoBg)
        }
    }
}

struct DuplicateThumbnailView: View {
    let photo: PhotoItem
    let isCurrent: Bool
    let isSelected: Bool
    let onTap: () -> Void

    @State private var image: PlatformImage?

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    thumbnail
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? TrashPicUpTheme.accentCyan : Color.clear, lineWidth: 3)
                        )
                    if isCurrent {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(TrashPicUpTheme.fullScreenInfoBg.opacity(0.85))
                            .clipShape(Circle())
                            .padding(6)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(TrashPicUpTheme.accentCyan)
                            .padding(4)
                    }
                }
                duplicateTagsRow
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
        .onAppear { loadThumbnail() }
    }

    @ViewBuilder
    private var duplicateTagsRow: some View {
        HStack(spacing: 3) {
            if photo.analysis?.isScreenshot == true {
                tagPill("SS", TrashPicUpTheme.accentMagenta)
            }
            if photo.analysis?.isBlurry == true {
                tagPill("Blur", TrashPicUpTheme.accentOrange)
            }
            if photo.analysis?.isDuplicate == true {
                tagPill("Dup", TrashPicUpTheme.accentCyan)
            }
        }
    }

    private func tagPill(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let img = image {
            #if os(iOS)
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
            #else
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
            #endif
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.2))
                .overlay { ProgressView().tint(.white) }
        }
    }

    private func loadThumbnail() {
        photo.getImage(targetSize: CGSize(width: 144, height: 144), deliveryMode: .fastFormat) { image = $0 }
    }
}

// MARK: - Photo info sheet (swipe up)

struct PhotoInfoSheet: View {
    let photo: PhotoItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                if let date = photo.asset.creationDate {
                    LabeledContent("Date taken") {
                        Text(date, style: .date)
                    }
                }
                LabeledContent("File size") {
                    Text(photo.formattedFileSize)
                }
                LabeledContent("Dimensions") {
                    Text("\(photo.asset.pixelWidth) × \(photo.asset.pixelHeight)")
                }
                if let loc = photo.asset.location {
                    LabeledContent("Location") {
                        Text(String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude))
                            .font(.caption)
                    }
                } else {
                    LabeledContent("Location") {
                        Text("None")
                            .foregroundStyle(TrashPicUpTheme.textSecondary)
                    }
                }
                if photo.analysis?.isScreenshot == true || photo.analysis?.isBlurry == true || photo.analysis?.isDuplicate == true {
                    LabeledContent("Type") {
                        HStack(spacing: 4) {
                            if photo.analysis?.isScreenshot == true {
                                Text("Screenshot").foregroundStyle(TrashPicUpTheme.accentMagenta)
                            }
                            if photo.analysis?.isScreenshot == true, (photo.analysis?.isBlurry == true || photo.analysis?.isDuplicate == true) { Text(",").foregroundStyle(TrashPicUpTheme.textSecondary) }
                            if photo.analysis?.isBlurry == true {
                                Text("Blurry").foregroundStyle(TrashPicUpTheme.accentOrange)
                            }
                            if photo.analysis?.isBlurry == true, photo.analysis?.isDuplicate == true { Text(",").foregroundStyle(TrashPicUpTheme.textSecondary) }
                            if photo.analysis?.isDuplicate == true {
                                Text("Duplicate").foregroundStyle(TrashPicUpTheme.accentCyan)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Photo info")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(TrashPicUpTheme.accentMagenta)
                }
            }
        }
    }
}

struct FullScreenPhotoModifier: ViewModifier {
    @Binding var showingFullScreen: PhotoItem?
    var allPhotos: [PhotoItem]
    @Binding var pendingDeletes: [PhotoItem]
    var onAddToPending: ([PhotoItem]) -> Void
    var onKeep: (Set<String>) -> Void
    var onDismissAndAdvance: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(item: $showingFullScreen) { photo in
                FullScreenPhotoView(
                    photo: photo,
                    allPhotos: allPhotos,
                    pendingDeletes: $pendingDeletes,
                    onAddToPending: onAddToPending,
                    onKeep: onKeep,
                    onDismiss: { showingFullScreen = nil },
                    onDismissAndAdvance: onDismissAndAdvance
                )
            }
    }
}

// MARK: - Helpers

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundStyle(TrashPicUpTheme.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(TrashPicUpTheme.textPrimary)
        }
    }
}

// PhotoItem Hashable for sheet(item:)
extension PhotoItem: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool { lhs.id == rhs.id }
}
