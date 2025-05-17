# Quick Conflict Resolution Test

## Simulator + Device Test

1. **Build and run on your iPhone**
2. **Build and run on iOS Simulator**
3. **Sign into same iCloud account on both**

## Create a Test Conflict

```bash
# Terminal commands to help with testing

# 1. Reset simulator (optional)
xcrun simctl erase all

# 2. Build and run on simulator
cd /Users/x/Documents/GitHub/Channer
./build.sh

# 3. Open simulator app
open -a Simulator
```

## Testing Steps

1. **On iPhone:**
   - Sign into iCloud
   - Enable iCloud sync in Settings
   - Add 2-3 favorites
   - Go to Settings > Toggle Airplane Mode ON

2. **On Simulator:**
   - Sign into same iCloud account
   - Enable iCloud sync
   - Add 2-3 different favorites
   - Keep network enabled

3. **On iPhone:**
   - Turn Airplane Mode OFF
   - Go to Settings > Tap "Sync Now"

4. **Expected Result:**
   - Conflict resolution UI appears
   - Shows local vs iCloud data
   - Options to merge, keep local, or keep remote

## Debug Output

Add this to AppDelegate.swift for testing:

```swift
// Add to didFinishLaunchingWithOptions
NotificationCenter.default.addObserver(
    forName: ICloudSyncManager.iCloudSyncStartedNotification,
    object: nil,
    queue: .main
) { _ in
    print("🔄 iCloud sync started")
}

NotificationCenter.default.addObserver(
    forName: ICloudSyncManager.iCloudSyncCompletedNotification,
    object: nil,
    queue: .main
) { _ in
    print("✅ iCloud sync completed")
}
```