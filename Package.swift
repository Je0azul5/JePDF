// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PDFStudio",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PDFStudio", targets: ["PDFStudio"]),
        .executable(name: "PDFCoreChecks", targets: ["PDFCoreChecks"])
    ],
    targets: [
        .target(name: "PDFCore"),
        .executableTarget(name: "PDFStudio", dependencies: ["PDFCore"]),
        .executableTarget(name: "PDFCoreChecks", dependencies: ["PDFCore"], path: "Tests/PDFCoreTests")
    ]
)
