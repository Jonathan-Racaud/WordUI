# M4 Summary

## What we built

Scrollable, clipping, and mouse-wheel support, built additively on M3's rebuild-surviving
identity store. A `Scrollable` container primitive carries a `ScrollView` marker; `Clip()`,
`Vertical()`, and `Horizontal()` are composable modifiers, so a scroll viewport is spelled as
`Scrollable(...) ; Height(.Fixed(240)); Clip();` rather than a monolithic widget. The wheel is
dispatched by a new `ScrollTracker` to the nearest scrollable under the pointer, which stores a
persistent per-key scroll offset in the `InteractionStore` and requests a repaint (no rebuild);
the offset is applied as a render-time translation in the existing `DrawWidget` walk, and the
`Painter` clips children to the viewport via a new clip stack over `SDL_SetRenderClipRect`.
Retained state is swept each rebuild (`Store.Retain` after `KeyAssign`), the M4 eviction
checkpoint. The exit demo is a functional Todo app — add, remove, scroll — whose list is a
`Scrollable` of `TodoRow` words (HStack + Label + Spacer + delete Button) keyed on item id, so
scroll position and per-row interaction state survive the rebuild each add/remove triggers.

## Files changed

| File | Status | Purpose |
|---|---|---|
| `src/Components/ClipRegion.bf` | New | `ClipRegion` marker component + `Clip()` modifier |
| `src/Components/ScrollView.bf` | New | `ScrollView` marker component (scroll-offset applicator) |
| `src/Widgets/Scrollable.bf` | New | `_Scrollable()`/`Scrollable_()`/`Scrollable(body)` container words |
| `src/Behaviors/OnScroll.bf` | New | `OnScrollBehavior` + `ScrollHandler` + `OnScroll()` word |
| `src/Core/ScrollTracker.bf` | New | Wheel dispatch: find scrollable, clamp, store offset, repaint |
| `src/Core/InputEvent.bf` | Modified | Added `MouseWheel` kind + `WheelX`/`WheelY` fields |
| `src/Core/InteractionStore.bf` | Modified | `mScroll` map (`GetScroll`/`SetScroll`) + `Retain` eviction sweep |
| `src/Core/KeyAssign.bf` | Modified | `Run` collects the live `StableKey` set into a `HashSet` |
| `src/Core/App.bf` | Modified | Calls `KeyAssign.Run(root, live)` then `Store.Retain(live)` |
| `src/Core/Painter.bf` | Modified | Clip stack: `PushClip`/`PopClip` over `SDL_SetRenderClipRect` |
| `src/Core/SDLApp.bf` | Modified | Wheel event case; clip + scroll offset in `DrawWidget` |
| `src/Program.bf` | Modified | Replaced counter demo with `TodoSDLApp` + `TodoRow` word |
| `docs/api/{widgets,modifiers,handlers}.mdx` | Modified | `Scrollable`, `Clip`/`Vertical`/`Horizontal`, `OnScroll` entries |
| `docs/roadmap.mdx` | Modified | M4 flipped to complete; eviction checkpoint checked |

## Decisions

| Decision | Rationale |
|---|---|
| **`Scrollable` a container primitive, not a modifier** | Reads as a distinct widget; direction/clipping become modifiers on it — cleaner decomposition (user's call) |
| **Clipping is its own capability (`Clip()` + `ClipRegion`)** | A scroll viewport composes from `Scrollable + Height + Clip`; `Clip()` reuses on any container, matching the concatenative thesis |
| **Scroll offset on `InteractionStore`, keyed by `StableKey`** | Mirrors the drag precedent exactly; survives the arena teardown a rebuild performs — the M4 exit criterion |
| **Render-time translation, no relayout** | Reuses the `DrawWidget` `(ox,oy)` offset already proven for drag; scroll never rebuilds or relayouts |
| **Bubbling via geometry, not parent pointers** | The container rect encloses the pointer, so a deepest-`ScrollView`-containing-point walk resolves the target; avoids adding upward traversal |
| **`Store.Retain` after `KeyAssign`** | The real "memory constraint" of M4: a churning list would otherwise leak hover/press/scroll entries for vanished keys |
| **Component name `ClipRegion` ≠ word `Clip`** | A `using static` word can't share a type's name (the `Int`/`Float` resolution hazard) |

## Roads not taken

- **`Scrollable()` as a flat modifier on `VStack`.** The first proposal; superseded by the
  container-primitive shape so direction and clipping could themselves be modifiers.
- **Scrollbar thumb this milestone.** Deferred; offset-only ships. The `ScrollView`/`Clip`
  split + store offset are the seam a `Scrollbar` component reading state at draw grows from.
- **A layout-algorithm change to bound the viewport.** Unnecessary — a bounded `Height`
  clamps the container while children overflow naturally and are clipped at draw.
- **Parent pointers / an ancestor-walk dispatch for wheel bubbling.** Not needed; the
  scrollable's rect already encloses the pointer, so a filtered hit-test suffices.
- **`SDL_SetRenderViewport` for the scroll translation.** Reused the existing draw-offset
  mechanism instead, keeping scroll consistent with drag and touching one code path.

## Exit criteria met

- [x] Scroll a list — wheel over the `Scrollable` translates the clipped content, clamped to `content − viewport`
- [x] Clipping — content is bounded to the 240px viewport; overflow rows are not drawn (verified by screenshot: Task 7–8 clipped)
- [x] Click a button (rebuild) — Add/delete buttons rebuild the tree
- [x] Scroll position survives — offset keyed by the stable `Scrollable` `StableKey`, unaffected by item churn
- [x] Side-table eviction — `Store.Retain` drops vanished keys each rebuild
- [x] No regression — `--test-mismatch` / `--test-unbalanced` / `--test-unclosed-pen` / `--test-leftover` still report their named errors
