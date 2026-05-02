//
//  MemoryUsageView.swift
//  DownloadWatcher
//
//  Created by 김민석 on 5/2/26.
//

import SwiftUI
import Darwin

struct MemoryUsageView: View {
    // How many bytes are currently free/available
    @State private var freeBytes: UInt64 = 0
    
    // Total physical RAM installed on this Mac
    @State private var totalBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    
    //Holds the repeating timer so we can cancel it when the view goes away
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 4) {
            //SF Symbol that looks like a RAM stick
            Image(systemName: "memorychip")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            //
            Text("RAM: \(format(freeBytes)) free / \(format(totalBytes))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .onAppear {
            freeBytes =
        }
    }
    
    // Turns a raw bytes count into a human-readable string like "8 GB" or "512 MB"
    private func format(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    
    
}
#Preview("Live") {
    MemoryUsageView()
        .padding()
}
