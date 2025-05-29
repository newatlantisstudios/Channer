<div align="center">
  <img src="App Images/iOS/iOS-1.png" alt="Channer Logo" width="120">
  
  # Channer v2.0
  
  ### The Ultimate Image Board Client for iOS & iPadOS
  
  [![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20iPadOS-blue.svg)](https://developer.apple.com/ios/)
  [![iOS Version](https://img.shields.io/badge/iOS-15.6%2B-brightgreen.svg)](https://developer.apple.com/ios/)
  [![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org/)
  [![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)
  [![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()
  
  **A powerful, native iOS/iPadOS client for browsing image boards with advanced features, privacy-focused design, and seamless media handling.**
  
  [Features](#-features) • [Screenshots](#-screenshots) • [Installation](#-installation) • [Build](#-building-from-source) • [Contributing](#-contributing)
</div>

---

## ✨ Why Channer?

- 🚀 **Native Performance**: Built with Swift for blazing-fast browsing
- 🔒 **Privacy First**: No tracking, no analytics, your data stays yours
- 🎨 **Beautiful Design**: Adaptive UI that looks great on any device
- 📱 **Universal App**: One app for iPhone and iPad with optimized interfaces
- 🌐 **Offline Support**: Browse cached threads without internet
- ⚡ **Smart Features**: Advanced search, filtering, and organization tools

## 🆕 What's New in v2.0

### Enhanced Organization & Sync

- **📂 Categorized Favorites**: Organize saved threads into custom categories with color-coding and icons
- **☁️ iCloud Sync**: Seamlessly sync settings, themes, and preferences across all your devices
- **🔍 Advanced Thread Search**: Search through threads with history tracking and saved searches

### Improved Media Experience

- **🎥 Enhanced Video Playback**: Better WebM and MP4 support with improved gallery view
- **🖼️ High-Quality Thumbnails**: Optional high-resolution preview images for better browsing
- **⚡ Smart Preloading**: Configurable media preloading for smoother browsing

### User Interface & Accessibility

- **🎨 Advanced Theming**: Comprehensive theme customization with live editing
- **⌨️ iPad Keyboard Shortcuts**: Full keyboard navigation support for iPad users
- **📱 Display Mode Toggle**: Switch between table and grid view for boards
- **🔧 Content Filtering**: Advanced keyword, poster, and image filtering system

### Developer & Build Improvements

- **🔨 Enhanced Build System**: Multiple build scripts with clean, formatted output
- **📦 Updated Dependencies**: Migrated to modern FFmpeg implementation
- **🧪 Better Testing Framework**: Improved test structure and CI/CD support

## 🌟 Features

<table>
<tr>
<td width="50%">

### 📱 Browsing Experience

- **Intuitive Navigation**: Swipe gestures and smart controls
- **Thread Sorting**: By reply count, date, or custom filters
- **Adaptive Layout**: Optimized for every screen size
- **Quick Actions**: 3D Touch and context menus
- **Split View**: Multitasking on iPad

### 🎬 Media Handling

- **WebM & MP4 Support**: Native video playback
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
- **Smart Suggestions**: AI-powered recommendations
- **Export Results**: Share or save search results

### 🎨 Customization

- **Theme Editor**: Create custom themes
- **Dynamic Themes**: Auto light/dark switching
- **Font Options**: Size and style preferences
- **Layout Modes**: List, grid, or compact view
- **Gesture Controls**: Customize swipe actions

</td>
</tr>
</table>

## 📱 Screenshots

### iPhone
<div align="center">
  <img src="https://github.com/user-attachments/assets/3c589998-3b0a-4cd5-ba27-102d0e2cdd7b" width="200" alt="Board List">
  <img src="https://github.com/user-attachments/assets/a62eedd6-bf1c-49f4-ad4f-c9cabdd681d5" width="200" alt="Thread View">
  <img src="https://github.com/user-attachments/assets/53162278-c0ff-459f-8209-837418a1d666" width="200" alt="Reply View">
  <img src="https://github.com/user-attachments/assets/ee980155-6595-4a55-bf5f-994b9e00ce1b" width="200" alt="Settings">
</div>

<div align="center">
  <img src="https://github.com/user-attachments/assets/1e08fdde-56a7-4010-a6e7-472f648559e3" width="200" alt="Media Gallery">
  <img src="https://github.com/user-attachments/assets/9fa5140d-fb20-44f5-b9d1-7649ccea92c6" width="200" alt="Theme Editor">
  <img src="https://github.com/user-attachments/assets/c9e5d8c9-c8fc-4eb2-a0af-5c0c059a0942" width="200" alt="Search">
  <img src="https://github.com/user-attachments/assets/65802ea9-032e-4563-b920-ab6d9b7b2c86" width="200" alt="Categories">
</div>

### iPad
<div align="center">
  <img src="App Images/iPadOS/iPadOS-1.png" width="400" alt="iPad Split View">
  <img src="App Images/iPadOS/iPadOS-2.png" width="400" alt="iPad Gallery">
</div>


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
- **Architecture**: MVC + Coordinators
- **Package Manager**: CocoaPods
- **Minimum Deployment**: iOS 15.6
</details>

<details>
<summary><b>Dependencies</b></summary>

| Library | Purpose | Version |
|---------|---------|----------|
| Alamofire | Networking | Latest |
| SwiftyJSON | JSON Parsing | Latest |
| Kingfisher | Image Loading | Latest |
| VLCKit | Video Playback | 4.0.0a6 |
| FFmpeg | Media Processing | Latest |
</details>

## 🚀 Installation

### Option 1: AltStore (Recommended)

Add our repository to AltStore for automatic updates:

```
https://newatlantisstudios.github.io/altstore-repo/altStoreApps.json
```

<details>
<summary><b>AltStore Installation Steps</b></summary>

1. Install [AltStore](https://altstore.io) on your device
2. Open AltStore and go to **Browse** → **Sources**
3. Tap **+** and add the repository URL above
4. Find Channer in the store and tap **Install**
5. Enjoy automatic updates!
</details>

### Option 2: Direct IPA

Download the latest IPA from our [Releases](https://github.com/yourusername/Channer/releases) page.

### Option 3: TestFlight

[Join our TestFlight beta](https://testflight.apple.com/join/XXXXXXXX) for early access to new features.

## 🔨 Building from Source

<details>
<summary><b>Prerequisites</b></summary>

- macOS 12.0 or later
- Xcode 14.0 or later
- CocoaPods 1.11.0 or later
- Active Apple Developer account (for device builds)
</details>

<details>
<summary><b>Build Instructions</b></summary>

```bash
# Clone the repository
git clone https://github.com/yourusername/Channer.git
cd Channer

# Install dependencies
pod install

# Open in Xcode
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

Found a bug or have a feature idea? [Open an issue](https://github.com/yourusername/Channer/issues/new/choose)!

## 📚 Documentation

- [Development Guide](CLAUDE.md)
- [Keyboard Shortcuts](KEYBOARD_SHORTCUTS.md)
- [Theme Creation](DEVELOPMENT_PLAN.md)
- [API Reference](docs/API.md)

## 📞 Support

- 📧 Email: support@channer.app
- 💬 Discord: [Join our server](https://discord.gg/XXXXXX)
- 🐦 Twitter: [@ChannerApp](https://twitter.com/ChannerApp)

## 🙏 Acknowledgments

- Thanks to all our [contributors](https://github.com/yourusername/Channer/graphs/contributors)
- Special thanks to the open source community
- Icons by [Icons8](https://icons8.com)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">
  <b>Channer v2.0</b><br>
  Made with ❤️ for the iOS community<br>
  <br>
  <a href="https://github.com/yourusername/Channer/stargazers">⭐ Star us on GitHub!</a>
</div>
