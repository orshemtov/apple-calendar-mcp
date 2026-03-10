// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "apple-calendar-mcp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "AppleCalendarMCP", targets: ["AppleCalendarMCP"]),
        .executable(name: "apple-calendar-mcp", targets: ["apple-calendar-mcp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0")
    ],
    targets: [
        .target(
            name: "AppleCalendarMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/AppleCalendarMCP",
            exclude: [
                "Executable"
            ],
            linkerSettings: [
                .linkedFramework("EventKit"),
                .linkedFramework("CoreLocation"),
            ]
        ),
        .executableTarget(
            name: "apple-calendar-mcp",
            dependencies: [
                "AppleCalendarMCP"
            ],
            path: "Sources/AppleCalendarMCP/Executable"
        ),
        .testTarget(
            name: "AppleCalendarMCPTests",
            dependencies: [
                "AppleCalendarMCP",
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
    ],
)
