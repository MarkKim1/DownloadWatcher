//
//  SettingsView.swift
//  DownloadWatcher
//
//  Created by 김민석 on 4/28/26.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var fileMonitor: FileMonitor
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Watched Folder") {
                HStack {
                    Text(fileMonitor.watchedFolder.path)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button("Change...") {
                        selectFolder()
                    }
                }
            }

            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 200)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            fileMonitor.changeFolder(to: url)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
}
