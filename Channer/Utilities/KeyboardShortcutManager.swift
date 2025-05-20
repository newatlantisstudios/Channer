import UIKit

/**
 * Manages keyboard shortcuts for the app.
 * Provides shortcut configurations for different views and controllers.
 */
class KeyboardShortcutManager {
    static let shared = KeyboardShortcutManager()
    
    private var isEnabled = true
    
    private init() {
        // Load settings
        isEnabled = UserDefaults.standard.bool(forKey: "keyboardShortcutsEnabled")
        if !UserDefaults.standard.contains(key: "keyboardShortcutsEnabled") {
            // Default to enabled if setting doesn't exist
            isEnabled = true
            UserDefaults.standard.set(true, forKey: "keyboardShortcutsEnabled")
        }
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "keyboardShortcutsEnabled")
    }
    
    func isShortcutsEnabled() -> Bool {
        return isEnabled
    }
    
    // Register global shortcuts with the app
    func registerGlobalShortcuts(window: UIWindow) {
        guard isEnabled else { return }
        
        // These shortcuts will be available throughout the app
        let shortcuts = [
            UIKeyCommand(title: "Home", action: #selector(AppDelegate.navigateToHome), input: "h", modifierFlags: .command),
            UIKeyCommand(title: "Boards", action: #selector(AppDelegate.navigateToBoards), input: "b", modifierFlags: .command),
            UIKeyCommand(title: "Favorites", action: #selector(AppDelegate.navigateToFavorites), input: "f", modifierFlags: .command),
            UIKeyCommand(title: "History", action: #selector(AppDelegate.navigateToHistory), input: "y", modifierFlags: .command),
            UIKeyCommand(title: "Settings", action: #selector(AppDelegate.navigateToSettings), input: ",", modifierFlags: .command),
            UIKeyCommand(title: "Refresh", action: #selector(AppDelegate.refreshContent), input: "r", modifierFlags: .command)
        ]
        
        // Add to the app's key commands
        window.rootViewController?.addKeyCommands(shortcuts)
    }
    
    // Shortcuts for the boards collection view
    func getBoardsViewShortcuts(target: Any) -> [UIKeyCommand] {
        guard isEnabled else { return [] }
        
        return [
            UIKeyCommand(title: "Next Board", action: #selector(boardsCV.nextBoard), input: UIKeyCommand.inputRightArrow, modifierFlags: []),
            UIKeyCommand(title: "Previous Board", action: #selector(boardsCV.previousBoard), input: UIKeyCommand.inputLeftArrow, modifierFlags: []),
            UIKeyCommand(title: "Open Selected Board", action: #selector(boardsCV.openSelectedBoard), input: "\r", modifierFlags: [])
        ]
    }
    
    // Shortcuts for the board threads table view
    func getBoardThreadsShortcuts(target: Any) -> [UIKeyCommand] {
        guard isEnabled else { return [] }
        
        return [
            UIKeyCommand(title: "Next Thread", action: #selector(boardTV.nextThread), input: UIKeyCommand.inputDownArrow, modifierFlags: []),
            UIKeyCommand(title: "Previous Thread", action: #selector(boardTV.previousThread), input: UIKeyCommand.inputUpArrow, modifierFlags: []),
            UIKeyCommand(title: "Open Selected Thread", action: #selector(boardTV.openSelectedThread), input: "\r", modifierFlags: []),
            UIKeyCommand(title: "Refresh Threads", action: #selector(boardTV.refreshThreads), input: "r", modifierFlags: .command)
        ]
    }
    
    // Shortcuts for thread replies view
    func getThreadRepliesShortcuts(target: Any) -> [UIKeyCommand] {
        guard isEnabled else { return [] }
        
        return [
            UIKeyCommand(title: "Next Reply", action: #selector(threadRepliesTV.nextReply), input: UIKeyCommand.inputDownArrow, modifierFlags: []),
            UIKeyCommand(title: "Previous Reply", action: #selector(threadRepliesTV.previousReply), input: UIKeyCommand.inputUpArrow, modifierFlags: []),
            UIKeyCommand(title: "Toggle Favorite", action: #selector(threadRepliesTV.toggleFavoriteShortcut), input: "d", modifierFlags: .command),
            UIKeyCommand(title: "Gallery View", action: #selector(threadRepliesTV.openGallery), input: "g", modifierFlags: .command),
            UIKeyCommand(title: "Back to Board", action: #selector(threadRepliesTV.backToBoard), input: UIKeyCommand.inputEscape, modifierFlags: [])
        ]
    }
    
    // iPad-specific shortcuts for split view
    func getIPadSplitViewShortcuts(target: Any) -> [UIKeyCommand] {
        guard isEnabled else { return [] }
        
        return [
            UIKeyCommand(title: "Focus on Master View", action: #selector(CustomSplitViewController.focusMasterView), input: "[", modifierFlags: .command),
            UIKeyCommand(title: "Focus on Detail View", action: #selector(CustomSplitViewController.focusDetailView), input: "]", modifierFlags: .command),
            UIKeyCommand(title: "Toggle Split View", action: #selector(CustomSplitViewController.toggleSplitView), input: "\\", modifierFlags: .command)
        ]
    }
}

// Extension to check if a key exists in UserDefaults
extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}