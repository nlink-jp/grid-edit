import Foundation

/// Character encodings grid-edit reads and writes: UTF-8 (BOM optional),
/// Shift_JIS, and CP932 (Excel's default on Japanese Windows).
///
/// Detection strategy (identical to csv-editor's):
///  1. UTF-8 BOM present → `.utf8bom`
///  2. Bytes are valid UTF-8 → `.utf8`
///  3. Otherwise → `.cp932`
///
/// Shift_JIS proper and CP932 share a codec: on Darwin,
/// `String.Encoding.shiftJIS` maps to CFString's DOSJapanese (CP932)
/// converter, the same compatibility csv-editor gets from Go's
/// japanese.ShiftJIS. Users may still pick "Shift_JIS" explicitly on write
/// when a downstream tool insists on the strict label.
public enum TextEncoding: String, CaseIterable, Sendable {
    case utf8 = "UTF-8"
    case utf8bom = "UTF-8-BOM"
    case shiftJIS = "Shift_JIS"
    case cp932 = "CP932"

    static let utf8BOM: [UInt8] = [0xEF, 0xBB, 0xBF]

    /// Returns the most likely encoding for `data`.
    public static func detect(_ data: Data) -> TextEncoding {
        if data.starts(with: utf8BOM) {
            return .utf8bom
        }
        if String(data: data, encoding: .utf8) != nil {
            return .utf8
        }
        return .cp932
    }

    /// Converts `data` from this encoding to a String.
    public func decode(_ data: Data) throws -> String {
        let decoded: String?
        switch self {
        case .utf8:
            decoded = String(data: data, encoding: .utf8)
        case .utf8bom:
            let body = data.starts(with: Self.utf8BOM)
                ? data.dropFirst(Self.utf8BOM.count) : data
            decoded = String(data: body, encoding: .utf8)
        case .shiftJIS, .cp932:
            decoded = String(data: data, encoding: .shiftJIS)
        }
        guard let decoded else {
            throw CSVEngineError.decodeFailed(encoding: self)
        }
        return decoded
    }

    /// Converts a String to bytes in this encoding. `.utf8bom` prepends the
    /// EF BB BF marker.
    public func encode(_ string: String) throws -> Data {
        switch self {
        case .utf8:
            return Data(string.utf8)
        case .utf8bom:
            var out = Data(Self.utf8BOM)
            out.append(contentsOf: string.utf8)
            return out
        case .shiftJIS, .cp932:
            guard let data = string.data(using: .shiftJIS) else {
                throw CSVEngineError.encodeFailed(encoding: self)
            }
            return data
        }
    }
}

public enum CSVEngineError: Error, Equatable, LocalizedError {
    case decodeFailed(encoding: TextEncoding)
    case encodeFailed(encoding: TextEncoding)

    public var errorDescription: String? {
        switch self {
        case .decodeFailed(let encoding):
            return String(
                format: NSLocalizedString(
                    "The file could not be decoded as %@.", bundle: .coreResources, comment: ""),
                encoding.rawValue)
        case .encodeFailed(let encoding):
            return String(
                format: NSLocalizedString(
                    "The text contains characters not representable in %@.",
                    bundle: .coreResources, comment: ""),
                encoding.rawValue)
        }
    }
}
