//
//  FileMonitor.swift
//  DownloadWatcher
//
//  Created by 김민석 on 4/28/26.
//

import Foundation
import Observation

@Observable
class FileMonitor {
    var isRunning = false
    var watchedFolder: URL
    var duplicateGroups: [DuplicateGroup] = []

    private var source: DispatchSourceFileSystemObject?
    private var knownFiles: Set<String> = []

    init() {
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        self.watchedFolder = downloadsPath
        loadExistingFiles()
        scanExistingDuplicates()
        start()
    }

    func start() {
        guard !isRunning else { return }
        loadExistingFiles()

        let fd = open(watchedFolder.path, O_EVTONLY)
        guard fd >= 0 else {
            print("Failed to open folder: \(watchedFolder.path)")
            return
        }
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )

        source?.setEventHandler { [weak self] in
            self?.checkForNewFiles()
        }

        source?.setCancelHandler {
            close(fd)
        }

        source?.resume()
        isRunning = true
    }

    func stop() {
        source?.cancel()
        source = nil
        isRunning = false
    }

    func changeFolder(to url: URL) {
        stop()
        watchedFolder = url
        start()
    }

    func clearDuplicates() {
        duplicateGroups.removeAll()
    }

    func rescan() {
        duplicateGroups.removeAll()
        loadExistingFiles()
        scanExistingDuplicates()
    }

    func removeGroup(_ group: DuplicateGroup) {
        duplicateGroups.removeAll { $0.id == group.id }
    }

    /// Delete only identical copy files for a single group
    func deleteIdenticalCopies(for group: DuplicateGroup) -> (deleted: Int, skipped: Int, failed: Int) {
        var deleted = 0
        var skipped = 0
        var failed = 0
        for copy in group.copies {
            if copy.matchStatus != .identical {
                skipped += 1
                continue
            }
            do {
                try FileManager.default.trashItem(at: URL(fileURLWithPath: copy.path), resultingItemURL: nil)
                deleted += 1
            } catch {
                print("Failed to trash \(copy.fileName): \(error)")
                failed += 1
            }
        }
        loadExistingFiles()
        // Remove identical copies from the group, keep different ones
        if let index = duplicateGroups.firstIndex(where: { $0.id == group.id }) {
            duplicateGroups[index].copies.removeAll { $0.matchStatus == .identical }
            if duplicateGroups[index].copies.isEmpty {
                duplicateGroups.remove(at: index)
            }
        }
        return (deleted, skipped, failed)
    }

    /// Delete all identical copies across all groups
    func deleteAllIdenticalCopies() -> (deleted: Int, skipped: Int, failed: Int) {
        var totalDeleted = 0
        var totalSkipped = 0
        var totalFailed = 0
        for group in duplicateGroups {
            let result = deleteIdenticalCopies(for: group)
            totalDeleted += result.deleted
            totalSkipped += result.skipped
            totalFailed += result.failed
        }
        return (totalDeleted, totalSkipped, totalFailed)
    }

    private func checkForNewFiles() {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: watchedFolder.path)) ?? []
        let currentFiles = Set(contents)
        let newFiles = currentFiles.subtracting(knownFiles)

        for filename in newFiles {
            handleNewFile(filename: filename)
        }

        knownFiles = currentFiles
    }

    private func handleNewFile(filename: String) {
        let ignoredExtensions = ["crdownload", "part", "download", "tmp"]
        let ext = (filename as NSString).pathExtension.lowercased()
        if ignoredExtensions.contains(ext) || filename.hasPrefix(".") { return }

        let folderPath = watchedFolder.path

        if let originalName = extractOriginalName(from: filename) {
            let originalPath = (folderPath as NSString).appendingPathComponent(originalName)
            if FileManager.default.fileExists(atPath: originalPath) {
                addCopyToGroup(originalName: originalName, originalPath: originalPath, copyName: filename, folderPath: folderPath)
                NotificationManager.shared.sendNotification(
                    title: "Duplicate download detected",
                    subtitle: filename,
                    body: "Original: \(originalName)",
                    filePath: originalPath
                )
                return
            }
        }

        let searchName = extractOriginalName(from: filename) ?? filename
        let downloadedPath = (folderPath as NSString).appendingPathComponent(filename)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) {
            let duplicates = DuplicateFinder.find(filename: searchName, excludingFolder: folderPath)
            if let firstMatch = duplicates.first {
                DispatchQueue.main.async {
                    let copy = CopyInfo(fileName: filename, path: downloadedPath, originalPath: firstMatch)
                    let group = DuplicateGroup(
                        originalFile: (firstMatch as NSString).lastPathComponent,
                        originalPath: firstMatch,
                        copies: [copy],
                        detectedAt: Date()
                    )
                    self.duplicateGroups.insert(group, at: 0)
                }
                NotificationManager.shared.sendNotification(
                    title: "File already exists",
                    subtitle: filename,
                    body: "Found at: \(firstMatch)",
                    filePath: firstMatch
                )
            }
        }
    }

    private func addCopyToGroup(originalName: String, originalPath: String, copyName: String, folderPath: String) {
        let copyPath = (folderPath as NSString).appendingPathComponent(copyName)
        let copy = CopyInfo(fileName: copyName, path: copyPath, originalPath: originalPath)

        if let index = duplicateGroups.firstIndex(where: { $0.originalPath == originalPath }) {
            duplicateGroups[index].copies.append(copy)
        } else {
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: folderPath)) ?? []
            var allCopies: [CopyInfo] = []
            for file in contents {
                if let base = extractOriginalName(from: file), base == originalName {
                    let path = (folderPath as NSString).appendingPathComponent(file)
                    allCopies.append(CopyInfo(fileName: file, path: path, originalPath: originalPath))
                }
            }
            allCopies.sort { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }

            let group = DuplicateGroup(
                originalFile: originalName,
                originalPath: originalPath,
                copies: allCopies,
                detectedAt: Date()
            )
            duplicateGroups.insert(group, at: 0)
        }
    }

    private func extractOriginalName(from filename: String) -> String? {
        let nsName = filename as NSString
        let ext = nsName.pathExtension
        let nameWithoutExt = nsName.deletingPathExtension

        let pattern = #"^(.+)\s+\(\d+\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: nameWithoutExt, range: NSRange(nameWithoutExt.startIndex..., in: nameWithoutExt)),
              let range = Range(match.range(at: 1), in: nameWithoutExt) else {
            return nil
        }

        let baseName = String(nameWithoutExt[range])
        return ext.isEmpty ? baseName : "\(baseName).\(ext)"
    }

    private func scanExistingDuplicates() {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: watchedFolder.path)) ?? []
        let folderPath = watchedFolder.path

        var grouped: [String: [String]] = [:]
        for filename in contents {
            if filename.hasPrefix(".") { continue }
            let ignoredExtensions = ["crdownload", "part", "download", "tmp"]
            let ext = (filename as NSString).pathExtension.lowercased()
            if ignoredExtensions.contains(ext) { continue }

            if let originalName = extractOriginalName(from: filename) {
                let originalPath = (folderPath as NSString).appendingPathComponent(originalName)
                if FileManager.default.fileExists(atPath: originalPath) {
                    grouped[originalName, default: []].append(filename)
                }
            }
        }

        for (originalName, copyNames) in grouped {
            let originalPath = (folderPath as NSString).appendingPathComponent(originalName)
            var copies = copyNames.map { name in
                CopyInfo(fileName: name, path: (folderPath as NSString).appendingPathComponent(name), originalPath: originalPath)
            }
            copies.sort { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }

            let group = DuplicateGroup(
                originalFile: originalName,
                originalPath: originalPath,
                copies: copies,
                detectedAt: Date()
            )
            duplicateGroups.append(group)
        }
    }

    private func loadExistingFiles() {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: watchedFolder.path)) ?? []
        knownFiles = Set(contents)
    }
}
