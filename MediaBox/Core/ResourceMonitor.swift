import Foundation
import Darwin
import os
import UIKit

enum MemoryFootprint {
    /// Empreinte physique du processus (même métrique que Xcode / jetsam).
    static func currentBytes() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { raw in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), raw, &count)
            }
        }
        return kr == KERN_SUCCESS ? UInt64(info.phys_footprint) : 0
    }
    static func availableBytes() -> UInt64 { UInt64(max(0, os_proc_available_memory())) }
}

enum CPUUsage {
    /// Somme des CPU des threads du processus (peut dépasser 100 % en multi-cœur). Appel ponctuel uniquement.
    static func currentPercent() -> Double {
        var threads: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)
        guard task_threads(mach_task_self_, &threads, &threadCount) == KERN_SUCCESS, let list = threads else { return 0 }
        var total = 0.0
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size)
            let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
                ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { raw in
                    thread_info(list[i], thread_flavor_t(THREAD_BASIC_INFO), raw, &count)
                }
            }
            if kr == KERN_SUCCESS && (info.flags & 0x2) == 0 {
                total += Double(info.cpu_usage) / 1000.0 * 100.0
            }
        }
        let size = vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: list)), size)
        return total
    }
}

struct ResourceSnapshot {
    var footprint: UInt64
    var peak: UInt64
    var available: UInt64
    var cpu: Double
    var thermal: ProcessInfo.ThermalState
    var lowPower: Bool
    var date: Date
}

/// Capture à la demande (aucune boucle de surveillance).
@MainActor
final class ResourceMonitor: ObservableObject {
    static let shared = ResourceMonitor()
    @Published private(set) var latest: ResourceSnapshot?

    @discardableResult
    func capture() -> ResourceSnapshot {
        let mm = MemoryManager.shared
        mm.sample()
        let s = ResourceSnapshot(footprint: mm.currentBytes, peak: mm.peakBytes,
                                 available: MemoryFootprint.availableBytes(),
                                 cpu: CPUUsage.currentPercent(),
                                 thermal: ProcessInfo.processInfo.thermalState,
                                 lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled,
                                 date: Date())
        latest = s
        return s
    }
}
