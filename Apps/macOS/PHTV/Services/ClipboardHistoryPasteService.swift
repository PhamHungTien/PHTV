//
//  ClipboardHistoryPasteService.swift
//  PHTV
//
//  Materializes history content before replacing the destination pasteboard.
//

import AppKit

@MainActor
enum ClipboardHistoryPasteService {
    struct Prepared {
        fileprivate let items: [NSPasteboardItem]
        fileprivate let filePaths: [String]
    }

    enum Failure: LocalizedError, Equatable {
        case unavailable
        case invalidImage
        case preparationFailed
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Nội dung này không còn khả dụng. Clipboard hiện tại được giữ nguyên."
            case .invalidImage:
                return "Không thể đọc hình ảnh này. Clipboard hiện tại được giữ nguyên."
            case .preparationFailed:
                return "Không thể chuẩn bị nội dung để dán. Clipboard hiện tại được giữ nguyên."
            case .writeFailed:
                return "Không thể ghi nội dung vào Clipboard. Nội dung chưa được dán; hãy thử lại."
            }
        }
    }

    static func prepare(_ item: ClipboardHistoryItem) throws -> Prepared {
        guard let payload = ClipboardHistoryPastePayloadResolver.resolve(item) else {
            throw Failure.unavailable
        }

        switch payload {
        case .text(let text):
            return try prepare(text: text)
        case .files(let paths):
            let items = try paths.map { path in
                let pasteboardItem = NSPasteboardItem()
                let fileURL = URL(fileURLWithPath: path)
                guard pasteboardItem.setString(fileURL.absoluteString, forType: .fileURL) else {
                    throw Failure.preparationFailed
                }
                return pasteboardItem
            }
            return Prepared(items: items, filePaths: paths)
        case .image(let data):
            // NSImage can defer decoding until the pasteboard asks for data.
            // Decode here, while an invalid image cannot erase the old clipboard.
            guard let bitmap = NSBitmapImageRep(data: data),
                  bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0,
                  bitmap.bitmapData != nil else {
                throw Failure.invalidImage
            }

            // Captures are normally already PNG. Preserve those bytes instead of
            // recompressing them; legacy TIFF/other bitmap formats become real PNG.
            let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
            guard let png = data.starts(with: pngSignature)
                ? data
                : bitmap.representation(using: .png, properties: [:]) else {
                throw Failure.preparationFailed
            }
            let pasteboardItem = NSPasteboardItem()
            guard pasteboardItem.setData(png, forType: .png) else {
                throw Failure.preparationFailed
            }
            if let tiff = bitmap.tiffRepresentation,
               !pasteboardItem.setData(tiff, forType: .tiff) {
                throw Failure.preparationFailed
            }
            return Prepared(items: [pasteboardItem], filePaths: [])
        }
    }

    static func prepare(text: String) throws -> Prepared {
        let item = NSPasteboardItem()
        guard item.setString(text, forType: .string) else {
            throw Failure.preparationFailed
        }
        return Prepared(items: [item], filePaths: [])
    }

    static func commit(
        _ prepared: Prepared,
        to pasteboard: NSPasteboard,
        writeObjects: (([NSPasteboardWriting]) -> Bool)? = nil
    ) throws {
        // Focus restoration can delay committing a prepared selection. Check its
        // selected file paths again immediately before clearing, without changing
        // the resolver's existing partial-file/fallback policy.
        guard !prepared.items.isEmpty,
              prepared.filePaths.allSatisfy({ FileManager.default.fileExists(atPath: $0) }) else {
            throw Failure.unavailable
        }

        // AppKit offers no atomic replace operation. Do not snapshot old content:
        // that could read sensitive or promised payloads merely to attempt rollback.
        pasteboard.clearContents()
        let objects: [NSPasteboardWriting] = prepared.items
        let didWrite = writeObjects?(objects) ?? pasteboard.writeObjects(objects)
        guard didWrite else { throw Failure.writeFailed }
    }
}
