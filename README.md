# Channer v2.0 for iOS & iPadOS

A powerful, native iOS/iPadOS client for browsing image boards with advanced features, privacy-focused design, and seamless media handling. Built with Swift and UIKit for optimal performance across iPhone and iPad.

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

## 🌟 Core Features

### Seamless Browsing Experience

- Navigate through boards, threads, and replies with intuitive gestures
- Sort threads by reply count or newest first
- Adaptive UI that works perfectly on both iPhone and iPad

### Comprehensive Media Support

- **WebM & MP4 Video**: Full video playback with VLC integration
- **Image Gallery**: View all thread media in a dedicated gallery mode
- **Download Manager**: Save images and videos directly to your device
- **Thumbnail Grid**: Quick overview of all thread media

### Privacy & Security

- **Biometric Authentication**: FaceID/TouchID protection for sensitive features
- **No Tracking**: Zero user tracking or data collection
- **Offline Reading**: Cache threads for offline access with iCloud sync
- **Content Filtering**: Hide unwanted content with customizable filters

### Advanced Organization

- **Categorized Favorites**: Organize saved threads into custom categories
  - Color-coded categories with SF Symbol icons
  - Default categories: General, To Read, Important, Archives
  - Bulk operations and category management
- **Smart History**: Automatic thread visit tracking with search capability
- **Thread Watcher**: Get notifications for new replies on favorite threads

### Powerful Search & Discovery

- **Thread Search**: Search by title, content, and metadata
- **Search History**: Track and revisit previous searches
- **Saved Searches**: Save frequent searches for quick access
- **Board-Specific Search**: Search within specific boards or across all boards

### Customization & Themes

- **Advanced Theme Engine**: Create and edit custom themes
- **Light/Dark Mode**: Automatic or manual theme switching
- **Color Customization**: Personalize every aspect of the interface
- **iCloud Theme Sync**: Share themes across devices

## 📱 Screenshots


![Simulator Screenshot - iPhone 16 Pro Max - 2025-05-21 at 22 49 31](https://github.com/user-attachments/assets/3c589998-3b0a-4cd5-ba27-102d0e2cdd7b)
![Simulator Screenshot - iPhone 16 Pro Max - 2025-05-21 at 22 49 35](https://github.com/user-attachments/assets/a62eedd6-bf1c-49f4-ad4f-c9cabdd681d5)
![Simulator Screenshot - iPhone 16 Pro Max - 2025-05-21 at 22 49 39](https://github.com/user-attachments/assets/53162278-c0ff-459f-8209-837418a1d666)
![Simulator Screenshot - iPhone 16 Pro Max - 2025-05-21 at 22 49 46](https://github.com/user-attachments/assets/ee980155-6595-4a55-bf5f-994b9e00ce1b)
![Simulator Screenshot - iPhone 16 Pro Max - 2025-05-21 at 22 49 49](https://github.com/user-attachments/assets/1e08fdde-56a7-4010-a6e7-472f648559e3)
![Simulator Screenshot - iPhone 16 Pro Max - 2025-05-21 at 22 52 14](https://github.com/user-attachments/assets/9fa5140d-fb20-44f5-b9d1-7649ccea92c6)
![Simulator Screenshot - iPhone 16 Pro Max - 2025-05-21 at 22 52 21](https://github.com/user-attachments/assets/c9e5d8c9-c8fc-4eb2-a0af-5c0c059a0942)
![Simulator Screenshot - iPhone 16 Pro Max - 2025-05-21 at 22 52 36](https://github.com/user-attachments/assets/65802ea9-032e-4563-b920-ab6d9b7b2c86)


## 🛠️ Technical Specifications

### Requirements

- **iOS/iPadOS**: 15.6 or later
- **Architecture**: Universal (iPhone/iPad)
- **Storage**: Varies with cached content

### Built With

- **Language**: Swift
- **Framework**: UIKit
- **Architecture**: MVC with modern Swift patterns
- **Dependencies**: CocoaPods

### Key Dependencies

- **Alamofire**: High-performance HTTP networking
- **SwiftyJSON**: Elegant JSON parsing
- **Kingfisher**: Powerful image loading and caching
- **VLCKit**: Advanced media playback
- **FFmpeg**: Media processing and conversion

## 🚀 Installation

### AltStore

Add our repository to AltStore for easy installation and updates:

```
https://newatlantisstudios.github.io/altstore-repo/altStoreApps.json
```

### Building from Source

1. Clone the repository
2. Install dependencies: `pod install`
3. Open `Channer.xcworkspace` in Xcode
4. Build and run on your device

For detailed build instructions, see our [development documentation](CLAUDE.md).

## 🔧 Build Scripts

The project includes several build scripts for different scenarios:

```bash
# Simple build with clean output
./build.sh

# Advanced build with options
./build-advanced.sh -c -r  # Clean release build
./build-advanced.sh -v     # Verbose output

# Quick CI/CD build
./test-build.sh
```

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## 📞 Support

Having issues? Check our documentation or create an issue on GitHub.

---

**Channer v2.0** - The ultimate image board client for iOS and iPadOS. Privacy-focused, feature-rich, and built for performance.
