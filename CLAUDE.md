# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Channer is a native iOS and iPadOS client for browsing image boards with a focus on user privacy, smooth media handling, and a clean interface. The app uses Swift and UIKit with an adaptive UI that works well on both iPhone and iPad.

## Development Environment

- Platform: iOS/iPadOS 18.0+
- Language: Swift
- Framework: UIKit
- Build System: Xcode
- Dependencies: CocoaPods

## Key Dependencies

- **SwiftyJSON**: Used for JSON parsing
- **Alamofire**: Used for networking
- **Kingfisher**: Used for image loading and caching
- **VLCKit**: Used for media playback
- **FFmpeg**: Used for media processing (replaced deprecated ffmpeg-kit-ios-full)

## Build and Run Commands

```bash
# Install dependencies
pod install

# Open the workspace (not the project file)
open Channer.xcworkspace

# Build the project from Xcode
# Select a target device/simulator and use Cmd+B or Product > Build
```

## Architecture Overview

The app follows a standard iOS MVC architecture with these key components:

1. **ThemeManager**: A singleton that manages app-wide theming with light/dark mode support
2. **ThreadCacheManager**: Manages offline reading capabilities and thread caching
3. **FavoritesManager**: Handles saving and retrieving favorite threads
4. **HistoryManager**: Tracks visited threads

## Key View Controllers

1. **boardsCV**: Main collection view that displays all available boards
2. **boardTV**: Displays threads from a selected board
3. **threadRepliesTV**: Displays replies in a thread
4. **settings**: Contains app configuration options
5. **ThemeEditorViewController**: Allows customization of app themes

## Authentication

The app uses FaceID/TouchID for securing certain features like history, favorites, and downloads. This is implemented through the LocalAuthentication framework.

## Recent Updates

As of May 2025, the project has replaced the deprecated `ffmpeg-kit-ios-full` library with the standard `FFmpeg` pod due to the original repository being archived.

## Planned Features

- Additional file format support
- UI improvements for iPad layout
- Enhanced theme customization options