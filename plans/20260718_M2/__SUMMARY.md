# M2 Summary

## What we built

Real SDL mouse input drives the UI. Pointer events are adapted to `InputEvent` at the framework boundary, hit-tested against widget rects, and dispatched to `Clickable` handlers on mouse release. The counter app is now truly interactive — clicking +/− updates the count in the window. `SimulateClick` and the console test harness are gone.

## Files changed

| File | Status | Purpose |
|---|---|---|
| `src/Core/InputEvent.bf` | New | `struct InputEvent { Kind, X, Y }` — SDL event adaptation at boundary |
| `src/Core/HitTest.bf` | New | Static depth-first point-in-rect utility |
| `src/Core/PressTracker.bf` | New | Static press tracking: down→record, up→match+dispatch |
| `src/Core/SDLApp.bf` | Modified | Mouse button event handling, pipeline integration |
| `src/Core/Layout.bf` | Modified | Container measurement fix (recursive child measurement) |
| `src/Core/App.bf` | Modified | Updated comment (removed SimulateClick reference) |
| `src/Program.bf` | Modified | Restored OnClick handlers, removed CounterApp + RunCounterConsole |
| `src/Diagnostics/Simulate.bf` | Deleted | Replaced by real input pipeline |

## Decisions

| Decision | Rationale |
|---|---|
| **Mouse-up dispatch** | Proper click semantics: press + release on same widget. Enables visual feedback in M3 |
| **Pipeline architecture** | Per-concern static modules (PressTracker, later HoverTracker, DragTracker). Composable, independently testable, no changes to existing code when adding new concerns |
| **HitTest returns any widget** | Trackers filter by capability. PressTracker checks for Clickable; HoverTracker will check for hoverable |
| **Container measurement** | `MeasureWidget` recursively measures container children instead of relying on component hooks. Fixes the zero-height HStack bug |
| **Press state in static module** | Survives rebuilds. Same pattern as `Layout` (static pass on the tree). Will evolve as more trackers are added |
| **Delete SimulateClick** | Replaced by real input. Console test harness (CounterApp) also removed |

## Roads not taken

- **Mouse-down dispatch.** Rejected: wrong UI semantics. A click is down+up on the same target
- **Monolithic input handler.** Rejected: would need refactoring when hover/drag/focus arrive. Pipeline of composable trackers scales better
- **Component-based press state.** Rejected: works for press (no rebuild between events) but breaks for hover (must survive rebuilds). Static module state is the consistent pattern
- **HitTest filtering by capability.** Rejected: couples hit-testing to specific concerns. Better to return any widget and let trackers filter

## Exit criteria met

- [x] Clicking +/− in the window changes the visible count
- [x] Mouse-up dispatch (click = down + up on same widget)
- [x] SimulateClick deleted
- [x] Existing `--test-*` flags preserved
