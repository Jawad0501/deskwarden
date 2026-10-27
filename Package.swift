// swift-tools-version: 6.0

import PackageDescription

let infoPlistPath = #filePath
    .split(separator: "/", omittingEmptySubsequences: false)
    .dropLast()
    .joined(separator: "/") + "/Sources/DeskwardenApp/Info.plist"

let package = Package(
    name: "Deskwarden",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Deskwarden",
            targets: ["Deskwarden"]
        ),
        .executable(
            name: "deskwarden",
            targets: ["DeskwardenApp"]
        )
    ],
    targets: [
        .target(
            name: "Deskwarden"
        ),
        .executableTarget(
            name: "DeskwardenApp",
            dependencies: ["Deskwarden"],
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", infoPlistPath
                ])
            ]
        ),
        .testTarget(
            name: "DeskwardenTests",
            dependencies: ["Deskwarden"]
        )
    ]
)
