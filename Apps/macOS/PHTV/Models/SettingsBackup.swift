import Foundation

struct SettingsBackup: Codable, Sendable {
    static let currentVersion = "3.0"
    let version: String
    let exportDate: String
    var settings: [String: AnyCodableValue]?
    var macros: [MacroItem]?
    var macroCategories: [MacroCategory]?
    var excludedApps: [String]?
    var excludedAppsV2: [ExcludedApp]?
    var sendKeyStepByStepApps: [ExcludedApp]?
    var upperCaseExcludedApps: [ExcludedApp]?
    var macroExcludedApps: [MacroExcludedApp]? = nil
    var clipboardHistory: [ClipboardHistoryItem]? = nil
    var clipboardLibrary: ClipboardSavedLibrary? = nil
    var clipboardFiles: [ClipboardBackupFile]? = nil
    var smartSwitchData: Data? = nil
    var customDictionary: [[String: AnyCodableValue]]? = nil

    var externalFileReferenceCount: Int {
        let assets = Set((clipboardFiles ?? []).map { "\($0.itemID):\($0.referenceIndex)" })
        return (clipboardHistory ?? []).reduce(0) { count, item in
            if let refs = item.fileReferences {
                return count + refs.indices.filter { !assets.contains("\(item.id):\($0)") }.count
            }
            return count + (item.filePaths?.count ?? 0)
        }
    }
}

/// Cached files owned by PHTV travel with the backup. External references remain
/// references; exporting never recursively reads arbitrary folders on the machine.
struct ClipboardBackupFile: Codable, Sendable {
    var itemID: UUID
    var referenceIndex: Int
    var data: Data
}

enum BackupError: LocalizedError, Equatable {
    case invalid(String)
    case rollbackFailed

    var errorDescription: String? {
        switch self {
        case .invalid(let reason): return "Bản sao lưu không hợp lệ: \(reason)"
        case .rollbackFailed:
            return "Chưa khôi phục được dữ liệu cũ. Bản phục hồi được giữ lại; hãy kiểm tra dung lượng và quyền ghi rồi mở lại PHTV."
        }
    }
}

indirect enum AnyCodableValue: Codable, Sendable {
    case integer(Int), double(Double), boolean(Bool), string(String)
    case array([AnyCodableValue]), dictionary([String: AnyCodableValue])

    var value: Any {
        switch self {
        case .integer(let v): v
        case .double(let v): v
        case .boolean(let v): v
        case .string(let v): v
        case .array(let v): v.map(\.value)
        case .dictionary(let v): v.mapValues(\.value)
        }
    }

    init(_ value: Any) throws {
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .boolean(number.boolValue)
            } else if ["f", "d"].contains(String(cString: number.objCType)) {
                guard number.doubleValue.isFinite else { throw BackupError.invalid("số không hữu hạn") }
                self = .double(number.doubleValue)
            } else {
                self = .integer(number.intValue)
            }
        } else if let text = value as? String {
            self = .string(text)
        } else if let array = value as? [Any] {
            self = .array(try array.map { try Self($0) })
        } else if let dictionary = value as? [String: Any] {
            self = .dictionary(try dictionary.mapValues { try Self($0) })
        } else {
            throw BackupError.invalid("kiểu dữ liệu không được hỗ trợ")
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { self = .boolean(v) }
        else if let v = try? c.decode(Int.self) { self = .integer(v) }
        else if let v = try? c.decode(Double.self), v.isFinite { self = .double(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([AnyCodableValue].self) { self = .array(v) }
        else if let v = try? c.decode([String: AnyCodableValue].self) { self = .dictionary(v) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported backup value") }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .integer(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .boolean(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .dictionary(let v): try c.encode(v)
        }
    }
}
