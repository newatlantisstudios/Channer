# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Channer is a native iOS/iPadOS image board client using Swift, UIKit, and MVC architecture. The app supports both iPhone and iPad with adaptive UI.

## Development Environment

- **Platform**: iOS/iPadOS 15.6+ (deployment target 18.0)
- **Language**: Swift 5.0+
- **Build System**: Xcode with Swift Package Manager
- **Workspace**: Use `Channer.xcworkspace` or `Channer.xcodeproj`

## Build Commands

```bash
# Build scripts
./build.sh                    # Simple build with xcbeautify
./build-advanced.sh -c        # Clean build
./build-advanced.sh -r        # Release build
./build-advanced.sh -d        # Device build (not simulator)
./build-advanced.sh -m        # Mac Catalyst build
./build-advanced.sh -v        # Verbose build (no xcbeautify)
```

Both scripts use an isolated local cache at `build/.xcode-cache/` (DerivedData, SourcePackages, etc.) to avoid system cache permission issues. The `build/` directory is a build artifact — do not commit it.

## Testing

```bash
# Run all unit tests
xcodebuild test -workspace Channer.xcworkspace -scheme Channer \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test class
xcodebuild test -workspace Channer.xcworkspace -scheme Channer \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ChannerTests/ThemeManagerTests

# Run single test method
xcodebuild test -workspace Channer.xcworkspace -scheme Channer \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ChannerTests/ThemeManagerTests/testThemeManagerSetThemePostsNotification

# Run UI tests
xcodebuild test -workspace Channer.xcworkspace -scheme ChannerUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Test helpers in `ChannerTests/Helpers/`: `TestDataFactory`, `MockUserDefaults`, `MockiCloudStore`, `XCTestCase+Helpers`.

## Architecture Overview

MVC architecture with singleton managers in `Utilities/` for shared state.

### Navigation Flow
```
boardsCV (boards list)
  → boardTV (threads in board)
    → threadRepliesTV (thread replies, iPhone = UITableView)
    → threadRepliesCV (thread replies, iPad = UICollectionView)
      → ImageGalleryVC / WebMViewController (media viewing)
```

### iPhone vs iPad

The iPhone and iPad use separate view controller implementations for thread replies:
- **iPhone**: `ViewControllers/Thread Replies/threadRepliesTV.swift` — UITableViewController (~181KB, the largest file in the project)
- **iPad**: `iPad/threadRepliesCV.swift` — UICollectionViewController with split view, hover support (`threadRepliesCV+HoverSupport.swift`), keyboard shortcuts, and Apple Pencil support

`ThreadViewControllerFactory` in `Utilities/` selects the correct implementation at runtime.

### Key Singleton Managers
Located in `Utilities/` except where noted:
- **ThemeManager** (`ViewControllers/ThemeManager.swift`): App-wide theming (6 built-in + custom themes via `ThemeEditorViewController`)
- **FavoritesManager** (`ViewControllers/Home/FavoritesManager.swift`): Thread bookmarks with categorization
- **HistoryManager** (`ViewControllers/Home/HistoryManager.swift`): Visited thread tracking
- **ContentFilterManager**: Keyword/poster/image filtering (uses `ThreadDataHelper`)
- **SearchManager** (`ViewControllers/Home/SearchManager.swift`): Thread search with history
- **ICloudSyncManager** / **ConflictResolutionManager**: iCloud sync with conflict resolution
- **NotificationManager**: Push notifications for thread updates
- **WatchedPostsManager**: Watch individual posts for replies
- **StatisticsManager**: Tracks browsing analytics (boards visited, threads read, time spent)
- **ThreadCacheManager**: Offline thread caching

### Data Models Location
Some models are defined inline within view controller files:
- `ThreadData` struct: `ViewControllers/Board/boardTV.swift`
- `BookmarkCategory`: `ViewControllers/Home/BookmarkCategory.swift`
- `Reachability`, `TextFormatter`: `ViewControllers/Thread Replies/threadRepliesTV.swift`

### Storage Architecture
- **UserDefaults**: Simple preferences and feature flags (e.g., `faceIDEnabledKey`)
- **Keychain** (`KeychainHelper`): Sensitive credentials (4chan Pass via `PassAuthManager`)
- **iCloud** (`NSUbiquitousKeyValueStore`): Cross-device sync for favorites, history, settings
- **Codable**: Complex objects (themes, filters, bookmark categories) serialized to UserDefaults/iCloud

## Key Dependencies

- **Alamofire** + **SwiftyJSON**: Networking and JSON parsing (via Swift Package Manager)
- **Kingfisher**: Async image loading and caching (via Swift Package Manager)
- **VLCKit** (4.0.0a6): Downloaded video playback only (local XCFramework in `Frameworks/`)
- **FFmpeg**: Via bridging header (`FFmpeg-Bridging-Header.h`), NOT via package manager

## Important Implementation Notes

### Video Playback
- Streaming videos: Native AVPlayer via `WebMViewController`
- Downloaded videos: VLCKit exclusively (maximum codec compatibility)
- Videos start **muted by default**

### Thread Safety
`FavoritesManager`, `NotificationManager`, and `WatchedPostsManager` handle concurrent access. When modifying managers:
- Use serial queues, locks, or actors for synchronization
- iCloud sync callbacks arrive on background threads
- Test with `DispatchQueue.concurrentPerform` (see existing tests)

### Large Files
`threadRepliesTV.swift` (~181KB) and `settings.swift` (~145KB) are very large. When editing these, read only the relevant sections with line offsets rather than the entire file.

### Authentication
FaceID/TouchID protection via LocalAuthentication. Controlled by `faceIDEnabledKey` in UserDefaults.

## CI/CD

GitHub Actions (`.github/workflows/Xcode_build_PR.yml`):
- Self-hosted runner (macstudio)
- Builds for iPhone 16 Simulator
- Posts build errors to PR comments
- Build logs uploaded with 7-day retention

**Note**: The workflow file still references CocoaPods (`pod install`) but the project has migrated to Swift Package Manager. The workflow may need updating.