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

    private let queue = DispatchQueue(label: "com.gifmon.gif-controller", qos: .userInteractive)

    // MARK: - Public

    func load(gifURL: URL) throws {
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

    func stop() {
        frameTimer?.cancel()
        frameTimer = nil
    }

    func updateSpeed(usage: Double) {
        guard !frames.isEmpty else { return }
        schedule(interval: frameInterval(from: usage))
    }

    // MARK: - Private

    private func schedule(interval: TimeInterval) {
        frameTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            let frame = self.frames[self.currentIndex]
            self.currentIndex = (self.currentIndex + 1) % self.frames.count
            DispatchQueue.main.async { self.onFrame?(frame) }
        }
        t.resume()
        frameTimer = t
    }

    // usage 0.0 → 5fps(200ms),  usage 1.0 → 30fps(33ms)
    private func frameInterval(from usage: Double) -> TimeInterval {
        let minInterval = 0.033  // ~30fps at usage 1.0
        let maxInterval = 0.200  //   5fps at usage 0.0
        return maxInterval - (usage * (maxInterval - minInterval))
    }
}
