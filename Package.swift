// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FireKit",
    platforms: [
        .macOS(.v11),
        .iOS(.v16),
        .watchOS(.v8),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "FireKit",
            targets: ["FireKit"]),
    ], 
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.24.0")
    ],
    targets: [
        .target(
            name: "FireKit",
            dependencies: [
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk")
            ]
        ),
        .testTarget(
            name: "FireKitTests",
            dependencies: [
                "FireKit",
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk")
            ]
        ),
    ]
)
