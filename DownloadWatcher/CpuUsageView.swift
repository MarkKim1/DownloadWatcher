//
//  CpuUsageView.swift
//  DownloadWatcher
//
//  Created by 김민석 on 4/28/26.
//

import SwiftUI
import Darwin

struct CpuUsageView: View {
    @State private var cpuUsage: Double = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "CPU: %.1f%%", cpuUsage))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .onAppear {
            cpuUsage = Self.getCurrentCpuUsage()
            timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                cpuUsage = Self.getCurrentCpuUsage()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    static func getCurrentCpuUsage() -> Double {
        var threads: thread_act_array_t?
        var threadCount = mach_msg_type_number_t()

        let result = task_threads(mach_task_self_, &threads, &threadCount)
        guard result == KERN_SUCCESS, let threads = threads else { return 0 }

        var totalUsage: Double = 0

        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var infoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

            let kr = withUnsafeMutablePointer(to: &info) { ptr in
                ptr.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) { reboundPtr in
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), reboundPtr, &infoCount)
                }
            }

            if kr == KERN_SUCCESS && info.flags != TH_FLAGS_IDLE {
                totalUsage += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }

        vm_deallocate(mach_task_self_,
                      vm_address_t(bitPattern: threads),
                      vm_size_t(Int(threadCount) * MemoryLayout<thread_act_t>.stride))

        return totalUsage
    }
}
