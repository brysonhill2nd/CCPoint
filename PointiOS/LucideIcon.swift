#if canImport(UIKit)
import SwiftUI
import LucideIcons
import UIKit

/// Lightweight wrapper around the Lucide asset catalog so SwiftUI views can treat
/// every icon as a tintable template image.
struct LucideIcon: Hashable {
    private let name: String
    fileprivate let uiImage: UIImage

    private init(name: String, image: UIImage) {
        self.name = name
        self.uiImage = image
    }

    /// Dynamically loads an icon from the Lucide catalog.
    static func named(_ name: String) -> LucideIcon? {
        guard let image = UIImage(lucideId: name) else {
            return nil
        }
        return LucideIcon(name: name, image: image)
    }

    static let activity = LucideIcon(name: "activity", image: Lucide.activity)
    static let target = LucideIcon(name: "target", image: Lucide.target)
    static let trophy = LucideIcon(name: "trophy", image: Lucide.trophy)
    static let x = LucideIcon(name: "x", image: Lucide.x)
}

extension Image {
    init(icon: LucideIcon) {
        self = Image(uiImage: icon.uiImage).renderingMode(.template)
    }
}
#endif
