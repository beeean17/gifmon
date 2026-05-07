import Darwin

// Mach API wrapper for per-core CPU tick sampling via host_processor_info
struct CPUSampler {
    private var prev: [processor_cpu_load_info] = []

    // Returns system-wide CPU usage 0.0–1.0 (user+sys ticks / total ticks delta)
    mutating func sample() -> Double {
        guard let current = fetchInfo() else { return 0.0 }
        defer { prev = current }
        guard !prev.isEmpty, prev.count == current.count else { return 0.0 }

        var user: UInt32 = 0, sys: UInt32 = 0
        var idle: UInt32 = 0, nice: UInt32 = 0

        for i in 0..<current.count {
            user += current[i].cpu_ticks.0 &- prev[i].cpu_ticks.0  // CPU_STATE_USER
            sys  += current[i].cpu_ticks.1 &- prev[i].cpu_ticks.1  // CPU_STATE_SYSTEM
            idle += current[i].cpu_ticks.2 &- prev[i].cpu_ticks.2  // CPU_STATE_IDLE
            nice += current[i].cpu_ticks.3 &- prev[i].cpu_ticks.3  // CPU_STATE_NICE
        }

        let total = user + sys + idle + nice
        guard total > 0 else { return 0.0 }
        return Double(user + sys) / Double(total)
    }

    private func fetchInfo() -> [processor_cpu_load_info]? {
        var numCPUs: natural_t = 0
        var ptr: processor_info_array_t?
        var count: mach_msg_type_number_t = 0

        let kr = host_processor_info(mach_host_self(),
                                     PROCESSOR_CPU_LOAD_INFO,
                                     &numCPUs, &ptr, &count)
        guard kr == KERN_SUCCESS, let raw = ptr else { return nil }

        let info = raw.withMemoryRebound(to: processor_cpu_load_info.self,
                                          capacity: Int(numCPUs)) {
            Array(UnsafeBufferPointer(start: $0, count: Int(numCPUs)))
        }
        vm_deallocate(mach_task_self_,
                      vm_address_t(UInt(bitPattern: raw)),
                      vm_size_t(count) * vm_size_t(MemoryLayout<integer_t>.size))
        return info
    }
}
