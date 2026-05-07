import Foundation
import CoreGraphics

class GIFController {
    var onFrame: ((CGImage) -> Void)?

    func load(gifURL: URL) throws {}
    func updateSpeed(usage: Double) {}
    func start() {}
    func stop() {}
}
