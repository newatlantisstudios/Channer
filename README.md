<div align="center">

<img width="300" alt="simulator_screenshot_480AF9A3-0AF9-4C27-92DB-B455FBED3AB0" src="https://github.com/user-attachments/assets/e3f91edd-b860-4a14-acb2-7edbb1c5f5b2" />

  
  # Channer v3.0

  ### The Ultimate Image Board Client for iOS & iPadOS

  [![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20iPadOS-blue.svg)](https://developer.apple.com/ios/)
  [![iOS Version](https://img.shields.io/badge/iOS-15.6%2B-brightgreen.svg)](https://developer.apple.com/ios/)
  [![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org/)
  [![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)
  [![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()

  **A powerful, native iOS/iPadOS client for browsing image boards with advanced features, privacy-focused design, and seamless media handling.**

  [Features](#-features) • [Installation](#-installation) • [Build](#-building-from-source) • [Contributing](#-contributing)
</div>

---

## ✨ Why Channer?

- 🚀 **Native Performance**: Built with Swift for blazing-fast browsing
- 🔒 **Privacy First**: No tracking, no analytics, your data stays yours
- 🎨 **Beautiful Design**: Adaptive UI that looks great on any device
- 📱 **Universal App**: One app for iPhone and iPad with optimized interfaces
- 🌐 **Offline Support**: Browse cached threads without internet
- ⚡ **Smart Features**: Advanced search, filtering, and organization tools

## 🆕 What's New in v3.0

### Expanded iCloud Sync

- **☁️ Universal Sync**: Sync settings, themes, favorites, statistics, 4chan Pass credentials, and hidden boards across all devices
- **📂 Categorized Favorites**: Organize saved threads into custom categories with color-coding and icons
- **🔍 Synced Search History**: Search through threads with history tracking and saved searches

### Enhanced Post Rendering

- **🔮 Spoiler Support**: Tap-to-reveal spoiler text with per-spoiler state tracking
- **💻 Code Highlighting**: Syntax highlighting for programming boards (/g/, /sci/, /diy/)
- **📐 Math Rendering**: LaTeX and formula support for /sci/ board with Greek letters
- **🔗 Link Previews**: Inline YouTube, Twitter, and external link previews

### Smart Notifications

- **📍 Auto-Scroll to Reply**: Tap a notification to jump directly to the reply
- **🔔 Duplicate Prevention**: Stable identifiers prevent notification spam
- **📝 Rich Previews**: See actual reply text and image indicators in notifications

### User Interface Improvements

- **🔄 Pull-to-Refresh**: Refresh boards and threads with a simple swipe
- **🎨 Advanced Theming**: Comprehensive theme customization with live editing
- **⌨️ iPad Keyboard Shortcuts**: Full keyboard navigation support for iPad users
- **📱 Streamlined Actions**: Consolidated action menu for cleaner interface

### Developer & Build Improvements

- **📦 Swift Package Manager**: Migrated from CocoaPods to modern SPM
- **🔨 Enhanced Build System**: Multiple build scripts with clean, formatted output
- **🧪 Better Testing Framework**: Improved test structure and CI/CD support

## 🌟 Features

<table>
<tr>
<td width="50%">

### 📱 Browsing Experience

- **Intuitive Navigation**: Swipe gestures and smart controls
- **Pull-to-Refresh**: Refresh content with a simple swipe
- **Thread Sorting**: By reply count, date, or custom filters
- **Adaptive Layout**: Optimized for every screen size
- **Quick Actions**: 3D Touch and context menus
- **Split View**: Multitasking on iPad

### 🎬 Media Handling

- **WebM & MP4 Support**: Native video playback
- **Local Videos via VLC**: Downloaded videos play using the in-app VLCKit player exclusively for maximum compatibility
- **Image Gallery**: Beautiful media browser
- **Download Manager**: Batch downloads with progress
- **Thumbnail Grid**: Visual thread overview
- **Smart Preloading**: Configurable media caching

### 🔐 Privacy & Security

- **Biometric Lock**: FaceID/TouchID protection
- **Zero Tracking**: No analytics or data collection
- **Local Storage**: Your data stays on device
- **Encrypted Sync**: Secure iCloud synchronization
- **Content Filters**: Advanced filtering system

</td>
<td width="50%">

### 📂 Organization Tools

- **Smart Categories**: Custom folders for favorites
  - 🎨 Color-coded with icons
  - 📋 Bulk management tools
  - 🏷️ Custom tags and notes
- **Thread History**: Automatic visit tracking
- **Watch List**: Notifications for new replies
- **Quick Access**: Jump to recent threads

### 🔍 Search & Discovery

- **Full-Text Search**: Search all thread content
- **Search Filters**: By board, date, or type
- **Search History**: Recent and saved searches
- **Export Results**: Share or save search results

### ✨ Rich Post Rendering

- **Spoiler Text**: Tap-to-reveal spoilers
- **Code Highlighting**: Syntax colors for /g/, /sci/, /diy/
- **Math/LaTeX**: Formula rendering for /sci/
- **Link Previews**: YouTube, Twitter embeds

### 🎨 Customization

- **Theme Editor**: Create custom themes
- **Dynamic Themes**: Auto light/dark switching
- **Font Options**: Size and style preferences
- **Layout Modes**: List, grid, or compact view
- **Gesture Controls**: Customize swipe actions

</td>
</tr>
</table>

## 🛠️ Technical Details

<details>
<summary><b>System Requirements</b></summary>

- **iOS/iPadOS**: 15.6 or later
- **Devices**: iPhone, iPad, iPad Pro
- **Storage**: ~50MB app + cache
- **Network**: Required for browsing
</details>

<details>
<summary><b>Technology Stack</b></summary>

- **Language**: Swift 5.0+
- **UI Framework**: UIKit
- **Architecture**: MVC
- **Package Manager**: Swift Package Manager (SPM)
- **Minimum Deployment**: iOS 15.6
</details>

<details>
<summary><b>Dependencies</b></summary>

| Library | Purpose | Version |
|---------|---------|---------|
| Alamofire | Networking | 5.11.0 |
| SwiftyJSON | JSON Parsing | 5.0.2 |
| Kingfisher | Image Loading | 8.6.2 |
| VLCKit | Video Playback | 4.0.0a6 |
</details>

## 🚀 Installation

### Direct IPA

Download the latest IPA from our [Releases](https://github.com/newatlantisstudios/Channer/releases) page.

## 🔨 Building from Source

<details>
<summary><b>Prerequisites</b></summary>

- macOS 12.0 or later
- Xcode 14.0 or later
- Active Apple Developer account (for device builds)
</details>

<details>
<summary><b>Build Instructions</b></summary>

```bash
# Clone the repository
git clone https://github.com/newatlantisstudios/Channer.git
cd Channer

# Open in Xcode (SPM dependencies resolve automatically)
open Channer.xcworkspace

# Select your target and build (⌘+B)
```

For automated builds, use our build scripts:

```bash
# Simple build
./build.sh

# Advanced options
./build-advanced.sh --help
```
</details>

## ⌨️ Keyboard Shortcuts (iPad)

<details>
<summary><b>Navigation</b></summary>

| Shortcut | Action |
|----------|--------|
| `⌘ + 1-9` | Switch to board 1-9 |
| `⌘ + ↑/↓` | Navigate threads |
| `⌘ + Enter` | Open selected thread |
| `⌘ + W` | Close current view |
| `⌘ + R` | Refresh content |
</details>

<details>
<summary><b>Media</b></summary>

| Shortcut | Action |
|----------|--------|
| `Space` | Play/Pause video |
| `⌘ + G` | Open gallery view |
| `⌘ + S` | Save current media |
| `Esc` | Close media viewer |
</details>

<details>
<summary><b>Organization</b></summary>

| Shortcut | Action |
|----------|--------|
| `⌘ + D` | Add to favorites |
| `⌘ + F` | Search |
| `⌘ + K` | Quick switcher |
| `⌘ + ,` | Settings |
</details>

## 🤝 Contributing

We love contributions! Please read our [Contributing Guide](CONTRIBUTING.md) to get started.

<details>
<summary><b>Quick Start</b></summary>

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
</details>

## 🐛 Bug Reports & Feature Requests

Found a bug or have a feature idea? [Open an issue](https://github.com/newatlantisstudios/Channer/issues/new/choose)!

## 📚 Documentation

- [Development Guide](CLAUDE.md)
- [Keyboard Shortcuts](KEYBOARD_SHORTCUTS.md)
- [Theme Creation](DEVELOPMENT_PLAN.md)
- [API Reference](docs/API.md)


## 🙏 Acknowledgments

- Thanks to all our [contributors](https://github.com/newatlantisstudios/Channer/graphs/contributors)
- Special thanks to the open source community
- Icons by [Icons8](https://icons8.com)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">
  <b>Channer v3.0</b><br>
  Made with ❤️ for the iOS community<br>
  <br>
  <a href="https://github.com/newatlantisstudios/Channer/stargazers">⭐ Star us on GitHub!</a>
</div>
