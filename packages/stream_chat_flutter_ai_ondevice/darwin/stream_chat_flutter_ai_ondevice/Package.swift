// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "stream_chat_flutter_ai_ondevice",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "stream-chat-flutter-ai-ondevice", targets: ["stream_chat_flutter_ai_ondevice"])
    ],
    // No FlutterFramework dependency: Flutter only generates that package from 3.44, and links the
    // engine into plugins without it.
    dependencies: [],
    targets: [
        .target(
            name: "stream_chat_flutter_ai_ondevice",
            dependencies: []
        )
    ]
)
