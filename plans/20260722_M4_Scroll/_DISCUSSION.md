# M4 Discussion Log

## Was the M4 identity/store foundation still to be built?

**Context:** The roadmap frames M4 as "the widget-identity side table and a rebuild-surviving
store earn their keep," implying that infrastructure is M4 work. DESIGN.md still says "the
side table comes with the first stateful widget."

**Analysis:** Exploration of the current tree showed M3's interaction-pipeline work already
landed it: `KeyAssign.Run` assigns `Widget.StableKey` (a path hash of parentKey + Name +
discriminator) post-build, and `InteractionStore` (owned by `App`, outliving the arena)
already keys hover/press/drag/animation-clocks by `StableKey`. `BuildIndex`/`CurrentBuildPosition`
referenced in older docs no longer exist. The draw walk `SDLApp.DrawWidget(w, ox, oy)` already
threads a render-time `(ox,oy)` offset down the subtree for drag.

**Decision:** Treat M4 as **additive**. Scroll offset is one more per-key float on the
existing store; scroll translation reuses the existing draw-offset mechanism; no new identity
machinery. The roadmap/DESIGN prose is stale on this point.

---

## How to expose the scroll capability as a word — modifier vs container

**Proposal/Context:** First proposal was a `Scrollable()` **modifier** on any container
(most concatenative, reuses `VStack`). The user pushed back: "Maybe Scrollable should be
containers as well instead of just a modifier? For me the modifiers for a scrollable
container would be the direction (horizontal or vertical), clipping, etc. So the primitive
words would be `_Scrollable()`/`Scrollable_()`."

**Analysis:** The user's decomposition is cleaner and more in the spirit of the framework:
a `Scrollable` **container primitive** (paired `_Scrollable()`/`Scrollable_()` + delegate
block, exactly like `Stack.bf`), with **direction and clipping as modifiers** on it. This
makes clipping a first-class reusable capability (`Clip()` works on any container) rather
than a hidden side effect of scroll, and lets a scroll viewport be spelled as the composition
`Scrollable(...) ; Height(.Fixed(n)); Clip();`.

**Decision:** `Scrollable` is a container primitive carrying a `ScrollView` marker.
`Clip()`, `Vertical()`, `Horizontal()` are modifiers. A scroll viewport is composed, not
built-in.

---

## Naming collision: word vs type (the `Int`/`Float` hazard)

**Context:** DESIGN.md notes that a `using static` word cannot share a name with a type —
the type constructor wins resolution (why bare `Int()`/`Float()` words are impossible).

**Analysis:** Naming the clip component `Clip` and the modifier word `Clip()` would collide:
`Clip()` in a build body would construct the type, not call the word.

**Decision:** Name the component **`ClipRegion`** and keep the word **`Clip()`**. (Same
already-safe split as `ScrollView` component / `Scrollable` word, `OnScrollBehavior` /
`OnScroll`.)

---

## Scrollbar composition, and whether to include it

**Context:** The user wanted the scrollbar as "its own word attached to the widget… A
Scrollbar factored word with an OnScroll event handler similar to OnClick?" but was unsure
how it composes.

**Analysis:** Three shapes considered: (a) a `Scrollbar()` modifier attaching a component
whose `DrawOverlay` draws the thumb from the container's live offset + content/viewport ratio
(composable, reads state at draw, no rebuild coupling); (b) the thumb drawn by `ScrollView`
itself (welded, least composable); (c) defer. The scrollbar reads scroll state directly at
draw, so it does **not** depend on `OnScroll`.

**Decision:** **Defer the scrollbar.** M4 ships offset-only (wheel scrolls clipped content,
position survives). The `ScrollView`/`Clip` split + the store offset are the seam it grows
from. Kept `OnScroll` in scope separately (below).

---

## OnScroll — include now or defer?

**Context:** Nothing in the Todo demo reacts to scroll, and the (deferred) scrollbar reads
state at draw, so `OnScroll` has no consumer this milestone.

**Analysis:** `OnScroll` rounds out the event vocabulary next to `OnClick`/`OnDrag` and is a
near-copy of `OnDrag.bf` (a `Behavior` + get-or-create word). A wheel is a discrete impulse
with no capture, so it is a plain event consumer, not a gesture — simpler than drag.

**Decision:** **Include `OnScroll`.** `ScrollTracker` fires it on offset change; the demo
leaves it unused.

---

## Bubbling: reaching the scroll container from a wheel over a child

**Context:** Dispatch has no parent pointers and no ancestor walk; `HitTest` returns the
leaf-most widget. A wheel over a child `Label` would hit the label, which doesn't scroll.

**Analysis:** Two options — add a parent pointer + walk up, or a hit-test variant that finds
the nearest ancestor bearing the capability. But a scroll container's own rect **encloses its
viewport** (and therefore the pointer), so a top-down walk that keeps the *deepest widget
carrying a `ScrollView` whose rect contains the point* already resolves to the enclosing
scrollable — no parent pointer needed.

**Decision:** `ScrollTracker.FindScrollableAt` is a `HitTest`-style walk filtered to
`ScrollView` carriers. Bubbling falls out of the geometry.

---

## SDL3 specifics confirmed against the binding

- Clip: `SDL_SetRenderClipRect(SDL_Renderer*, SDL_Rect*)` — **integer** `SDL_Rect` (float
  `Rect` must be floor-origin / ceil-size converted); `null` clears. SDL keeps only one clip,
  so the `Painter` owns the stack + intersection.
- Wheel: `SDL_EVENT_MOUSE_WHEEL`; `event.wheel` carries `mouse_x`/`mouse_y` (window-relative
  pointer) and float `x`/`y` (scroll amounts, `y` positive away from the user).
