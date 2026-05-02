//
//  App.swift
//  DownloadWatcher
//
//  Created by 김민석 on 4/28/26.
//

import SwiftUI

@main
struct DownloadWatcherApp: App {
    @State private var fileMonitor = FileMonitor()
    @State private var notificationManager = NotificationManager.shared
    @State private var showPermissionAlert = false

    var body: some Scene {
        MenuBarExtra("DownloadWatcher",
                     systemImage: fileMonitor.isRunning ? "eye.fill" : "eye.slash.fill") {
            MenuBarView(fileMonitor: fileMonitor)
        }
        .menuBarExtraStyle(.window)
        Settings {
            SettingsView(fileMonitor: fileMonitor)
        }
        Window("Notification Permission", id: "permission") {
            NotificationPermissionView(notificationManager: notificationManager)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    init() {
        NotificationManager.shared.requestPermission()
        // Check permission after a short delay to allow the system prompt to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            NotificationManager.shared.checkPermission()
        }
    }
}
