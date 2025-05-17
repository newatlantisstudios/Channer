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

### Using Xcode
```bash
# Install dependencies
pod install

# Open the workspace (not the project file)
open Channer.xcworkspace

# Build the project from Xcode
# Select a target device/simulator and use Cmd+B or Product > Build
```

### Using Build Scripts
The project includes several build scripts for command-line building:

1. **Simple Build** (`build.sh`)
   ```bash
   ./build.sh
   ```
   - Uses xcbeautify for clean, formatted output
   - Builds in Debug configuration for iOS Simulator
   - Shows only warnings and errors

2. **Advanced Build** (`build-advanced.sh`)
   ```bash
   ./build-advanced.sh [options]
   ```
   Options:
   - `-c, --clean`: Clean before building
   - `-r, --release`: Build in Release configuration (default: Debug)
   - `-d, --device`: Build for device instead of simulator
   - `-v, --verbose`: Show verbose output
   - `-h, --help`: Show help message

   Examples:
   ```bash
   ./build-advanced.sh -c       # Clean and build
   ./build-advanced.sh -r       # Release build
   ./build-advanced.sh -c -r    # Clean and release build
   ./build-advanced.sh -v       # Verbose output
   ```

3. **Quick Test Build** (`test-build.sh`)
   ```bash
   ./test-build.sh
   ```
   - Minimal output (only shows "BUILD SUCCEEDED" or "BUILD FAILED")
   - Useful for CI/CD pipelines
   - Returns exit code 0 for success, 1 for failure

### Installing xcbeautify
The build scripts use `xcbeautify` for better output formatting. If not installed, the scripts will attempt to install it via Homebrew:

```bash
brew install xcbeautify
```

## Architecture Overview

The app follows a standard iOS MVC architecture with these key components:

1. **ThemeManager**: A singleton that manages app-wide theming with light/dark mode support and theme customization
2. **ThreadCacheManager**: Manages offline reading capabilities and thread caching with iCloud sync
3. **FavoritesManager**: Handles saving and retrieving favorite threads with categorization support
4. **HistoryManager**: Tracks visited threads
5. **ContentFilterManager**: Manages keyword, poster, and image filtering for content

## Key View Controllers

1. **boardsCV**: Main collection view that displays all available boards
2. **boardTV**: Displays threads from a selected board
3. **threadRepliesTV**: Displays replies in a thread
4. **settings**: Contains app configuration options
5. **ThemeEditorViewController**: Allows customization of app themes
6. **CategorizedFavoritesViewController**: Manages categorized favorites
7. **ContentFilterViewController**: Manages content filtering settings

## Authentication

The app uses FaceID/TouchID for securing certain features like history, favorites, and downloads. This is implemented through the LocalAuthentication framework.

## Testing

The project has test targets (ChannerTests and ChannerUITests) but currently contains only placeholder test files. Unit tests can be added to the `ChannerTests` directory and UI tests to the `ChannerUITests` directory.

To run tests:
```bash
# Unit tests
xcodebuild test -workspace Channer.xcworkspace -scheme Channer -destination 'platform=iOS Simulator,name=iPhone 15'

# UI tests
xcodebuild test -workspace Channer.xcworkspace -scheme ChannerUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Recent Updates

As of May 2025, the project has replaced the deprecated `ffmpeg-kit-ios-full` library with the standard `FFmpeg` pod due to the original repository being archived.

## Planned Features

- Additional file format support
- UI improvements for iPad layout
- Enhanced theme customization options