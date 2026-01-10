// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UsualToneOfVoice",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "UsualToneOfVoice", targets: ["UsualToneOfVoice"])
    ],
    targets: [
        .binaryTarget(
            name: "whisper",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.7.5/whisper-v1.7.5-xcframework.zip",
            checksum: "c7faeb328620d6012e130f3d705c51a6ea6c995605f2df50f6e1ad68c59c6c4a"
        ),
        .executableTarget(
            name: "UsualToneOfVoice",
            dependencies: ["whisper"],
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
