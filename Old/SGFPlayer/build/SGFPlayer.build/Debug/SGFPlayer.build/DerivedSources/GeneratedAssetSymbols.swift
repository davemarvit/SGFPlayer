import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "board_kaya" asset catalog image resource.
    static let boardKaya = DeveloperToolsSupport.ImageResource(name: "board_kaya", bundle: resourceBundle)

    /// The "clam_01" asset catalog image resource.
    static let clam01 = DeveloperToolsSupport.ImageResource(name: "clam_01", bundle: resourceBundle)

    /// The "clam_02" asset catalog image resource.
    static let clam02 = DeveloperToolsSupport.ImageResource(name: "clam_02", bundle: resourceBundle)

    /// The "clam_03" asset catalog image resource.
    static let clam03 = DeveloperToolsSupport.ImageResource(name: "clam_03", bundle: resourceBundle)

    /// The "clam_04" asset catalog image resource.
    static let clam04 = DeveloperToolsSupport.ImageResource(name: "clam_04", bundle: resourceBundle)

    /// The "clam_05" asset catalog image resource.
    static let clam05 = DeveloperToolsSupport.ImageResource(name: "clam_05", bundle: resourceBundle)

    /// The "go_lid_1" asset catalog image resource.
    static let goLid1 = DeveloperToolsSupport.ImageResource(name: "go_lid_1", bundle: resourceBundle)

    /// The "go_lid_2" asset catalog image resource.
    static let goLid2 = DeveloperToolsSupport.ImageResource(name: "go_lid_2", bundle: resourceBundle)

    /// The "stone_black" asset catalog image resource.
    static let stoneBlack = DeveloperToolsSupport.ImageResource(name: "stone_black", bundle: resourceBundle)

    /// The "tatami" asset catalog image resource.
    static let tatami = DeveloperToolsSupport.ImageResource(name: "tatami", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "board_kaya" asset catalog image.
    static var boardKaya: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .boardKaya)
#else
        .init()
#endif
    }

    /// The "clam_01" asset catalog image.
    static var clam01: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .clam01)
#else
        .init()
#endif
    }

    /// The "clam_02" asset catalog image.
    static var clam02: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .clam02)
#else
        .init()
#endif
    }

    /// The "clam_03" asset catalog image.
    static var clam03: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .clam03)
#else
        .init()
#endif
    }

    /// The "clam_04" asset catalog image.
    static var clam04: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .clam04)
#else
        .init()
#endif
    }

    /// The "clam_05" asset catalog image.
    static var clam05: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .clam05)
#else
        .init()
#endif
    }

    /// The "go_lid_1" asset catalog image.
    static var goLid1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .goLid1)
#else
        .init()
#endif
    }

    /// The "go_lid_2" asset catalog image.
    static var goLid2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .goLid2)
#else
        .init()
#endif
    }

    /// The "stone_black" asset catalog image.
    static var stoneBlack: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stoneBlack)
#else
        .init()
#endif
    }

    /// The "tatami" asset catalog image.
    static var tatami: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .tatami)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "board_kaya" asset catalog image.
    static var boardKaya: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .boardKaya)
#else
        .init()
#endif
    }

    /// The "clam_01" asset catalog image.
    static var clam01: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .clam01)
#else
        .init()
#endif
    }

    /// The "clam_02" asset catalog image.
    static var clam02: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .clam02)
#else
        .init()
#endif
    }

    /// The "clam_03" asset catalog image.
    static var clam03: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .clam03)
#else
        .init()
#endif
    }

    /// The "clam_04" asset catalog image.
    static var clam04: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .clam04)
#else
        .init()
#endif
    }

    /// The "clam_05" asset catalog image.
    static var clam05: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .clam05)
#else
        .init()
#endif
    }

    /// The "go_lid_1" asset catalog image.
    static var goLid1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .goLid1)
#else
        .init()
#endif
    }

    /// The "go_lid_2" asset catalog image.
    static var goLid2: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .goLid2)
#else
        .init()
#endif
    }

    /// The "stone_black" asset catalog image.
    static var stoneBlack: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stoneBlack)
#else
        .init()
#endif
    }

    /// The "tatami" asset catalog image.
    static var tatami: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .tatami)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

