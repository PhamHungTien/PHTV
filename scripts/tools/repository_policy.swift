#!/usr/bin/env swift

import Foundation

struct PolicyFailure: Error, CustomStringConvertible {
    let description: String
}

let scriptURL = URL(fileURLWithPath: #filePath)
let root = scriptURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let fileManager = FileManager.default
var failures: [String] = []

func fail(_ message: String) { failures.append(message) }
func contents(_ url: URL) -> String { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }
func files(under url: URL, extension wanted: String? = nil) -> [URL] {
    guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
    return enumerator.compactMap { item in
        guard let url = item as? URL, (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
        return wanted == nil || url.pathExtension == wanted ? url : nil
    }
}

// GitHub Actions must be immutable references.
for workflow in files(under: root.appendingPathComponent(".github/workflows"), extension: "yml") {
    for (lineNumber, line) in contents(workflow).components(separatedBy: .newlines).enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("uses:") else { continue }
        let reference = trimmed.dropFirst("uses:".count).split(separator: "#", maxSplits: 1)[0].trimmingCharacters(in: .whitespaces)
        if reference.hasPrefix("./") { continue }
        let parts = reference.split(separator: "@", maxSplits: 1)
        let revision = parts.count == 2 ? String(parts[1]) : ""
        if revision.range(of: #"^[0-9a-f]{40}$"#, options: .regularExpression) == nil {
            fail("\(workflow.path.replacingOccurrences(of: root.path + "/", with: "")):\(lineNumber + 1) must pin a full action SHA")
        }
    }
}

// Sparkle lockfile must be checked in and exact.
let resolvedURL = root.appendingPathComponent("App/PHTV.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
do {
    let data = try Data(contentsOf: resolvedURL)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let pins = object?["pins"] as? [[String: Any]] ?? []
    guard let sparkle = pins.first(where: { $0["identity"] as? String == "sparkle" }),
          let state = sparkle["state"] as? [String: Any],
          state["version"] as? String == "2.8.1",
          let revision = state["revision"] as? String,
          revision.range(of: #"^[0-9a-f]{40}$"#, options: .regularExpression) != nil else {
        throw PolicyFailure(description: "Sparkle is not pinned to 2.8.1 with a full revision")
    }
} catch { fail("Package.resolved: \(error)") }

// Privacy declarations for the online Picker boundary.
do {
    let data = try Data(contentsOf: root.appendingPathComponent("App/PHTV/PrivacyInfo.xcprivacy"))
    let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    let entries = plist?["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []
    let declared = Set(entries.compactMap { $0["NSPrivacyCollectedDataType"] as? String })
    let expected: Set<String> = [
        "NSPrivacyCollectedDataTypeUserID", "NSPrivacyCollectedDataTypeSearchHistory",
        "NSPrivacyCollectedDataTypeProductInteraction", "NSPrivacyCollectedDataTypeAdvertisingData",
        "NSPrivacyCollectedDataTypeCoarseLocation",
    ]
    if !expected.isSubset(of: declared) { fail("PrivacyInfo.xcprivacy is missing Picker data declarations") }
} catch { fail("PrivacyInfo.xcprivacy: \(error)") }

let swiftFiles = files(under: root.appendingPathComponent("App/PHTV"), extension: "swift")
let allSwift = swiftFiles.map(contents).joined(separator: "\n")
let nslogCount = allSwift.components(separatedBy: "NSLog(").count - 1
let uncheckedCount = allSwift.components(separatedBy: "@unchecked Sendable").count - 1
if nslogCount > 364 { fail("Legacy NSLog budget grew to \(nslogCount) (maximum 364)") }
if uncheckedCount > 36 { fail("@unchecked Sendable budget grew to \(uncheckedCount) (maximum 36)") }
if allSwift.contains("nonisolated(unsafe)") { fail("nonisolated(unsafe) global state is prohibited") }
for line in allSwift.components(separatedBy: .newlines) where line.contains("PHTVLogger") || line.contains("NSLog") {
    for value in [".shortcut", ".expansion", "trimmedCode", "trimmedName", "releaseNotes.prefix", "searchText"]
    where line.contains(value) {
        fail("A log statement includes user content via \(value)")
    }
}

let sensitivePickerFiles = [
    "App/PHTV/Data/KlipyAPIClient.swift", "App/PHTV/Services/MediaStorageHelper.swift",
    "App/PHTV/UI/Picker/ContentViews/GIFOnlyView.swift",
    "App/PHTV/UI/Picker/ContentViews/StickerOnlyView.swift",
    "App/PHTV/UI/Picker/ContentViews/UnifiedContentView.swift",
]
for relativePath in sensitivePickerFiles {
    let logged = contents(root.appendingPathComponent(relativePath)).components(separatedBy: .newlines)
        .filter { $0.contains("NSLog") || $0.contains("PHTVLogger") }.joined(separator: "\n")
    for value in ["fullURL", ".slug", ".lastPathComponent", ".absoluteString", "ad.targetURL"] where logged.contains(value) {
        fail("\(relativePath) logs sensitive value \(value)")
    }
}

// Local Markdown links must resolve.
var markdown = files(under: root, extension: "md")
markdown.removeAll { $0.path.contains("/.build/") || $0.path.contains("/.git/") }
let linkRegex = try NSRegularExpression(pattern: #"(?<!!)\[[^]]*\]\(([^)]+)\)"#)
for document in markdown {
    let text = contents(document)
    for match in linkRegex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
        guard let range = Range(match.range(at: 1), in: text) else { continue }
        var target = String(text[range]).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        if target.hasPrefix("#") { continue }
        target = target.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
        if target.isEmpty || target.hasPrefix("http://") || target.hasPrefix("https://") || target.hasPrefix("mailto:") { continue }
        let resolved = URL(fileURLWithPath: target, relativeTo: document.deletingLastPathComponent()).standardizedFileURL
        if !fileManager.fileExists(atPath: resolved.path) {
            fail("Broken Markdown link: \(document.lastPathComponent) -> \(target)")
        }
    }
}

// Local tooling is Swift-only; GitHub Actions may still use YAML run blocks.
let prohibited = files(under: root).filter {
    ($0.pathExtension == "py" || $0.pathExtension == "sh")
        && !$0.path.contains("/.build/") && !$0.path.contains("/.git/")
}
if !prohibited.isEmpty { fail("Non-Swift local tools remain: \(prohibited.map(\.lastPathComponent).joined(separator: ", "))") }
if !contents(root.appendingPathComponent(".gitignore")).components(separatedBy: .newlines).contains(".codex/") {
    fail(".codex/ must stay ignored")
}

if failures.isEmpty {
    print("Repository policy checks passed")
} else {
    failures.forEach { fputs("policy: \($0)\n", stderr) }
    exit(1)
}
