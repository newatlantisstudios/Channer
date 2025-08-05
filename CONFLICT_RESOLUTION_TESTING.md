# Testing Conflict Resolution for iCloud Sync

## Prerequisites

1. **Ensure app is built** with conflict resolution system
2. **Prepare testing devices** with same iCloud account

## Test Setup

You'll need:
- Two iOS devices (or one device and the iOS Simulator)
- The same iCloud account signed in on both devices
- iCloud sync enabled in the app settings on both devices

## Test Scenarios

### Scenario 1: Basic Favorites Conflict

1. **Prepare initial state:**
   - Install the app on both devices
   - Enable iCloud sync on both devices
   - Wait for initial sync

2. **Create conflict:**
   - Turn on Airplane Mode on Device 1
   - Add 2-3 favorite threads on Device 1
   - Turn on Airplane Mode on Device 2
   - Add 2-3 different favorite threads on Device 2
   - Turn off Airplane Mode on both devices

3. **Expected result:**
   - When devices sync, the conflict resolution UI should appear
   - You should see options to:
     - Keep local data
     - Keep iCloud data  
     - Merge both sets

### Scenario 2: Category Conflicts

1. **Create categories:**
   - On Device 1: Create categories "Tech" and "Gaming"
   - Wait for sync
   - On Device 2: Verify categories synced

2. **Create conflict:**
   - Turn on Airplane Mode on both devices
   - On Device 1: Rename "Tech" to "Technology"
   - On Device 2: Rename "Tech" to "Software"
   - Add different favorites to these categories
   - Turn off Airplane Mode on both devices

3. **Expected result:**
   - Conflict resolution UI should appear
   - Shows the different category names and their contents

### Scenario 3: History Conflicts

1. **Build history:**
   - Visit several threads on Device 1
   - Wait for sync
   - Verify history appears on Device 2

2. **Create conflict:**
   - Turn on Airplane Mode on both devices
   - Visit different threads on each device
   - Turn off Airplane Mode

3. **Expected result:**
   - History should merge automatically (union of both sets)
   - May show conflict UI if same thread has different metadata

### Scenario 4: Theme Conflicts

1. **Create custom themes:**
   - Create a custom theme on Device 1
   - Wait for sync
   - Modify the same theme on Device 2 while offline

2. **Expected result:**
   - Should show conflict resolution for theme changes
   - Options to keep either version or rename one

## Debugging Tips

1. **Enable logging:**
   - Check Console app on Mac while testing
   - Look for messages from `ConflictResolutionManager`
   - Check iCloud sync status in Settings

2. **Force conflicts:**
   - Use Airplane Mode to ensure devices don't sync
   - Make conflicting changes before reconnecting
   - Can also use "Sync Now" button to trigger manual sync

3. **Monitor sync status:**
   - Check the sync timestamp in Settings
   - Look for "Last synced X minutes ago"
   - Green indicator means recent sync

## Common Issues

1. **No conflict UI appears:**
   - Ensure both devices have different data
   - Check that ConflictResolutionDelegate is set
   - Verify files are added to Xcode project

2. **Data not syncing:**
   - Check iCloud account is signed in
   - Verify app has iCloud entitlements
   - Ensure network connectivity

3. **Merge doesn't work as expected:**
   - Check the merge logic in ConflictResolutionManager
   - Verify data structures match between versions

## Integration Testing

To fully test the integration:

1. Update `ICloudSyncManager.swift` as shown in the implementation
2. Update `FavoritesManager.swift` to use conflict resolution
3. Update `HistoryManager.swift` to use conflict resolution
4. Update `AppDelegate.swift` to implement the delegate

Then run through all scenarios above.