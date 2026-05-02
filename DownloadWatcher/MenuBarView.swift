//
//  MenuBarView.swift
//  DownloadWatcher
//
//  Created by 김민석 on 4/28/26.
//

import SwiftUI

struct MenuBarView: View {
    var fileMonitor: FileMonitor
    @Environment(\.openWindow) private var openWindow
    @State private var showDeleteAllConfirm = false
    @State private var deleteResultMessage: String?
    private var isInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status
            HStack {
                Circle()
                    .fill(fileMonitor.isRunning ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(fileMonitor.isRunning ? "Watching ~/Downloads" : "Paused")
                    .font(.headline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if !NotificationManager.shared.isPermissionGranted {
                Button {
                    openWindow(id: "permission")
                } label: {
                    Label("Notifications Disabled", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }

            Divider()

            // Duplicates list
            if fileMonitor.duplicateGroups.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("No duplicates found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(fileMonitor.duplicateGroups) { group in
                            DuplicateGroupView(group: group, fileMonitor: fileMonitor)
                        }
                    }
                }
                .frame(maxHeight: 300)

                Divider()

                HStack(spacing: 12) {
                    let totalIdentical = fileMonitor.duplicateGroups.reduce(0) { $0 + $1.identicalCount }
                    if totalIdentical > 0 {
                        Button {
                            showDeleteAllConfirm = true
                        } label: {
                            Label("Delete Identical (\(totalIdentical))", systemImage: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }

                    Spacer()

                    Button {
                        fileMonitor.rescan()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    
                    
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            // Delete result toast
            if let message = deleteResultMessage {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(message)
                        .font(.caption2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            // Delete all confirmation
            if showDeleteAllConfirm {
                let totalIdentical = fileMonitor.duplicateGroups.reduce(0) { $0 + $1.identicalCount }
                let totalDifferent = fileMonitor.duplicateGroups.reduce(0) { $0 + $1.differentCount }
                VStack(spacing: 8) {
                    Text("Delete \(totalIdentical) identical copies?")
                        .font(.caption)
                        .bold()
                    if totalDifferent > 0 {
                        Text("\(totalDifferent) files with different content will be kept safe.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Text("Files will be moved to Trash.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Button("Cancel") {
                            showDeleteAllConfirm = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Delete Identical") {
                            let result = fileMonitor.deleteAllIdenticalCopies()
                            var msg = "\(result.deleted) files moved to Trash"
                            if result.skipped > 0 { msg += ", \(result.skipped) kept (different)" }
                            deleteResultMessage = msg
                            showDeleteAllConfirm = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                deleteResultMessage = nil
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .background(Color.red.opacity(0.08))
                .cornerRadius(8)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Divider()

            // Controls
            HStack(spacing: 8) {
                Button(fileMonitor.isRunning ? "Pause" : "Resume") {
                    if fileMonitor.isRunning {
                        fileMonitor.stop()
                    } else {
                        fileMonitor.start()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                SettingsLink {
                    Text("Settings...")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isInPreview)
                .help(isInPreview ? "Disabled in Preview" : "Open Settings")

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isInPreview)

                Spacer()

                
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            HStack{
                MemoryUsageView()
                Spacer()
                CpuUsageView()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
        }
        .frame(width: 340)
        .padding(.vertical, 4)
        .onAppear {
            NotificationManager.shared.checkPermission()
        }
    }
}

struct DuplicateGroupView: View {
    let group: DuplicateGroup
    var fileMonitor: FileMonitor
    @State private var expanded = false
    @State private var showDeleteConfirm = false

    private let maxVisible = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Original file with size
            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: group.originalPath))
                } label: {
                    HStack(spacing: 8) {
                        Image(nsImage: group.originalIcon)
                            .resizable()
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text("Original")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text(group.originalSize)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(group.originalFile)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .help(group.originalPath)
            }

            // Copies with status
            let visibleCopies = expanded ? group.copies : Array(group.copies.prefix(maxVisible))
            ForEach(visibleCopies) { copy in
                HStack(spacing: 8) {
                    Button {
                        NSWorkspace.shared.open(URL(fileURLWithPath: copy.path))
                    } label: {
                        HStack(spacing: 8) {
                            Image(nsImage: copy.icon)
                                .resizable()
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text("Copy")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(copy.fileSize)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(copy.fileName)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            // Match status badge
                            StatusBadge(status: copy.matchStatus)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(copy.path)
                }
            }

            // Show more / less
            if group.copies.count > maxVisible {
                Button {
                    expanded.toggle()
                } label: {
                    Text(expanded ? "Show less" : "... and \(group.copies.count - maxVisible) more")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .padding(.leading, 32)
            }

            // Footer
            HStack {
                Text("\(group.identicalCount) identical, \(group.differentCount) different")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if group.identicalCount > 0 {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [URL(fileURLWithPath: group.originalPath)]
                    )
                } label: {
                    Image(systemName: "folder")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Show in Finder")

                Button("Dismiss") {
                    fileMonitor.removeGroup(group)
                }
                .font(.caption2)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            // Delete confirmation
            if showDeleteConfirm {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete \(group.identicalCount) identical copies?")
                            .font(.caption2)
                        if group.differentCount > 0 {
                            Text("\(group.differentCount) different will be kept")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    Button("Cancel") {
                        showDeleteConfirm = false
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("Delete") {
                        _ = fileMonitor.deleteIdenticalCopies(for: group)
                        showDeleteConfirm = false
                    }
                    .font(.caption2)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.mini)
                }
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}

struct StatusBadge: View {
    let status: FileMatchStatus

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: status == .identical ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text(status.label)
        }
        .font(.caption2)
        .foregroundStyle(status == .identical ? .green : .orange)
    }
}

#Preview {
    MenuBarView(fileMonitor: FileMonitor())
}
