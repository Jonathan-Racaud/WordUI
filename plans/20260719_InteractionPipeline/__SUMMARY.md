# Interaction Pipeline Summary

## What we built

An event-driven, draw-time-resolved interaction pipeline that replaces the
busy-poll, rebuild-per-state model. The frame loop blocks in `SDL_WaitEvent` when
idle and only ticks at ~60 fps while an animation or drag is live. Interaction
state, animation clocks, and drag capture live in a persistent `InteractionStore`
keyed by a stable per-widget identity (`Widget.StableKey`), so state survives the
arena teardown a rebuild performs — which also structurally fixes the dangling
`Widget*` that caused missed clicks. State-dependent styling is expressed with the
existing concatenative words: `IfActive`/`IfHover`/`IfPressed` bodies always run at
build and record field-level `StatePatch` deltas onto the widget, and the draw pass
blends the active patches over the base values, field by field, interpolating any
fields wrapped in `Transition(...)`. Drag follows the pointer via a render-time
offset with pointer capture, leaving a seam for live reflow later. Layers — the
previously proposed mechanism — were dropped entirely.

## Files changed

| File | Status | Purpose |
|---|---|---|
| `src/Core/Easing.bf` | New | Easing curves + scalar lerp for animation |
| `src/Core/KeyAssign.bf` | New | Post-build path-hash walk assigning `StableKey` |
| `src/Core/InteractionStore.bf` | New | Persistent, non-arena hover/press/drag + animation clocks |
| `src/Core/Interaction.bf` | New | `IfActive`, `Transition`, patch-record helpers |
| `src/Core/StyleResolve.bf` | New | Draw-time field-by-field blend of active patches |
| `src/Core/HoverTracker.bf` | New | Hover-on-motion → store + repaint (no rebuild) |
| `src/Core/DragTracker.bf` | New | Drag capture + delta dispatch |
| `src/Properties/StatePatch.bf` | New | Field-level style delta + `InteractionStyle` property |
| `src/Properties/HoverState.bf` | New | `HoverState` + `IfHover` |
| `src/Behaviors/OnDrag.bf` | New | `OnDragBehavior` + `OnDrag` word |
| `src/Core/Color.bf` | Modified | Added `Lerp` |
| `src/Core/Widget.bf` | Modified | Added `StableKey`; removed `BuildIndex` |
| `src/Core/App.bf` | Modified | `mNeedsRepaint`/`RequestRepaint`, owns `Store`, runs `KeyAssign`, `List<Delegate>` handlers |
| `src/Core/UI.bf` | Modified | `List<Delegate>` handlers; removed `BuildIndex`/`CurrentBuildPosition` |
| `src/Core/SDLApp.bf` | Modified | Event-loop rewrite, motion coalescing, drag-offset `DrawWidget` |
| `src/Core/PressTracker.bf` | Modified | Keyed by `StableKey`, requests repaint not rebuild |
| `src/Properties/PressState.bf` | Modified | `IInteractionState.IsActiveFor`, `PressState`, `IfPressed` |
| `src/Properties/TextStyle.bf` | Modified | `TextColor`/`FontSize` record when in patch mode |
| `src/Modifiers/Styling.bf` | Modified | `Fill`/`Stroke`/`StrokeWidth` record; `Background`/`Border`/`Radius` patch-mode |
| `src/Components/Interior.bf` | Modified | Resolves `Fill` at draw |
| `src/Components/Boundary.bf` | Modified | Resolves `Stroke`/`StrokeWidth` at draw |
| `src/Components/Text.bf` | Modified | Resolves `TextColor` at draw |
| `src/Program.bf` | Modified | Demo `+` button: animated `IfHover` + instant `IfPressed` |

## Decisions

| Decision | Rationale |
|---|---|
| **Draw-time field-level patches, not layers** | Patches compose concurrent states and carry time/position; layers were boolean-only, whole-property, and timeless |
| **Persistent `InteractionStore` keyed by `StableKey`** | Animation must survive a mid-flight rebuild; a stable key re-associates state and removes the dangling `Widget*` |
| **`StableKey` via post-build path hash** | Deterministic and stable across rebuilds when structure is stable; retires positional `BuildIndex` |
| **Block when idle, tick only when animating/dragging** | True ~0% idle CPU while still giving animation a steady frame clock |
| **`mDirty` vs `mNeedsRepaint`** | Interaction/animation repaint without tearing down and rebuilding the tree |
| **Explicit `Transition` words** | Controlled and composes with the word style; nothing moves unless asked |
| **Drag as render offset with a reflow seam** | Cheap, no relayout now; the tracker extends to live reflow later without a rework |
| **Handlers as `List<Delegate>`** | One ownership list serves both `ClickHandler` and `DragHandler` |

## Roads not taken

- **Interaction layers (the prior plan).** Boolean-only, whole-property replacement
  (no composition), no notion of time or position, positional `BuildIndex` identity.
- **Option B — centralized interaction controller.** Cleaner for adding state kinds
  but adds indirection (a widget's look no longer lives on the widget) and machinery
  the milestone doesn't need.
- **Option C — retained/reconciled tree.** Highest ceiling and the only option that
  natively does layout-affecting animation and live-reflow drag, but the largest
  departure and risk; deliberately left as the seam Option A can grow into.
- **Transient animation state.** Rejected in favour of survive-rebuild persistence.
- **Implicit CSS-style transitions.** Rejected for explicit `Transition` words.
- **Live-reflow drag / layout-affecting animation (magnify).** Deferred behind the
  drag-offset and base-layout seams; layout still uses base values.

## Exit criteria met

- [x] Idle CPU ~0% — measured 0 CPU ticks over a 2s idle window (`/proc/<pid>/stat`)
- [x] No missed/delayed clicks — press/click keyed by `StableKey`, no dangling `Widget*`
- [x] `IfHover` without flicker or rebuild spam — resolved at draw, requests repaint only
- [x] Animation via `Transition` that survives a rebuild — clocks persist in the store
- [x] Concurrent states compose — field-by-field blend in `StyleResolve`
- [x] Drag follows the pointer with capture — render offset in `DrawWidget`
- [x] Regression `--test-mismatch/-unbalanced/-unclosed-pen/-leftover` still pass
