import Foundation
import GridEditCore

extension Bundle {
    /// The app target's resource bundle (en/ja `Localizable.strings`).
    /// Resolved by `ResourceBundleLocator`, not by SwiftPM's `Bundle.module` —
    /// see `GridEditCore/ResourceBundle.swift` for why.
    static let appResources = ResourceBundleLocator.resolve(
        bundleName: "GridEdit_GridEdit")
}
