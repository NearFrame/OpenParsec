import Foundation
import CoreGraphics

@main
struct StreamViewportTests {
    static func main() {
        var checks = 0
        func check(_ value: Bool, _ name: String) {
            precondition(value, name)
            checks += 1
        }
        let portrait = CGRect(x: 0, y: 0, width: 800, height: 1100)
        let fold = CGRect(x: 0, y: 540, width: 800, height: 20)
        let top = CGRect(x: 0, y: 0, width: 800, height: 540)
        check(StreamViewport.frame(in: portrait, partiallyOpen: true, folds: [fold]) == top, "tabletop uses upper panel")
        check(StreamViewport.frame(in: portrait, partiallyOpen: false, folds: [fold]) == portrait, "unfolding restores full bounds even with stale division geometry")
        check(StreamViewport.frame(in: portrait, partiallyOpen: true, folds: []) == portrait, "posture before geometry remains full bounds")
        let landscape = CGRect(x: 0, y: 0, width: 1100, height: 800)
        let vertical = CGRect(x: 540, y: 0, width: 20, height: 800)
        check(StreamViewport.frame(in: landscape, partiallyOpen: true, folds: [vertical]) == landscape, "book posture remains full bounds")
        let wideFold = CGRect(x: 0, y: 390, width: 1100, height: 20)
        check(StreamViewport.frame(in: landscape, partiallyOpen: true, folds: [wideFold]).height == 390, "horizontal folds do not depend on portrait aspect ratio")
        let offset = CGRect(x: 20, y: 30, width: 800, height: 1100)
        check(StreamViewport.frame(in: offset, partiallyOpen: true, folds: [fold.offsetBy(dx: 20, dy: 30)]) == top.offsetBy(dx: 20, dy: 30), "nonzero bounds origin")
        for invalid in [CGRect.null, .infinite, .zero,
                        CGRect(x: 0, y: -20, width: 800, height: 10),
                        CGRect(x: 0, y: 1090, width: 800, height: 20),
                        CGRect(x: 0, y: 0, width: 800, height: 10),
                        CGRect(x: 10, y: 400, width: 700, height: 20),
                        CGRect(x: 0, y: 400, width: 800, height: 0)] {
            check(StreamViewport.frame(in: portrait, partiallyOpen: true, folds: [invalid]) == portrait, "invalid or partial obstruction must not shrink stream")
        }
        let earlier = fold.offsetBy(dx: 0, dy: -100)
        check(StreamViewport.frame(in: portrait, partiallyOpen: true, folds: [fold, earlier]).height == 440, "nearest upper obstruction wins")
        check(StreamViewport.frame(in: portrait, partiallyOpen: true, folds: [earlier, fold]).height == 440, "region order does not change viewport")
        check(StreamViewport.frame(in: .zero, partiallyOpen: true, folds: [fold]) == .zero, "zero layout is safe")
        for height in [100.0, 300, 500, 700, 900] {
            let moving = CGRect(x: 0, y: height, width: 800, height: 20)
            check(StreamViewport.frame(in: portrait, partiallyOpen: true, folds: [moving]).height == height, "geometry tracks every fold update without a posture transition")
        }
        check(StreamViewport.pixelSize(top.size, scale: 3) == CGSize(width: 2400, height: 1620), "client resolution follows actual upper viewport")
        check(StreamViewport.pixelSize(CGSize(width: 10.2, height: 20.8), scale: 2) == CGSize(width: 20, height: 42), "fractional pixel rounding")
        for size in [CGSize.zero, CGSize(width: -1, height: 2), CGSize(width: CGFloat.nan, height: 20), CGSize(width: CGFloat.infinity, height: 20)] {
            check(StreamViewport.pixelSize(size, scale: 2) == nil, "invalid size cannot reach Int conversion")
        }
        for scale in [CGFloat.zero, -1, .nan, .infinity, .greatestFiniteMagnitude] {
            check(StreamViewport.pixelSize(top.size, scale: scale) == nil, "invalid or overflowing scale rejected")
        }
        check(StreamViewport.needsResolutionUpdate(top.size, current: portrait.size), "height-only viewport changes request new resolution")
        check(!StreamViewport.needsResolutionUpdate(top.size, current: top.size), "stable resolution does not renegotiate")
        let pending = ViewportResolutionUpdate()
        var sent: [Int] = []
        pending.schedule(after: 0.01) { sent.append(1) }
        pending.schedule(after: 0.01) { sent.append(2) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        check(sent == [2], "fold burst sends only the latest viewport")
        pending.schedule(after: 0.01) { sent.append(3) }
        pending.cancel()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        check(sent == [2], "disappearance cancels a pending host update")
        pending.schedule(after: 0.01) { sent.append(4) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        check(sent == [2, 4], "new work after cancellation is accepted")
        var released: ViewportResolutionUpdate? = ViewportResolutionUpdate()
        released?.schedule(after: 0.01) { sent.append(5) }
        released = nil
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        check(sent == [2, 4], "deallocation does not send a stale update")
        print("Passed \(checks) stream viewport assertions")
    }
}
