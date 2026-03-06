# TrashPicUp 🎮📸

A gamified macOS/iOS app that helps you clean up your Apple Photos library with a **Tinder-style** swipe interface. Focus on screenshots: one photo at a time, swipe or tap to keep or delete.

## Why I Built This

Managing thousands of screenshots across devices became overwhelming. I wanted a fun, gamified way to clean up my photo library that felt less like a chore and more like a game. TrashPicUp combines Tinder-style UI patterns with Apple's Photos framework to make photo management actually enjoyable.

## Screenshots

<img src="screenshots/TrashPicUp_Loading%20Screen.PNG" width="200" alt="Loading Screen"> <img src="screenshots/TrashPicUp_Screenshot%20and%20Blurry%20Photo.PNG" width="200" alt="Screenshot and Blurry Photo">

*Loading · Main review*

<img src="screenshots/TrashPicUp_Keep%20Photo.PNG" width="200" alt="Keep Photo"> <img src="screenshots/TrashPicUp_Delete%20Photo.PNG" width="200" alt="Delete Photo">

*Keep · Delete*

<img src="screenshots/TrashPicUp_Blurry%20Photo.PNG" width="200" alt="Blurry Photo"> <img src="screenshots/TrashPicUp_Blurry%20Photo%20Full%20Screen%20View.PNG" width="200" alt="Blurry Photo Full Screen">

*Blurry (card) · Blurry (full screen)*

<img src="screenshots/TrashPicUp_Duplicate%20Photo.PNG" width="200" alt="Duplicate Photo"> <img src="screenshots/TrashPicUp_Duplicate%20Photo%20Full%20Screen%20View.PNG" width="200" alt="Duplicate Full Screen">

*Duplicate (card) · Duplicate (full screen)*

<img src="screenshots/TrashPicUp_Stats%20%26%20Settings.PNG" width="200" alt="Stats & Settings">

*Stats & Settings*

## Features

- 🃏 **Tinder-Style Cards**: One photo at a time. Swipe left → delete, swipe right → keep. Or use the trash (bottom-left) and check (bottom-right) buttons.
- 📸 **Tap for Full-Screen**: Tap any photo to view it full-screen; tap again or close to dismiss.
- 📋 **Swipe Up for Info**: Swipe up on a card to see date taken, location, file size, and dimensions.
- 🎯 **Screenshot Focus**: Filter by All Photos or Screenshots. Reliable detection via Screenshots album, system subtype, and filename.
- 🎮 **Gamification**: Earn points, level up, and track progress as you clean up.
- 📊 **Statistics**: Track photos deleted, space freed, and streaks (Stats & Settings).
- 🔄 **Undo Support**: Undo last deletion from Stats.
- 📱 **Cross-Platform**: Works on both macOS and iOS (see [IOS_SETUP.md](IOS_SETUP.md) for iOS setup).

## Requirements

- **macOS**: 14.0 or later
- **iOS**: 17.0 or later (when iOS target is added)
- Xcode 15.0 or later
- Photo library access permission

## Setup Instructions

### macOS

1. **Open the project in Xcode**:
   ```bash
   open TrashPicUp.xcodeproj
   ```

2. **Build and Run**:
   - Press `Cmd + R` to build and run
   - Grant photo library access when prompted

### iOS

See **[IOS_SETUP.md](IOS_SETUP.md)** for detailed iOS setup instructions. The code is already cross-platform—you just need to add an iOS target in Xcode.

## How It Works

### Photo Analysis

The app focuses on **screenshots**:

- **Screenshots**: Detected via the Screenshots album, system `.photoScreenshot` subtype, or filename containing "screenshot" / "screen shot".

### Gamification

- **Points**: Earn points for deleting screenshots (and other detected types).
- **Levels**: Level up every 100 points.
- **Streaks**: Consecutive deletions; track best streak.
- **Space**: See how much storage you've freed.

### UI / Theme

- **App icon**: Trash can + Photos-style flower (your provided asset).
- **Colors**: Lavender–blue → pink–violet gradient backgrounds; accent colors from the icon (cyan, magenta, green for keep, red for delete).
- **Design tooling**: UI flows and layouts were iterated in Figma.

### Audio

- **Sound design**: Swipe and celebration sound effects were generated and refined using ElevenLabs (custom whoosh and celebration clips).

## Usage

1. **Launch the app** and grant photo library access.
2. **Wait for analysis** (progress in header).
3. **Filter** via Stats & Settings: All Photos or Screenshots; sort by newest, oldest, largest, smallest.
4. **Review one photo at a time**:
   - **Swipe left** or **trash button** (bottom-left) → delete (with confirmation).
   - **Swipe right** or **check button** (bottom-right) → keep and advance.
   - **Tap photo** → full-screen view; tap or close to dismiss.
   - **Swipe up** → photo info (date, location, size, dimensions).
5. **Track progress** in Stats & Settings; **Undo last delete** when needed.

## Privacy & Security

- All photo analysis happens locally on your device
- No photos are uploaded to any server
- The app only requests read-write access to your photo library
- You maintain full control over which photos to delete

## Technical Details

- Built with SwiftUI for macOS and iOS
- Uses Photos framework for library access
- CoreImage for image analysis
- Background processing for efficient analysis
- Cross-platform code with `#if os(iOS)` / `#if os(macOS)` conditionals

## Future Enhancements

Potential improvements:
- More sophisticated duplicate detection
- Machine learning-based blur detection
- Batch operations
- Export statistics
- Cloud sync for statistics (optional)

## License

This project is provided as-is for personal use.

## Notes

- The app requires photo library access permission
- First-time analysis may take a while for large photo libraries
- Always review photos before deleting - the app provides recommendations but you make the final decision
- For iOS setup, see [IOS_SETUP.md](IOS_SETUP.md)
