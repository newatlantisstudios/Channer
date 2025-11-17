# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Channer is a native iOS and iPadOS client for browsing image boards with a focus on user privacy, smooth media handling, and a clean interface. The app uses Swift and UIKit with an MVC architecture and adaptive UI that works on both iPhone and iPad.

## Development Environment

- **Platform**: iOS/iPadOS (deployment target 15.6+, platform target 18.0+)
- **Language**: Swift 5.0+
- **Framework**: UIKit
- **Build System**: Xcode with CocoaPods
- **Workspace**: Always use `Channer.xcworkspace`, NOT `Channer.xcodeproj`

## Key Dependencies

- **Alamofire**: All networking requests (board lists, thread data, API calls)
- **SwiftyJSON**: JSON parsing for API responses
- **Kingfisher**: Async image loading, caching, and download management
- **VLCKit** (4.0.0a6): Local video file playback (downloaded files only)
- **FFmpeg**: Media processing via bridging header (`FFmpeg-Bridging-Header.h`) - uses system FFmpeg, not a pod

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

The app follows an MVC architecture with singleton managers for shared state and services.

### Directory Structure
```
Channer/
├── Application/        # AppDelegate, SceneDelegate, Info.plist
├── ViewControllers/    # All view controllers organized by feature
│   ├── Home/          # Main screens (boardsCV, boardsTV, settings)
│   ├── Board/         # Board listing (boardTV, boardTVCell)
│   ├── Thread Replies/# Thread view (threadRepliesTV, threadRepliesCell)
│   ├── Show Media/    # Media viewers (ImageGalleryVC, WebMViewController)
│   └── Downloads/     # Download management
├── iPad/              # iPad-specific views (threadsCell, threadRepliesCV)
├── Utilities/         # Singleton managers and helpers
├── Networking/        # Network services (ICloudSyncManager)
└── Files/             # Assets and resources
```

### Singleton Managers (All in `Utilities/`)
These are the core services accessed throughout the app:

1. **ThemeManager**: App-wide theming (6 built-in themes + custom themes)
2. **ThreadCacheManager**: Offline thread caching with iCloud sync
3. **FavoritesManager**: Thread bookmarks with categorization
4. **HistoryManager**: Visited thread tracking
5. **ContentFilterManager**: Keyword/poster/image filtering
6. **SearchManager**: Thread search with history
7. **ICloudSyncManager**: Settings/data sync across devices (also in `Networking/`)
8. **ConflictResolutionManager**: Handles iCloud sync conflicts
9. **NotificationManager**: Push notifications for thread updates
10. **KeyboardShortcutManager**: iPad keyboard shortcuts
11. **PencilInteractionManager**: Apple Pencil support

### Navigation Flow
The main user journey follows this pattern:
```
boardsCV (boards list)
  → boardTV (threads in selected board)
    → threadRepliesTV (replies in selected thread)
      → ImageGalleryVC / WebMViewController (media viewing)
```

**Key View Controllers**:
- **boardsCV**: Main entry point - displays all available boards in collection view
- **boardTV**: Shows threads from selected board in table view (also defines `ThreadData` struct)
- **threadRepliesTV**: Displays all replies in a thread with media thumbnails (also defines `Reachability` and `TextFormatter`)
- **ImageGalleryVC**: Full-screen image gallery with swipe navigation
- **WebMViewController**: Video player for WebM/MP4 files
- **ThumbnailGridVC**: Grid view of all media in a thread
- **settings**: Main settings interface
- **CategorizedFavoritesViewController**: Organized bookmarks with categories
- **SearchViewController**: Thread search with filters

**Important**: Some data models are defined inline within view controller files rather than in separate model files:
- `ThreadData` struct: in `ViewControllers/Board/boardTV.swift`
- `BookmarkCategory`: in `ViewControllers/Home/BookmarkCategory.swift`
- Other models may be embedded in their respective manager files

## Data Persistence & Networking

### Data Storage
- **UserDefaults**: Settings, preferences, authentication flags
- **FileManager**: Cached threads, downloaded media, offline content
- **iCloud**: Settings/theme sync via `NSUbiquitousKeyValueStore`

### Networking Pattern
All API calls use Alamofire with SwiftyJSON for parsing:
1. Request made via `Alamofire.request()`
2. Response parsed with `SwiftyJSON`
3. Data processed through manager singletons
4. UI updated on main thread

### Media Handling
- **Thumbnails/Images**: Kingfisher handles loading, caching, and memory management
- **WebM/MP4 (streaming)**: Played inline via WebMViewController with native player
- **Downloaded videos**: Played exclusively through VLCKit player for maximum format compatibility
- **Preloading**: Configurable in settings to optimize data usage

## Key Features & Implementation Details

### Enhanced Bookmarking (v2.2)
Categorized favorites with color-coding, SF Symbol icons, and bulk operations. Default categories: General, To Read, Important, Archives. See `ENHANCED_BOOKMARKING_SUMMARY.md`.

