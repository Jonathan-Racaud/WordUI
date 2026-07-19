# M2 Discussion Log

## Interaction state: where should pressed/hover state live?

**Context:** Pressed state (which widget is currently pressed) spans multiple frames — mouse-down and mouse-up are separate events. The state must survive between them, so it can't live on transient widgets (freed on rebuild).

**Options analyzed:**
- **A: Component state** — Set `Clickable.IsPressed` on down, check on up. Works for press (no rebuild between down/up) but breaks for hover (must survive rebuilds). Rejected.
- **B: Persistent side table (M4 pattern)** — Correct but requires M4 infrastructure not yet built. Not viable for M2.
- **C: Static pass module** — `PressTracker` is a static class with `sPressedWidget`. Same pattern as `Layout` (static pass operating on the tree). State lives in the module, survives rebuilds naturally.

**Decision: Option C.** Each interaction concern gets its own static module (PressTracker, later HoverTracker, DragTracker, etc.). The pipeline feeds events through them in order, and each maintains its own private state.

## Pipeline architecture: composable trackers

**Design:** SDL_Event → InputEvent → pipeline of trackers. Each tracker:
- Receives `(Widget root, InputEvent event)`
- Maintains its own static state
- Returns `bool` (consumed / not consumed)

Order matters: DragTracker (future) runs before PressTracker, since a drag subsumes a press.

**Rationale:** Multiple passes are more composable than a single monolithic handler. Each tracker is independently testable. Adding hover (M3) means adding one new file, no modifications to existing code.

## Container measurement bug

**Problem:** HStack measured as (0,0) because `MeasureWidget` only queried component `Measure` hooks, and neither `StackLayout` nor `Children` overrode `Measure`. The HStack's children (buttons) measured correctly at (9,20), but that information was lost. Result: buttons got 0-height rects, clicks landed on the VStack's Spacer instead.

**Fix:** `MeasureWidget` now detects containers (widgets with both `Children` + `StackLayout`) and recursively measures children, computing totalMain + maxCross. This is essentially a dry-run of the layout pass for measurement purposes.

## HitTest Beef parameter immutability

**Problem:** Beef parameters are immutable by default. Assigning to the `best` parameter caused a compiler error. `var best;` (shadowing without initialization) defaulted to null, breaking the recursive accumulation.

**Fix:** `Widget current = best;` — a local mutable variable initialized with the parameter value. No shadowing warning, correct accumulation.

## Mouse-up vs mouse-down dispatch

**Decision: Dispatch on mouse-up.** Proper UI semantics: a "click" is mouse-down followed by mouse-up on the same widget. PressTracker records the pressed widget on mouse-down, then on mouse-up checks that the release landed on the same widget before firing the handler. This also gives visual feedback opportunities (M3): highlight on press, unhighlight on release.

## SimulateClick removal

Deleted `src/Diagnostics/Simulate.bf`, `CounterApp` (console demo), `RunCounterConsole`, and the `--test-counter` flag. The real SDL input pipeline replaces all of these.
