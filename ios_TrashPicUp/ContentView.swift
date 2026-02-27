import SwiftUI
import Photos
import Combine
import AVFoundation

struct ContentView: View {
    @StateObject private var gameState = GameState()
    @StateObject private var photoManager = PhotoManager()
    @State private var showingPermissionAlert = false
    
    private var isLoadingOrAnalyzing: Bool {
        photoManager.isLoading || photoManager.isAnalyzing
    }
    
    var body: some View {
        Group {
            if !photoManager.hasPhotoAccess {
                PermissionView(photoManager: photoManager)
            } else if isLoadingOrAnalyzing {
                LoadingView(photoManager: photoManager)
            } else {
                GameView()
                    .environmentObject(gameState)
                    .environmentObject(photoManager)
            }
        }
        .onAppear {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true, options: [])
            photoManager.requestAuthorization()
        }
    }
}

struct LoadingView: View {
    @ObservedObject var photoManager: PhotoManager
    
    var body: some View {
        ZStack {
            LoopingVideoView(resourceName: "loading screen 2.0", fileExtension: "mov", fillScreen: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                ZStack {
                    Text("It's time for ...")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(TrashPicUpTheme.loadingTitlePurple)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer()
                    .frame(height: 0)
                ZStack {
                    Text("Trash Pic Up")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(TrashPicUpTheme.loadingTitlePurple)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 24)
        }
        .ignoresSafeArea()
    }
}

struct PermissionView: View {
    @ObservedObject var photoManager: PhotoManager
    
    var body: some View {
        ZStack {
            TrashPicUpTheme.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 80))
                    .foregroundStyle(TrashPicUpTheme.accentCyan)
                
                Text("Welcome to Trash Pic Up!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(TrashPicUpTheme.textPrimary)
                    .shadow(color: TrashPicUpTheme.textShadowColor, radius: 0.5, x: 0, y: 1)
                
                Text("Clean up your photo library and earn points!")
                    .font(.title2)
                    .foregroundStyle(TrashPicUpTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .shadow(color: TrashPicUpTheme.textShadowColor, radius: 0.5, x: 0, y: 1)
                
                VStack(alignment: .leading, spacing: 15) {
                    FeatureRow(icon: "camera.viewfinder", text: "Identify screenshots")
                    FeatureRow(icon: "photo.on.rectangle.angled", text: "Filter by Screenshots album")
                    FeatureRow(icon: "gamecontroller", text: "Earn points as you clean up")
                }
                .padding()
                .background(TrashPicUpTheme.cardBackground)
                .cornerRadius(12)
                
                Button {
                    photoManager.requestAuthorization()
                } label: {
                    Text("Grant Photo Library Access")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 15)
                        .background(TrashPicUpTheme.accentMagenta)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                if photoManager.authorizationStatus == .denied {
                    Text("Please enable photo access in System Settings")
                        .font(.caption)
                        .foregroundStyle(TrashPicUpTheme.deleteRed)
                }
            }
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(TrashPicUpTheme.accentCyan)
                .frame(width: 30)
            Text(text)
                .font(.body)
                .foregroundStyle(TrashPicUpTheme.textPrimary)
        }
    }
}
