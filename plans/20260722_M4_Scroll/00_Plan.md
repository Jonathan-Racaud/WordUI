# M4 — Scrollable widgets, clipping, wheel events

**Goal:** Add the framework's first persistent, rebuild-surviving state — a scroll offset —
with clipping and mouse-wheel events, proven by a functional Todo app that adds an item,
removes an item, and scrolls a clipped list whose scroll position survives the rebuild.

## Plan

1. **Reuse the M3 identity + store foundation** — no new identity machinery
   - `Widget.StableKey` (path hash from `KeyAssign`) and the rebuild-surviving
     `InteractionStore` already exist; scroll offset is one more per-key map on the store.
   - The draw walk `SDLApp.DrawWidget(w, ox, oy)` already threads a render-time offset for
     drag — scroll translation reuses it, no relayout.

2. **Vocabulary (composed from smaller words, per the concatenative thesis)**
   - `Scrollable` **container primitive** (`_Scrollable()`/`Scrollable_()`/`Scrollable(body)`),
     a vertical stack carrying a `ScrollView` marker component.
   - `Clip()` **modifier** attaching a reusable `ClipRegion` component — clipping is its own
     capability, usable on any container, not welded to scroll.
   - `Vertical()`/`Horizontal()` **modifiers** setting `StackLayout.Axis`.
   - `OnScroll(handler)` **behavior word** (Behavior bag), mirroring `OnClick`/`OnDrag`.

3. **Wheel input** — `ScrollTracker`, modeled on `DragTracker`
   - `HandleWheel` finds the deepest `ScrollView` under the pointer (bubbling without a parent
     pointer, since the container rect encloses the viewport), clamps the offset to
     `content − viewport`, updates the store, fires `OnScroll`, and requests a repaint.
   - `SDLApp.HandleEvent` adapts `SDL_EVENT_MOUSE_WHEEL` → `InputEvent` at the single boundary.

4. **Clipping + translation in the draw walk**
   - `Painter` gains a clip stack over `SDL_SetRenderClipRect` (float `Rect` → integer
     `SDL_Rect`, with nested-clip intersection).
   - `DrawWidget` pushes the clip and folds `−offset` into the child offset before recursing,
     pops before the overlay pass so borders stroke the full box.

5. **Side-table eviction (the M4 constraint checkpoint)**
   - `KeyAssign.Run` collects the live key set; `App.RebuildIfNeeded` calls
     `Store.Retain(live)` to drop hover/press/scroll entries for vanished keys.

6. **The Todo demo — `Program.bf`**
   - `TodoRow` factored word (HStack + Label + Spacer + delete Button), keyed on item id.
   - `Scrollable(...) ; Height(.Fixed(240)); Clip();` viewport; Add/remove buttons.

## Decisions made in plan phase

- **`Scrollable` is a container primitive, not a flat modifier** (user preference): the
  scroll capability reads as a distinct widget, with direction/clipping as modifiers on it.
- **Clipping is a separate composable capability** (`Clip()`), so a scroll viewport is the
  composition `Scrollable + bounded Height + Clip`, demonstrating the framework's philosophy.
- **Scrollbar deferred**: M4 is offset-only; the `ScrollView`/`Clip` split is the seam a
  future `Scrollbar` component grows from.
- **`OnScroll` included**: rounds out the Click/Drag/Scroll event vocabulary even though the
  Todo demo doesn't consume it.
- **No flex-algorithm change**: a bounded `Height` keeps the oversized content from
  propagating up; children overflow naturally and are clipped at draw.
