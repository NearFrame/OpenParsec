import Foundation
import CoreGraphics

// Pure geometry shared by the live controller and regression tests. Fold frames
// are in the containing view's coordinate space, just like reservedRegions.
enum StreamViewport {
    static func frame(in bounds: CGRect, partiallyOpen: Bool, folds: [CGRect]) -> CGRect {
        guard partiallyOpen, bounds.width > 0, bounds.height > 0 else { return bounds }
        let cuts = folds.filter { fold in
            !fold.isNull && !fold.isInfinite && fold.width > fold.height && fold.height > 0 &&
            fold.minX <= bounds.minX && fold.maxX >= bounds.maxX &&
            fold.minY > bounds.minY && fold.maxY < bounds.maxY
        }
        guard let fold = cuts.min(by: { $0.minY < $1.minY }) else { return bounds }
        return CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: fold.minY - bounds.minY)
    }

    static func pixelSize(_ size: CGSize, scale: CGFloat) -> CGSize? {
        guard size.width.isFinite, size.height.isFinite, scale.isFinite,
              size.width > 0, size.height > 0, scale > 0 else { return nil }
        let width = (size.width * scale).rounded()
        let height = (size.height * scale).rounded()
        guard width.isFinite, height.isFinite, width >= 1, height >= 1,
              width < CGFloat(Int.max), height < CGFloat(Int.max) else { return nil }
        return CGSize(width: width, height: height)
    }

    static func needsResolutionUpdate(_ desired: CGSize, current: CGSize) -> Bool {
        desired != current
    }
}

// Main-thread-only: keep the most recent viewport and invalidate queued work on
// disappearance/backgrounding. The generation check also protects callbacks that
// have already been dequeued when cancelled.
final class ViewportResolutionUpdate {
    private var pending: DispatchWorkItem?
    private var generation = 0

    func cancel() {
        generation += 1
        pending?.cancel()
        pending = nil
    }

    func schedule(after delay: TimeInterval = 0.25, _ action: @escaping () -> Void) {
        cancel()
        let expected = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.generation == expected else { return }
            self.pending = nil
            action()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    deinit { pending?.cancel() }
}
