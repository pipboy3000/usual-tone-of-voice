// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UsualToneOfVoice",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "UsualToneOfVoice", targets: ["UsualToneOfVoice"])
    ],
    targets: [
        .executableTarget(
            name: "UsualToneOfVoice",
            path: "Sources/UsualToneOfVoice",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "UsualToneOfVoiceTests",
            dependencies: ["UsualToneOfVoice"],
            path: "Tests/UsualToneOfVoiceTests"
        )
    ]
)
