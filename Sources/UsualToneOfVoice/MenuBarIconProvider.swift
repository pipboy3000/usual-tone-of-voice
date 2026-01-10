import AppKit

enum MenuBarIconProvider {
    private static var cached: NSImage? = loadImage()

    static func image() -> NSImage? {
        cached
    }

    private static func loadImage() -> NSImage? {
        let candidates: [(String, String?)] = [
            ("menubar-icon", "pdf"),
            ("menubar-icon", "png"),
            ("menubar-icon", "tiff"),
            ("menubar-icon", "icns"),
            ("menubar-icon", nil)
        ]

        for (name, ext) in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                if let image = NSImage(contentsOf: url) {
                    image.isTemplate = true
                    return image
                }
            }
        }

        #if SWIFT_PACKAGE
        for (name, ext) in candidates {
            if let url = Bundle.module.url(forResource: name, withExtension: ext) {
                if let image = NSImage(contentsOf: url) {
                    image.isTemplate = true
                    return image
                }
            }
        }
        #endif

        return nil
    }
}
