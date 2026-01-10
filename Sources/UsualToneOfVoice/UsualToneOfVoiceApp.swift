import SwiftUI
import AppKit

@main
struct UsualToneOfVoiceApp: App {
    @StateObject private var model = AppModel()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: model, settings: model.settings)
        } label: {
            let showSystemIcon = model.shouldShowSystemIcon
            let customIcon = MenuBarIconProvider.image()
            if showSystemIcon || customIcon == nil {
                Image(systemName: model.menuIconName)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityLabel("Usual Tone of Voice")
            } else if let image = customIcon {
                Image(nsImage: image)
                    .accessibilityLabel("Usual Tone of Voice")
            }
        }

    }
}
