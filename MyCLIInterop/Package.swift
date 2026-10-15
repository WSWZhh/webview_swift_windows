// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "MyCLIInterop",
    products: [
        .library(name: "SwiftWebView", targets: ["SwiftWebView"]),
        .executable(name: "MyCLIInterop", targets: ["MyCLIInterop"]),
    ],
    targets: [
        .target(
            name: "WebViewBridge",
            path: "Sources/WebViewBridge",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("../../Vendor/webview/core/include"),
                .headerSearchPath("../../Vendor/webview2"),
                .define("WEBVIEW_STATIC"),
            ],
            linkerSettings: [
                .linkedLibrary("advapi32", .when(platforms: [.windows])),
                .linkedLibrary("ole32", .when(platforms: [.windows])),
                .linkedLibrary("shell32", .when(platforms: [.windows])),
                .linkedLibrary("shlwapi", .when(platforms: [.windows])),
                .linkedLibrary("user32", .when(platforms: [.windows])),
                .linkedLibrary("version", .when(platforms: [.windows])),
            ]
        ),
        .executableTarget(
            name: "MyCLIInterop",
            dependencies: ["SwiftWebView"],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
            ]
        ),
        .target(
            name: "SwiftWebView",
            dependencies: ["WebViewBridge"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
