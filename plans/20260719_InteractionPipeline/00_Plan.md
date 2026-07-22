# Interaction Pipeline — Draw-time Style Patches

**Goal:** Replace the busy-loop, rebuild-per-state pipeline with an event-driven,
draw-time-resolved one that fixes idle CPU + missed clicks and makes hover,
animation, and drag first-class — done when idle CPU is ~0%, clicks never drop,
and `IfHover`/`Transition`/`OnDrag` work without per-frame rebuilds.

> Supersedes the earlier "Retained Interaction Variants" design (per-Component
> interaction layers), which was rejected during review — see `_DISCUSSION.md`.

## Plan

1. **Animation primitives** — leaf helpers with no dependencies
   - `Color.Lerp(a, b, t)` and a scalar `Lerp.F`
   - `Easing` enum (Linear / EaseInOut / Spring) mapping progress → eased progress

2. **Stable identity (F2)** — replace positional/pointer identity
   - Add `Widget.StableKey`; assign it in a deterministic post-build path walk
     (`KeyAssign`: `hash(parentKey, Name, Key>=0 ? Key : siblingIndex)`)
   - Remove `Widget.BuildIndex` / `UI.CurrentBuildPosition` (positional identity)

3. **Persistent interaction store (F3)** — state that outlives the arena
   - `InteractionStore` owned by `App`, non-arena, keyed by `StableKey`
   - Holds hover/press booleans, animation clocks `(key,state)→{p,target,dur,curve}`,
     and drag capture (`BeginDrag`/`UpdateDrag`/`EndDrag`, `DragOffset`)
   - `NeedsTick` (any unsettled clock or active drag); `Tick(nowMs)` advances/prunes

4. **Event-driven loop (F1)** — `SDLApp.Run` rewrite
   - Block in `SDL_WaitEvent` when idle; `SDL_WaitEventTimeout(16)` while `NeedsTick`
   - Drain queue each wake, coalescing mouse motion to the last position
   - `mDirty` → rebuild+layout+render; else `mNeedsRepaint || NeedsTick` → render only
   - Time from `SDL_GetTicks()`

5. **Draw-time style patches (Option A core)** — no layers
   - `IfActive<T>` always runs its body, recording a field-level `StatePatch` into
     one generic `InteractionStyle` property (tagged with the state)
   - Styling words (`Fill`/`Stroke`/`StrokeWidth`/`TextColor`/`FontSize`) record onto
     the patch when `InPatch`; `Background`/`Border` pass through, `Radius` is a no-op
   - `Transition(ms, curve, body)` marks the enclosed fields animated
   - `StyleResolve` blends active patches over base **field-by-field**; animated
     fields interpolate via the store clock (`IsActiveFor(StableKey)` gates each)
   - Drawing components (`Interior`/`Boundary`/`Text`) resolve instead of reading raw

6. **Trackers via the store** — repaint, not rebuild
   - `PressTracker` keys press/click by `StableKey`, requests repaint; click still
     dispatches `OnClick` (which may `Invalidate()` for data changes)
   - `HoverTracker` updates hover on motion, requests repaint
   - Generalize handler ownership `List<ClickHandler>` → `List<Delegate>`

7. **Drag (F5)** — render-time offset with a reflow seam
   - `OnDrag` behavior + `DragTracker` with pointer capture
   - `DrawWidget` applies the dragged subtree's offset at draw (no relayout)

8. **Decisions made in plan phase**
   - **Drop layers for field-level patches** — patches compose concurrent states and
     carry time/position; layers are boolean-only, whole-property, timeless
   - **Animation must survive rebuild** → persistent store keyed by `StableKey`
   - **Drag = render offset now, live reflow later** behind the same tracker
   - **Animation = explicit `Transition` words**, not implicit CSS-style transitions
   - **Layout uses base values**; layout-affecting animation deferred behind a seam
   - **Recommend Option A** over B (central controller) / C (retained tree)
