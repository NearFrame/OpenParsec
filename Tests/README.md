# Stream viewport regression checks

Run `sh Tests/run-stream-viewport-tests.sh` on macOS with Xcode selected.
The tests compile the same geometry and debouncer used by the streaming controller.
They cover horizontal/vertical folds, absent and invalid regions, unfolding,
nonzero origins, same-posture geometry changes, height-only resolution changes,
invalid scale values, coalescing, cancellation and teardown.

These tests do not exercise UIKit layout, the Parsec transport, or hinge hardware.
An archive alone is not evidence that streaming works.

## Manual streaming checks

Use the normal app entry point: sign in, select a host, connect, and open the
Parsec streaming menu. Repeat with both Metal and OpenGL renderers:

1. On an ordinary iPhone/iPad, rotate in a stream, then repeat after zooming.
   Verify the stream fills the viewport, mouse coordinates remain aligned, and
   an unchanged viewport does not reset zoom during ordinary layout passes.
2. On a supported Duo using an iOS 27.1 SDK build, partially fold horizontally.
   The stream and touch input must occupy the upper panel. Continue changing the
   fold angle without changing its posture state; the viewport must follow it.
3. Unfold and rotate to a vertical/book fold. The full viewport must return.
   Touches below the tabletop stream must not click or begin a host drag.
4. Show the native keyboard, fold/unfold and rotate. Verify overlap is measured
   against the stream panel, controls remain reachable, and hiding the keyboard
   clears its inset.
5. Choose Client Resolution and fold repeatedly. Verify only the settled size
   is negotiated. Switch to a fixed resolution before the delay expires; that
   choice must remain in effect. Background/disconnect during the delay and
   confirm no stale renegotiation is sent.
6. Reconnect while folded. Confirm the renderer retains upper-panel dimensions.

Record the exact commit, Xcode/SDK, OS/device, renderer and host used. Results from
an earlier branch or a model-only test must not be reported as device validation
of the current change.
