// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SVNMate",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SVNMate",
            targets: ["SVNMate"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SVNMate",
            dependencies: [],
            path: "SVNMate/Sources",
            exclude: [
                "Info.plist",
                "SVNMate.entitlements"
            ]
        )
    ]
)
