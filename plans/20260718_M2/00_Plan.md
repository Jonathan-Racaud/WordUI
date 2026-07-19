# M2 — It's Alive

**Goal:** Real SDL pointer events → adapt to `InputEvent` at boundary → hit-test rects → dispatch `Clickable` on mouse release → `Invalidate` → rebuild → repaint. Delete `SimulateClick`. Exit: clicking +/− in the window changes the visible count.

## Plan

1. **InputEvent** (`src/Core/InputEvent.bf`) — small struct adapting SDL mouse events at the framework boundary. Fields: `Kind { MouseDown, MouseUp, MouseMotion }`, `float X, Y`.

2. **HitTest** (`src/Core/HitTest.bf`) — static utility, recursive depth-first point-in-rect. Returns the leaf-most widget at (x,y) whose `mRect` contains the point. Does not filter by component type — trackers filter.

3. **PressTracker** (`src/Core/PressTracker.bf`) — static tracker with `sPressedWidget`. On mouse-down: hit-test, record widget if it has a `Clickable` with a non-null `Handler`. On mouse-up: hit-test again, if the released widget matches the pressed widget, fire the handler. Returns bool (consumed).

4. **SDLApp integration** — add `SDL_EVENT_MOUSE_BUTTON_DOWN`/`UP` cases to the event loop. Adapt `SDL_MouseButtonEvent` to `InputEvent`, feed through `PressTracker.HandleEvent(Root, input)`.

5. **Container measurement fix** — `MeasureWidget` in `Layout.bf` didn't handle containers (StackLayout + Children), causing HStack to measure as (0,0) and buttons to have zero-height rects. Fixed by adding recursive child measurement for containers.

6. **Demo** — restore `OnClick` handlers on +/- buttons in `CounterSDLApp`. Delete `SimulateClick`, `CounterApp`, `RunCounterConsole`, `--test-counter` flag.

## Decisions made in plan phase

- Mouse-up dispatch (not mouse-down): proper UI click semantics
- Pipeline architecture: SDL → InputEvent → PressTracker → handler. M3 adds HoverTracker, later adds DragTracker. Each is a separate static module with its own state
- HitTest returns any widget, not just Clickable ones — trackers filter by capability
- PressTracker owns its own `sPressedWidget` state (static, survives rebuilds)
- `Invalidate()` is public on `App`, called by user's handler delegate — no framework auto-invalidate