### iCloud Sync (v2.2)
Complete settings/themes/data synchronization with automatic conflict resolution via `ConflictResolutionManager`. See `ICLOUD_SYNC_IMPLEMENTATION.md` and `CONFLICT_RESOLUTION_IMPLEMENTATION.md`.

### Thread Search (v2.2)
Full-text search with history tracking, saved searches, and board-specific filtering via `SearchManager`. See `THREAD_SEARCH_SUMMARY.md`.

### iPad Enhancements
Full keyboard shortcut support (`KeyboardShortcutManager`), split view optimization, and Apple Pencil support. See `KEYBOARD_SHORTCUTS.md`.

### Authentication
FaceID/TouchID protection for history, favorites, and downloads via LocalAuthentication framework. Controlled by `faceIDEnabledKey` in UserDefaults.

## Testing

The project has comprehensive test infrastructure with unit tests for managers and UI tests for user flows.

### Test Structure
```
ChannerTests/
├── Managers/          # Unit tests for singleton managers
├── Models/            # Tests for data models (BookmarkCategory, etc.)
├── Mocks/             # Mock implementations for testing
└── Helpers/           # Test utilities and helpers
    ├── MockUserDefaults.swift
    ├── MockiCloudStore.swift
    ├── TestDataFactory.swift
    └── XCTestCase+Helpers.swift

ChannerUITests/
└── Screens/           # UI tests for main screens
```

### Running Tests

**Run all unit tests:**
```bash
xcodebuild test -workspace Channer.xcworkspace -scheme Channer -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Run specific test class:**
```bash
xcodebuild test -workspace Channer.xcworkspace -scheme Channer \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ChannerTests/ThemeManagerTests
```

**Run single test method:**
```bash
xcodebuild test -workspace Channer.xcworkspace -scheme Channer \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ChannerTests/ThemeManagerTests/testThemeManagerSetThemePostsNotification
```

**Run UI tests:**
```bash
xcodebuild test -workspace Channer.xcworkspace -scheme ChannerUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Run tests from Xcode:**
- Press `Cmd+U` to run all tests
- Use Test Navigator (`Cmd+6`) to run individual tests
- Click the diamond icon next to any test method

### Test Helpers

**TestDataFactory**: Creates realistic test fixtures for threads, categories, notifications, themes, etc.

**MockUserDefaults**: In-memory UserDefaults for isolated testing without polluting app data.

**MockiCloudStore**: Mock NSUbiquitousKeyValueStore for testing iCloud sync without real iCloud access.

**XCTestCase+Helpers**: Extensions for async testing, notifications, file operations, and common assertions.

### Test Coverage
Current test coverage includes:
- ContentFilterManager (29 test cases)
- HistoryManager (32 test cases)
- NotificationManager (36 test cases)
- ThemeManager (42 test cases)
- BookmarkCategory model (28 test cases)
- UI tests for board list screen (14 test cases)

See `TESTING_SUMMARY.md` and `TEST_STRUCTURE_ANALYSIS.md` for detailed test documentation.

## CI/CD Configuration

GitHub Actions workflow validates all pull requests:
- **Workflow**: `.github/workflows/Xcode_build_PR.yml`
- **Runner**: Self-hosted macstudio
- **Target**: iPhone 16 Simulator (iOS 18.0)
- **Process**: Auto-installs CocoaPods → Builds project → Runs tests → Posts errors to PR comments
- **Artifacts**: Build logs uploaded with 7-day retention
- **Note**: The Podfile is located in the project root directory

## Important Implementation Notes

### Video Playback
- **Streaming videos** (in-app WebM/MP4): Native AVPlayer via WebMViewController
- **Downloaded videos**: Exclusively use VLCKit for maximum codec compatibility
- Videos start **muted by default** in web player
- Gallery and thread views maintain playback consistency

### FFmpeg Integration
FFmpeg is integrated via bridging header (`FFmpeg-Bridging-Header.h`) linking to system FFmpeg libraries, NOT via CocoaPods. The old `ffmpeg-kit-ios-full` pod has been removed.

### iPad-Specific Behavior
- Split view controllers for multitasking
- Keyboard shortcuts via `KeyboardShortcutManager`
- Apple Pencil interactions via `PencilInteractionManager`
- Hover support in thread replies views (`threadRepliesCV+HoverSupport.swift`)

### Content Filtering
`ContentFilterManager` provides keyword, poster, and image filtering. Helper class `ThreadDataHelper` applies filters to thread data. Currently has TODO items for full implementation.

### Theming System
`ThemeManager` singleton controls app-wide theming. Supports 6 built-in themes plus custom themes created via `ThemeEditorViewController`. Themes sync across devices via iCloud.

### Thread Safety Considerations
Some singleton managers (notably `FavoritesManager` and `NotificationManager`) handle concurrent access from multiple threads. When modifying these managers or creating new ones:
- Use appropriate synchronization mechanisms (serial queues, locks, or actors)
- Test concurrent operations (see existing test suite for examples with `DispatchQueue.concurrentPerform`)
- Be aware that iCloud sync callbacks may arrive on background threads
- UserDefaults operations should be coordinated to prevent race conditions