#!/usr/bin/env swift

import Foundation

enum ReleaseNotesError: Error, CustomStringConvertible {
    case message(String)
    var description: String { if case .message(let value) = self { return value }; return "Unknown error" }
}

struct ListItem {
    var text: String
    var children: [ListItem] = []
}

func regex(_ pattern: String, options: NSRegularExpression.Options = []) throws -> NSRegularExpression {
    try NSRegularExpression(pattern: pattern, options: options)
}

func firstMatch(_ pattern: String, in value: String, options: NSRegularExpression.Options = []) throws -> [String]? {
    let expression = try regex(pattern, options: options)
    let range = NSRange(value.startIndex..., in: value)
    guard let match = expression.firstMatch(in: value, range: range) else { return nil }
    return (0..<match.numberOfRanges).map { index in
        let matchRange = match.range(at: index)
        guard matchRange.location != NSNotFound, let range = Range(matchRange, in: value) else { return "" }
        return String(value[range])
    }
}

func releaseSections(_ changelog: String) throws -> [(version: String, body: String)] {
    let lines = changelog.components(separatedBy: .newlines)
    let heading = try regex(#"^## \[([^]]+)\](?:\s+-\s+.+)?$"#)
    var starts: [(Int, String)] = []
    for (index, line) in lines.enumerated() {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = heading.firstMatch(in: line, range: range),
              let versionRange = Range(match.range(at: 1), in: line) else { continue }
        starts.append((index, String(line[versionRange])))
    }
    return starts.enumerated().map { offset, entry in
        let end = offset + 1 < starts.count ? starts[offset + 1].0 : lines.count
        return (entry.1, lines[(entry.0 + 1)..<end].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

func latestReleaseVersion(_ changelog: String) throws -> String {
    guard let version = try releaseSections(changelog).first(where: { $0.version.lowercased() != "unreleased" })?.version else {
        throw ReleaseNotesError.message("CHANGELOG.md has no released version")
    }
    return version
}

func extractRelease(_ changelog: String, version: String) throws -> String {
    guard let section = try releaseSections(changelog).first(where: { $0.version == version }) else {
        throw ReleaseNotesError.message("CHANGELOG.md has no release entry for \(version)")
    }
    guard !section.body.isEmpty else { throw ReleaseNotesError.message("CHANGELOG entry for \(version) is empty") }
    return section.body
}

func replaceRegex(_ value: String, pattern: String, template: String) throws -> String {
    let expression = try regex(pattern)
    return expression.stringByReplacingMatches(
        in: value,
        range: NSRange(value.startIndex..., in: value),
        withTemplate: template
    )
}

func renderInline(_ value: String) throws -> String {
    var rendered = value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
    rendered = try replaceRegex(rendered, pattern: #"`([^`]+)`"#, template: "<code>$1</code>")
    rendered = try replaceRegex(rendered, pattern: #"\*\*([^*]+)\*\*"#, template: "<strong>$1</strong>")
    rendered = try replaceRegex(
        rendered,
        pattern: #"\[([^]]+)\]\((https?://[^)]+)\)"#,
        template: #"<a href="$2">$1</a>"#
    )
    return rendered
}

func parseList(_ lines: [String], start: Int) throws -> ([ListItem], Int) {
    let bullet = try regex(#"^(\s*)-\s+(.+)$"#)
    var roots: [ListItem] = []
    var paths: [[Int]] = []
    var index = start

    func append(_ item: ListItem, depth: Int) {
        if depth == 0 || paths.isEmpty {
            roots.append(item)
            paths = [[roots.count - 1]]
            return
        }
        let effectiveDepth = min(depth, paths.count)
        let parentPath = paths[effectiveDepth - 1]
        func appendChild(_ items: inout [ListItem], path: ArraySlice<Int>) -> [Int] {
            guard let first = path.first else { return [] }
            if path.count == 1 {
                items[first].children.append(item)
                return Array(path) + [items[first].children.count - 1]
            }
            let suffix = appendChild(&items[first].children, path: path.dropFirst())
            return [first] + suffix
        }
        let newPath = appendChild(&roots, path: parentPath[...])
        paths = Array(paths.prefix(effectiveDepth)) + [newPath]
    }

    func updateLastText(_ extra: String) {
        guard let path = paths.last else { return }
        func update(_ items: inout [ListItem], path: ArraySlice<Int>) {
            guard let first = path.first else { return }
            if path.count == 1 { items[first].text += " " + extra; return }
            update(&items[first].children, path: path.dropFirst())
        }
        update(&roots, path: path[...])
    }

    while index < lines.count {
        let line = lines[index]
        let range = NSRange(line.startIndex..., in: line)
        if let match = bullet.firstMatch(in: line, range: range),
           let indentRange = Range(match.range(at: 1), in: line),
           let textRange = Range(match.range(at: 2), in: line) {
            let spaces = line[indentRange].reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
            append(ListItem(text: String(line[textRange]).trimmingCharacters(in: .whitespaces)), depth: spaces / 2)
            index += 1
        } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            var next = index + 1
            while next < lines.count, lines[next].trimmingCharacters(in: .whitespaces).isEmpty { next += 1 }
            if next < lines.count, bullet.firstMatch(in: lines[next], range: NSRange(lines[next].startIndex..., in: lines[next])) != nil {
                index = next
            } else { break }
        } else if line.first?.isWhitespace == true, !paths.isEmpty {
            updateLastText(line.trimmingCharacters(in: .whitespaces))
            index += 1
        } else { break }
    }
    return (roots, index)
}

func renderList(_ items: [ListItem], output: inout [String]) throws {
    output.append("<ul>")
    for item in items {
        if item.children.isEmpty {
            output.append("<li>\(try renderInline(item.text))</li>")
        } else {
            output.append("<li>\(try renderInline(item.text))")
            try renderList(item.children, output: &output)
            output.append("</li>")
        }
    }
    output.append("</ul>")
}

func renderHTML(version: String, body: String) throws -> String {
    let lines = body.components(separatedBy: .newlines)
    let heading = try regex(#"^(#{3,6})\s+(.+)$"#)
    let bullet = try regex(#"^\s*-\s+"#)
    var output = ["<h2>PHTV \(try renderInline(version))</h2>"]
    var index = 0
    while index < lines.count {
        let line = lines[index]
        if line.trimmingCharacters(in: .whitespaces).isEmpty { index += 1; continue }
        let range = NSRange(line.startIndex..., in: line)
        if let match = heading.firstMatch(in: line, range: range),
           let marks = Range(match.range(at: 1), in: line),
           let title = Range(match.range(at: 2), in: line) {
            let level = line[marks].count
            output.append("<h\(level)>\(try renderInline(String(line[title])))</h\(level)>")
            index += 1
        } else if bullet.firstMatch(in: line, range: range) != nil {
            let (items, next) = try parseList(lines, start: index)
            try renderList(items, output: &output)
            index = next
        } else {
            var paragraph = [line.trimmingCharacters(in: .whitespaces)]
            index += 1
            while index < lines.count {
                let candidate = lines[index]
                let candidateRange = NSRange(candidate.startIndex..., in: candidate)
                if candidate.trimmingCharacters(in: .whitespaces).isEmpty
                    || heading.firstMatch(in: candidate, range: candidateRange) != nil
                    || bullet.firstMatch(in: candidate, range: candidateRange) != nil { break }
                paragraph.append(candidate.trimmingCharacters(in: .whitespaces))
                index += 1
            }
            output.append("<p>\(try renderInline(paragraph.joined(separator: " ")))</p>")
        }
    }
    return output.joined(separator: "\n")
}

func items(in appcast: String) throws -> [String] {
    let expression = try regex(#"<item>.*?</item>"#, options: [.dotMatchesLineSeparators])
    return expression.matches(in: appcast, range: NSRange(appcast.startIndex..., in: appcast)).compactMap {
        Range($0.range, in: appcast).map { String(appcast[$0]) }
    }
}

func itemVersion(_ item: String) throws -> String? {
    try firstMatch(#"<sparkle:shortVersionString>([^<]+)</sparkle:shortVersionString>"#, in: item)?[1]
}

func latestAppcastVersion(_ appcast: String) throws -> String {
    guard let first = try items(in: appcast).first, let version = try itemVersion(first), !version.isEmpty else {
        throw ReleaseNotesError.message("Appcast has no current short version")
    }
    return version
}

func maximumBuildNumber(_ appcasts: [String]) throws -> Int {
    var maximum = 0
    for appcast in appcasts {
        for pattern in [#"<sparkle:version>([0-9]+)</sparkle:version>"#, #"sparkle:version=\"([0-9]+)\""#] {
            let expression = try regex(pattern)
            for match in expression.matches(in: appcast, range: NSRange(appcast.startIndex..., in: appcast)) {
                if let range = Range(match.range(at: 1), in: appcast), let value = Int(appcast[range]) {
                    maximum = max(maximum, value)
                }
            }
        }
    }
    return maximum
}

func validateReleaseItem(_ appcast: String, path: String, version: String, build: Int, archive: String) throws {
    for item in try items(in: appcast) where try itemVersion(item) == version {
        let versionBuild = (try firstMatch(#"<sparkle:version>([0-9]+)</sparkle:version>"#, in: item)?[1])
            .flatMap { Int($0) }
        guard let enclosure = try firstMatch(#"<enclosure\s+[^>]+>"#, in: item)?[0] else { continue }
        let enclosureBuild = (try firstMatch(#"sparkle:version=\"([0-9]+)\""#, in: enclosure)?[1])
            .flatMap { Int($0) }
        let url = try firstMatch(#"url=\"([^\"]+)\""#, in: enclosure)?[1] ?? ""
        if (versionBuild ?? enclosureBuild) == build, url.hasSuffix("/" + archive) {
            print("Validated \(path): version=\(version) build=\(build) archive=\(archive)")
            return
        }
    }
    throw ReleaseNotesError.message("\(path) has no matching version/build/archive item")
}

func normalizedHTML(_ value: String) -> String {
    value.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
}

func validateAppcast(_ appcast: String, path: String, version: String, expectedHTML: String) throws {
    guard let item = try items(in: appcast).first(where: { try itemVersion($0) == version }) else {
        throw ReleaseNotesError.message("Appcast has no item for \(version): \(path)")
    }
    guard let description = try firstMatch(#"<description><!\[CDATA\[(.*?)\]\]></description>"#, in: item, options: [.dotMatchesLineSeparators])?[1],
          normalizedHTML(description.trimmingCharacters(in: .whitespacesAndNewlines)) == normalizedHTML(expectedHTML) else {
        throw ReleaseNotesError.message("Appcast description for \(version) is missing or stale: \(path)")
    }
    guard let enclosure = try firstMatch(#"<enclosure\s+[^>]+>"#, in: item)?[0] else {
        throw ReleaseNotesError.message("Appcast item \(version) has no enclosure: \(path)")
    }
    for attribute in ["url", "length", "sparkle:edSignature"] where enclosure.range(of: "\(attribute)=\"") == nil {
        throw ReleaseNotesError.message("Appcast item \(version) is missing \(attribute): \(path)")
    }
}

func injectAppcast(_ appcast: String, version: String, html: String) throws -> String {
    let expression = try regex(#"<item>.*?</item>"#, options: [.dotMatchesLineSeparators])
    for match in expression.matches(in: appcast, range: NSRange(appcast.startIndex..., in: appcast)) {
        guard let range = Range(match.range, in: appcast) else { continue }
        let item = String(appcast[range])
        guard try itemVersion(item) == version else { continue }
        let enclosureRegex = try regex(#"(?m)^([ \t]*)<enclosure\s"#)
        guard let enclosure = enclosureRegex.firstMatch(in: item, range: NSRange(item.startIndex..., in: item)),
              let indentRange = Range(enclosure.range(at: 1), in: item) else {
            throw ReleaseNotesError.message("Appcast item \(version) has no enclosure")
        }
        let indent = String(item[indentRange])
        let htmlLines = html.components(separatedBy: .newlines).map { indent + "    " + $0 }.joined(separator: "\n")
        let block = "\(indent)<description><![CDATA[\n\(htmlLines)\n\(indent)]]></description>"
        var updated = item
        if let old = try firstMatch(#"\n[ \t]*<description><!\[CDATA\[.*?\]\]></description>"#, in: item, options: [.dotMatchesLineSeparators])?[0] {
            updated = item.replacingOccurrences(of: old, with: "\n" + block)
        } else if let enclosureRange = Range(enclosure.range, in: item) {
            updated.replaceSubrange(enclosureRange, with: block + "\n" + item[enclosureRange])
        }
        var result = appcast
        result.replaceSubrange(range, with: updated)
        return result
    }
    throw ReleaseNotesError.message("Appcast has no item for \(version)")
}

func argument(_ name: String, in arguments: [String], required: Bool = true) throws -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        if required { throw ReleaseNotesError.message("Missing \(name)") }
        return nil
    }
    return arguments[index + 1]
}

func runSelfTests() throws {
    let changelog = """
    # Changelog
    ## [Unreleased]
    ## [3.4.2] - 2026-07-22
    ### Tổng quan
    Một bản **ổn định** cho `PHTV`.
    - Mục cấp một
      - Mục cấp hai được xuống
        dòng đúng.
    ## [3.4.1] - 2026-07-20
    Cũ.
    """
    guard try latestReleaseVersion(changelog) == "3.4.2" else { throw ReleaseNotesError.message("latest self-test failed") }
    let html = try renderHTML(version: "3.4.2", body: extractRelease(changelog, version: "3.4.2"))
    guard html.contains("<strong>ổn định</strong>"), html.contains("Mục cấp hai được xuống dòng đúng.") else {
        throw ReleaseNotesError.message("HTML renderer self-test failed")
    }
    let appcast = """
    <rss><channel><item>
      <sparkle:shortVersionString>3.4.2</sparkle:shortVersionString>
      <enclosure url="https://example.test/a.dmg" length="42" sparkle:edSignature="sig"/>
    </item></channel></rss>
    """
    let injected = try injectAppcast(appcast, version: "3.4.2", html: html)
    guard try injectAppcast(injected, version: "3.4.2", html: html) == injected else {
        throw ReleaseNotesError.message("Appcast injection is not idempotent")
    }
    try validateAppcast(injected, path: "self-test", version: "3.4.2", expectedHTML: html)
    print("Release notes self-tests passed")
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let command = arguments.first else { throw ReleaseNotesError.message("Missing command") }
    let changelogPath = try argument("--changelog", in: arguments, required: false) ?? "CHANGELOG.md"
    if command == "self-test" { try runSelfTests(); exit(0) }
    if command == "appcast-version" {
        let path = try argument("--appcast", in: arguments)!
        print(try latestAppcastVersion(String(contentsOfFile: path, encoding: .utf8)))
        exit(0)
    }
    if command == "max-build" {
        var appcasts: [String] = []
        for (index, value) in arguments.enumerated() where value == "--appcast" && index + 1 < arguments.count {
            appcasts.append(try String(contentsOfFile: arguments[index + 1], encoding: .utf8))
        }
        print(try maximumBuildNumber(appcasts))
        exit(0)
    }
    if command == "validate-item" {
        let path = try argument("--appcast", in: arguments)!
        try validateReleaseItem(
            String(contentsOfFile: path, encoding: .utf8),
            path: path,
            version: try argument("--version", in: arguments)!,
            build: Int(try argument("--build", in: arguments)!) ?? -1,
            archive: try argument("--archive", in: arguments)!
        )
        exit(0)
    }
    let changelog = try String(contentsOfFile: changelogPath, encoding: .utf8)
    if command == "latest" { print(try latestReleaseVersion(changelog)); exit(0) }
    let version = try argument("--version", in: arguments)!
    let body = try extractRelease(changelog, version: version)
    let html = try renderHTML(version: version, body: body)
    switch command {
    case "render":
        let format = try argument("--format", in: arguments)!
        let value = format == "markdown" ? "# PHTV \(version)\n\n\(body)\n" : html + "\n"
        if let output = try argument("--output", in: arguments, required: false) {
            try value.write(toFile: output, atomically: true, encoding: .utf8)
        } else { print(value, terminator: "") }
    case "inject-appcast":
        let path = try argument("--appcast", in: arguments)!
        let original = try String(contentsOfFile: path, encoding: .utf8)
        let updated = try injectAppcast(original, version: version, html: html)
        try updated.write(toFile: path, atomically: true, encoding: .utf8)
        try validateAppcast(updated, path: path, version: version, expectedHTML: html)
    case "check":
        var index = 0
        while index < arguments.count {
            if arguments[index] == "--appcast", index + 1 < arguments.count {
                let path = arguments[index + 1]
                try validateAppcast(String(contentsOfFile: path, encoding: .utf8), path: path, version: version, expectedHTML: html)
                index += 2
            } else { index += 1 }
        }
        print("Release metadata is valid for PHTV \(version)")
    default:
        throw ReleaseNotesError.message("Unknown command: \(command)")
    }
} catch {
    fputs("release-notes: \(error)\n", stderr)
    exit(1)
}
