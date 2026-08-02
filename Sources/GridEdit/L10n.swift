import Foundation

/// Localized string for `key` from this target's resource bundle.
/// Keys are the English source strings (en.lproj is an identity table).
func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .appResources, comment: "")
}

/// Localized, count-aware menu title: `oneKey` verbatim for a single item,
/// `otherKey` as a format taking the count otherwise. (Full .stringsdict
/// plural rules are overkill for en/ja, which is our whole scope.)
func LPlural(_ count: Int, one oneKey: String, other otherKey: String) -> String {
    count == 1 ? L(oneKey) : String(format: L(otherKey), count)
}
