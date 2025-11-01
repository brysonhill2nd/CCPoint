# CCPoint

Point is a comprehensive sports tracking app for Tennis, Padel, and Pickleball with Apple Watch integration.

## Features

### iOS App
- 🔐 Firebase authentication with Google Sign-In
- ☁️ CloudKit sync across devices
- 📊 Detailed game statistics and insights
- 🏆 Achievement system with tiered rewards
- 📸 Instagram story-style session sharing
- 📍 Location tracking with manual court selection
- ❤️ HealthKit integration for workout data

### Watch App
- ⌚ Real-time game tracking
- 🎾 Support for Tennis, Padel, and Pickleball
- 💓 Live heart rate and calorie tracking
- 📱 Seamless iPhone sync via WatchConnectivity
- 🎯 Complete scoring systems for all sports
- 📜 Game history and insights

## Tech Stack

- **SwiftUI** - Modern declarative UI framework
- **Firebase** - Authentication and backend services
- **CloudKit** - iCloud data sync
- **HealthKit** - Health and workout data
- **WatchConnectivity** - iPhone-Watch communication
- **CoreLocation** - Location services

## Requirements

- iOS 16.0+
- watchOS 9.0+
- Xcode 15.0+
- Apple Developer Account (for HealthKit)

## Setup

1. Clone the repository
2. Open `PointiOS.xcodeproj` in Xcode
3. Add your Firebase configuration (`GoogleService-Info.plist`)
4. Build and run on device (required for HealthKit and Watch features)

## Architecture

- **Shared Models** - Common data structures between iOS and Watch
- **LocationDataManager** - Manages saved court locations
- **WatchConnectivityManager** - Bidirectional sync between devices
- **CloudKitManager** - Cloud data persistence
- **AchievementManager** - Tracks and awards achievements

## License

Copyright © 2025 Bryson Hill II. All rights reserved.
