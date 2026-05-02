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
            freeBytes = getFreeMemory()
            
            timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                freeBytes = getFreeMemory()
            }
        }
        .onDisappear {
            timer?.invalidate( )
            timer = nil
        }
    }
    
    // Turns a raw bytes count into a human-readable string like "8 GB" or "512 MB"
    private func format(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func getFreeMemory() -> UInt64 {
         // vm_statistics64 is the struct the kernel will fill in for us.
         // It contains page counts for free / active / inactive / wired / compressed memory.
         var stats = vm_statistics64()

         // host_statistics64 wants the size of the struct in "integer_t" units,
         // not bytes. This is a Mach API quirk.
         var count = mach_msg_type_number_t(
             MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
         )

         // The kernel reports memory in pages, not bytes. Multiply by page size
         // (typically 16 KB on Apple Silicon, 4 KB on Intel) to convert.
         let pageSize = UInt64(vm_kernel_page_size)

         // host_statistics64 takes a pointer typed as integer_t*, but our struct
         // is vm_statistics64. We rebind the memory so Swift lets us pass it through.
         let kr = withUnsafeMutablePointer(to: &stats) { ptr in
             ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                 host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPtr, &count)
             }
         }

         // KERN_SUCCESS == 0. Anything else means the call failed.
         guard kr == KERN_SUCCESS else { return 0 }

         // "Available" on macOS = free pages + inactive pages.
         // Inactive memory is being used as cache but the OS will reclaim it
         // the moment an app needs RAM, so users think of it as free.
         // This matches what Activity Monitor shows under "Memory Pressure".
         let freePages = UInt64(stats.free_count) + UInt64(stats.inactive_count)
         return freePages * pageSize
     }
    
    
    
}
#Preview("Live") {
    MemoryUsageView()
        .padding()
}
