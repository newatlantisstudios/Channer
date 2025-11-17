# Uncomment the next line to define a global platform for your project
platform :ios, '18.0'

use_frameworks!
source 'https://github.com/CocoaPods/Specs.git'

target 'Channer' do
  # Pods for Channer
  pod 'SwiftyJSON'
  pod 'Alamofire'
  pod 'Kingfisher'
  pod 'VLCKit', '4.0.0a6'
  # Original pod is retired
  # pod 'ffmpeg-kit-ios-full', '~> 6.0'

  # Using the system ffmpeg
  # No FFmpeg pod - will use the system's ffmpeg

  # Unit tests need access to pods because they test app code that uses them
  target 'ChannerTests' do
    inherit! :search_paths
    # Pods for testing
  end
end

# UI tests should NOT link against app dependencies
target 'ChannerUITests' do
  # UI tests only need XCTest, not the app's frameworks
end
