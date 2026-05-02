//
//  DuplicateItem.swift
//  DownloadWatcher
//
//  Created by 김민석 on 4/28/26.
//

import Foundation
import AppKit

enum FileMatchStatus {
    case identical
    case differentContent
    case unknown

    var label: String {
        switch self {
        case .identical: return "Identical"
        case .differentContent: return "Different content"
        case .unknown: return "Unknown"
        }
    }
}

struct CopyInfo: Identifiable {
    let id = UUID()
    let fileName: String
    let path: String
    let icon: NSImage
    let fileSize: String
    var matchStatus: FileMatchStatus

    init(fileName: String, path: String, originalPath: String) {
        self.fileName = fileName
        self.path = path
        self.icon = NSWorkspace.shared.icon(forFile: path)

        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        self.fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)

        // Direct byte-by-byte comparison — simple and reliable
        self.matchStatus = FileManager.default.contentsEqual(atPath: path, andPath: originalPath)
            ? .identical : .differentContent
    }
}

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let originalFile: String
    let originalPath: String
    let originalIcon: NSImage
    let originalSize: String
    var copies: [CopyInfo]
    let detectedAt: Date

    var identicalCount: Int {
        copies.filter { $0.matchStatus == .identical }.count
    }

    var differentCount: Int {
        copies.filter { $0.matchStatus == .differentContent }.count
    }

    init(originalFile: String, originalPath: String, copies: [CopyInfo], detectedAt: Date) {
        self.originalFile = originalFile
        self.originalPath = originalPath
        self.originalIcon = NSWorkspace.shared.icon(forFile: originalPath)
        let attrs = try? FileManager.default.attributesOfItem(atPath: originalPath)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        self.originalSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        self.copies = copies
        self.detectedAt = detectedAt
    }
}
