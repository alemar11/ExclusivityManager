// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "ExclusivityManager",
  platforms: [.macOS(.v10_13), .iOS(.v11), .tvOS(.v11), .watchOS(.v4)],
  products: [
    // Products define the executables and libraries produced by a package, and make them visible to other packages.
    .library(
      name: "ExclusivityManager",
      targets: ["ExclusivityManager"]),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(
      name: "ExclusivityManager",
      dependencies: []),
    .testTarget(
      name: "ExclusivityManagerTests",
      dependencies: ["ExclusivityManager"]),
  ],
  swiftLanguageVersions: [.v5]
)
