import SwiftUI

/// Theme colors derived from the TrashPicUp app icon (trash + Photos flower).
/// Background: lavender-blue → pink-violet gradient. Accents: flower palette.
enum TrashPicUpTheme {
    // Background gradient (icon)
    static let gradientTop = Color(red: 174/255, green: 198/255, blue: 240/255)      // lavender-blue
    static let gradientBottom = Color(red: 224/255, green: 176/255, blue: 229/255)   // pink-violet
    
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [gradientTop, gradientBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // Flower accent colors (keep / delete / etc.)
    static let keepGreen = Color(red: 0.2, green: 0.75, blue: 0.4)
    static let deleteRed = Color(red: 0.9, green: 0.3, blue: 0.3)
    static let accentCyan = Color(red: 0.4, green: 0.8, blue: 0.95)
    static let accentMagenta = Color(red: 0.85, green: 0.4, blue: 0.7)
    static let accentOrange = Color(red: 0.95, green: 0.6, blue: 0.2)
    
    // Cards, sheets
    static let cardBackground = Color.white.opacity(0.95)
    static let sheetBackground = Color.white.opacity(0.98)
    /// Header bar (main screen) – subtle tint so "Trash Pic Up" doesn't blend with white
    static let headerBackground = Color(red: 0.88, green: 0.90, blue: 0.96)
    static let overlayScrim = Color.black.opacity(0.4)
    
    // Text on light backgrounds (ensure readable)
    static let textPrimary = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let textSecondary = Color(red: 0.22, green: 0.22, blue: 0.28)
    
    // Full-screen viewer background (light, theme-adjacent)
    static let fullScreenBackground = Color(red: 0.92, green: 0.94, blue: 0.98)

    // Full-screen info panel (dark)
    static let fullScreenInfoBg = Color(red: 0.1, green: 0.1, blue: 0.14)
    static let fullScreenInfoText = Color.white.opacity(0.95)
    static let fullScreenInfoLabel = Color.white.opacity(0.65)
    
    // Subtle shadow for text on gradient (improves readability)
    static let textShadowColor = Color.black.opacity(0.14)
    /// Dark blue for loading screen text, aligned with gradient blues
    static let loadingTitleBlue = Color(red: 0.15, green: 0.22, blue: 0.48)
    /// Purple for loading screen text, aligned with accentMagenta and gradient
    static let loadingTitlePurple = Color(red: 0.5, green: 0.32, blue: 0.65)
}
