# iOS Setup Guide for TrashPicUp

The code is already cross-platform! To test on iOS, you need to add an iOS target in Xcode.

## Quick Setup (Recommended)

### Option 1: Using Xcode UI (Easiest)

1. **Open the project in Xcode**:
   ```bash
   open TrashPicUp.xcodeproj
   ```

2. **Add iOS Target**:
   - Click on the **project** (blue icon) in the navigator
   - Click the **"+"** button at the bottom of the **TARGETS** list
   - Select **iOS** → **App**
   - Name: `TrashPicUp iOS`
   - Bundle Identifier: `com.trashpicup.app.ios`
   - Language: **Swift**
   - Interface: **SwiftUI**
   - Click **Finish**

3. **Add Source Files to iOS Target**:
   - Select the iOS target in the project navigator
   - Go to **Build Phases** → **Compile Sources**
   - Click **"+"** and add all Swift files:
     - `TrashPicUpApp.swift`
     - `ContentView.swift`
     - `PhotoManager.swift`
     - `PhotoAnalyzer.swift`
     - `GameView.swift`
     - `GameState.swift`
     - `AnalysisCache.swift`
     - `PlatformImage.swift`
     - `TrashPicUpTheme.swift`

4. **Add Resources**:
   - In **Build Phases** → **Copy Bundle Resources**
   - Click **"+"** and add:
     - `Assets.xcassets`

5. **Configure iOS Target Settings**:
   - Select the iOS target
   - Go to **General** tab:
     - **Deployment Info**: iOS 17.0 (or your preferred minimum)
     - **Supported Destinations**: iPhone, iPad
   - Go to **Signing & Capabilities**:
     - Select your **Team**
     - Click **"+ Capability"** → Add **Photos Library** (Read and Write)
   - Go to **Info** tab:
     - Ensure `NSPhotoLibraryUsageDescription` is set:
       - Value: `"TrashPicUp needs access to your photo library to help you clean up unnecessary photos."`

6. **Update AppIcon for iOS**:
   - The AppIcon already includes a universal 1024x1024 icon
   - Xcode will generate iOS sizes automatically, or you can add specific sizes in `Assets.xcassets/AppIcon.appiconset`

7. **Build and Run**:
   - Select the **iOS target** from the scheme dropdown
   - Choose an **iOS Simulator** (e.g., iPhone 15 Pro)
   - Press **⌘R** to build and run

### Option 2: Using Command Line (Advanced)

If you prefer automation, you can use Xcode's command-line tools, but the UI method above is recommended.

## What's Already Cross-Platform

✅ All Swift files use `#if os(iOS)` and `#if os(macOS)` conditionals  
✅ `PlatformImage` type alias handles `UIImage` (iOS) and `NSImage` (macOS)  
✅ UI adapts automatically (NavigationView on iOS, HSplitView on macOS)  
✅ Full-screen photo uses `fullScreenCover` on iOS, `sheet` on macOS  
✅ Photo loading works on both platforms  

## Testing on iOS Simulator

1. **Select iOS Target**: Choose "TrashPicUp iOS" from the scheme dropdown
2. **Choose Simulator**: Select an iPhone or iPad simulator
3. **Run**: Press **⌘R**
4. **Grant Permissions**: When prompted, allow photo library access

## Testing on Physical Device

1. **Connect your iPhone/iPad** via USB
2. **Select your device** from the device dropdown
3. **Trust the developer certificate** on your device (Settings → General → VPN & Device Management)
4. **Run**: Press **⌘R**
5. **Grant Permissions**: Allow photo library access when prompted

## Troubleshooting

- **"No such module 'UIKit'"**: Make sure you're building the iOS target, not macOS
- **"Photos permission denied"**: Check Info.plist has `NSPhotoLibraryUsageDescription`
- **"App crashes on launch"**: Ensure all source files are added to the iOS target's Build Phases
- **"Icon not showing"**: Verify `Assets.xcassets` is in the iOS target's Resources

## Notes

- The macOS and iOS targets share the same source code
- Each target has its own build settings and capabilities
- You can build both targets from the same project
- The app icon (`AppIcon.png`) works for both platforms
