import Darwin
import Foundation

enum MonitorTarget: Int {
    case cpu  = 0
    case ram  = 1
    case both = 2
}

class ResourceMonitor {
    var onUpdate: ((Double, Double) -> Void)?
    var includeInactiveRAM = false

    private var timer: DispatchSourceTimer?
    private var sampler = CPUSampler()
    private let queue = DispatchQueue(label: "com.gifmon.resource-monitor", qos: .utility)

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: 0.5)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            let cpu = self.sampler.sample()
            let ram = self.sampleRAM()
            DispatchQueue.main.async { self.onUpdate?(cpu, ram) }
        }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func sampleRAM() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0.0 }

        let total    = Double(ProcessInfo.processInfo.physicalMemory)
        let pageSize = Double(vm_kernel_page_size)
        let free     = Double(stats.free_count)     * pageSize
        let inactive = Double(stats.inactive_count) * pageSize

        // includeInactiveRAM=false(기본): inactive를 여유 메모리로 처리
        let used = includeInactiveRAM ? (total - free) : (total - free - inactive)
        return max(0.0, min(1.0, used / total))
    }
}
