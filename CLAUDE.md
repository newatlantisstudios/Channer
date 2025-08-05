# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Channer is a native iOS and iPadOS client for browsing image boards with a focus on user privacy, smooth media handling, and a clean interface. The app uses Swift and UIKit with an adaptive UI that works well on both iPhone and iPad.

## Development Environment

- Platform: iOS/iPadOS (deployment target 15.6+, build target 18.0+)
- Language: Swift
- Framework: UIKit
- Build System: Xcode
- Dependencies: CocoaPods

## Key Dependencies

- **SwiftyJSON**: Used for JSON parsing
- **Alamofire**: Used for networking
- **Kingfisher**: Used for image loading and caching
- **VLCKit** (4.0.0a6): Used for media playback
- **FFmpeg**: Used for media processing via native bridging header integration

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

### Singleton Managers
1. **ThemeManager**: Manages app-wide theming with 6 built-in themes and custom theme support
2. **ThreadCacheManager**: Manages offline reading capabilities and thread caching with iCloud sync
3. **FavoritesManager**: Handles saving and retrieving favorite threads with categorization support
4. **HistoryManager**: Tracks visited threads
5. **ContentFilterManager**: Manages keyword, poster, and image filtering for content
6. **SearchManager**: Thread search functionality with history and saved searches
7. **ICloudSyncManager**: Handles settings and data sync across devices
8. **ConflictResolutionManager**: Intelligent handling of sync conflicts
9. **NotificationManager**: Push notification support for thread updates
10. **KeyboardShortcutManager**: iPad keyboard shortcut handling
11. **PencilInteractionManager**: Apple Pencil support

### Key View Controllers

#### Main Navigation Flow
1. **boardsCV**: Main collection view that displays all available boards
2. **boardTV**: Displays threads from a selected board
3. **threadRepliesTV**: Displays replies in a thread

#### Settings & Configuration
- **settings**: Main settings view controller
- **ThemeEditorViewController**: Allows customization of app themes
- **ThemeListViewController**: Lists available themes
- **ContentFilterViewController**: Manages content filtering settings

#### Organization & Search
- **CategorizedFavoritesViewController**: Manages categorized favorites
- **CategoryManagerViewController**: Category creation and management
- **SearchViewController**: Thread search interface
- **ConflictResolutionViewController**: Handles sync conflict resolution

#### Media Handling
- **ImageGalleryVC**: Gallery view for thread images
- **WebMViewController**: WebM video player
- **ThumbnailGridVC**: Grid view of media thumbnails
- **ImageViewController**: Full-screen image viewer

## Recent Feature Implementations

### Enhanced Bookmarking System
- Categorized favorites with color-coding and SF Symbol icons
- Default categories: General, To Read, Important, Archives
- Bulk operations and category management
- Full implementation details in `ENHANCED_BOOKMARKING_SUMMARY.md`

### iCloud Sync
- Complete settings, themes, and data synchronization
- Automatic conflict resolution
- Implementation details in `ICLOUD_SYNC_IMPLEMENTATION.md`

### Thread Search
- Comprehensive search with history tracking
- Saved searches and board-specific filtering
- Details in `THREAD_SEARCH_SUMMARY.md`

### iPad Enhancements
- Full keyboard shortcut support (see `KEYBOARD_SHORTCUTS.md`)
- Split view controller optimization
- Apple Pencil interaction support

## Authentication

The app uses FaceID/TouchID for securing certain features like history, favorites, and downloads. This is implemented through the LocalAuthentication framework.

## Testing

The project has test targets (ChannerTests and ChannerUITests) but currently contains only placeholder test files. The CI/CD pipeline validates builds but comprehensive test coverage is not yet implemented.

To run placeholder tests:
```bash
# Unit tests (placeholder)
xcodebuild test -workspace Channer.xcworkspace -scheme Channer -destination 'platform=iOS Simulator,name=iPhone 16'

# UI tests (placeholder)
xcodebuild test -workspace Channer.xcworkspace -scheme ChannerUITests -destination 'platform=iOS Simulator,name=iPhone 16'
```

## CI/CD Configuration

The project includes GitHub Actions workflow for pull request validation:
- **Workflow**: `.github/workflows/Xcode_build_PR.yml`
- **Runner**: Self-hosted macstudio
- **Test Device**: iPhone 16 Simulator
- **Features**: Automatic build validation, error reporting to PRs, artifact uploads

## Important Notes

### Recent Updates
- Enhanced video playback consistency between gallery and thread views
- Improved settings UI with media preload options
- Implemented native FFmpeg integration via bridging header (removed pod dependency)
- Added comprehensive GitHub Actions CI/CD pipeline
- Made videos start muted by default in web player

### Platform-Specific Features
- **iPad**: Split view controllers, keyboard shortcuts, Apple Pencil support
- **iPhone**: Adaptive UI with gesture navigation
- **Universal**: iCloud sync, biometric authentication, offline caching