// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JePDF",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "JePDF", targets: ["JePDF"]),
        .executable(name: "PDFCoreChecks", targets: ["PDFCoreChecks"])
    ],
    targets: [
        .target(name: "PDFCore"),
        .executableTarget(name: "JePDF", dependencies: ["PDFCore"]),
        .executableTarget(name: "PDFCoreChecks", dependencies: ["PDFCore"], path: "Tests/PDFCoreTests")
    ]
)
