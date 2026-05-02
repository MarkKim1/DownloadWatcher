//
//  NotificationPermissionView.swift
//  DownloadWatcher
//
//  Created by 김민석 on 4/28/26.
//

import SwiftUI

struct NotificationPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    var notificationManager: NotificationManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("Notifications Required")
                .font(.title2)
                .bold()

            Text("DownloadWatcher needs notification permission to alert you when duplicate files are detected in your Downloads folder.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button {
                    notificationManager.openSystemSettings()
                } label: {
                    Text("Open System Settings")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Dismiss") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
        }
        .padding(30)
        .frame(width: 360, height: 320)
    }
}
