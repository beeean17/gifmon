import Foundation
import ImageIO
import CoreGraphics

enum GIFError: Error {
    case sourceCreationFailed
    case noFrames
    case decodingFailed
}

class GIFController {
    private var frames: [CGImage] = []
    private var currentIndex = 0
    private var frameTimer: DispatchSourceTimer?

    var onFrame: ((CGImage) -> Void)?

    var minFPS: Double = 5.0    { didSet { minFPS = sanitizedFPS(minFPS); rescheduleCurrent() } }
    var maxFPS: Double = 30.0   { didSet { maxFPS = sanitizedFPS(maxFPS); rescheduleCurrent() } }
    var fixedFPS: Double = 15.0 { didSet { fixedFPS = sanitizedFPS(fixedFPS); rescheduleCurrent() } }
    var isResourceLinked: Bool = true { didSet { rescheduleCurrent() } }

    private var lastUsage: Double = 0.0
    private let queue = DispatchQueue(label: "com.gifmon.gif-controller", qos: .userInteractive)

    // MARK: - Public

    func load(gifURL: URL) throws {
        stop()
        guard let source = CGImageSourceCreateWithURL(gifURL as CFURL, nil) else {
            throw GIFError.sourceCreationFailed
        }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { throw GIFError.noFrames }

        var decoded: [CGImage] = []
        for i in 0..<count {
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                decoded.append(image)
            }
        }
        guard !decoded.isEmpty else { throw GIFError.decodingFailed }

        frames = decoded
        currentIndex = 0
    }

    func start() {
        guard !frames.isEmpty else { return }
        schedule(interval: frameInterval(from: 0.0))
    }

    func restart() {
        guard !frames.isEmpty else { return }
        stop()
        currentIndex = 0
        let firstFrame = frames[currentIndex]
        currentIndex = (currentIndex + 1) % frames.count
        DispatchQueue.main.async { self.onFrame?(firstFrame) }
        schedule(interval: frameInterval(from: lastUsage))
    }

    func stop() {
        frameTimer?.cancel()
        frameTimer = nil
    }

    func updateSpeed(usage: Double) {
        guard !frames.isEmpty else { return }
        lastUsage = max(0.0, min(1.0, usage))
        guard isResourceLinked else { return }
        schedule(interval: frameInterval(from: usage))
    }

    func applySpeedSettings(minFPS: Double, maxFPS: Double,
                            fixedFPS: Double, resourceLinked: Bool) {
        self.minFPS = sanitizedFPS(minFPS)
        self.maxFPS = max(sanitizedFPS(maxFPS), self.minFPS + 1.0)
        self.fixedFPS = sanitizedFPS(fixedFPS)
        self.isResourceLinked = resourceLinked
    }

    // MARK: - Private

    private func rescheduleCurrent() {
        guard !frames.isEmpty else { return }
        schedule(interval: frameInterval(from: lastUsage))
    }

    private func schedule(interval: TimeInterval) {
        frameTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        let safeInterval = max(1.0 / 120.0, interval)
        t.schedule(deadline: .now() + safeInterval, repeating: safeInterval)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            let frame = self.frames[self.currentIndex]
            self.currentIndex = (self.currentIndex + 1) % self.frames.count
            DispatchQueue.main.async { self.onFrame?(frame) }
        }
        t.resume()
        frameTimer = t
    }

    private func frameInterval(from usage: Double) -> TimeInterval {
        if !isResourceLinked {
            return 1.0 / max(1.0, fixedFPS)
        }
        let clampedUsage = max(0.0, min(1.0, usage))
        let minInterval = 1.0 / maxFPS  // fastest (at full load)
        let maxInterval = 1.0 / minFPS  // slowest (at idle)
        return maxInterval - clampedUsage * (maxInterval - minInterval)
    }

    private func sanitizedFPS(_ value: Double) -> Double {
        guard value.isFinite else { return 5.0 }
        return max(1.0, min(120.0, value))
    }
}
