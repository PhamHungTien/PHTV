//
//  BackupError.swift
//  PHTV
//
//  Errors raised while reading or restoring settings and gõ tắt files.
//  Foundation only, so the macro transfer code can be shared.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

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
