// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "BaizeBookCore", platforms: [.macOS(.v14)], products: [.library(name: "BaizeBookCore", targets: ["BaizeBookCore"])], targets: [.target(name: "BaizeBookCore", path: "Shared", exclude: ["Connectivity.swift"]), .testTarget(name: "BaizeBookCoreTests", dependencies: ["BaizeBookCore"], path: "Tests")])
