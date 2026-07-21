# Roadmap — from tree-construction to a minimal GUI framework — 2026-07-18

Planning session that turns the post-cleanup wish-list (basic words/widgets, modifiers,
event handling, layout, rendering, memory & runtime constraints) into an ordered sequence
of runnable milestones. Records the decisions made and the alternatives set aside, per the
`plans/` habit.

## Starting reality (the line, not a phase)

Already built and working (see `DESIGN.md`, `src/`): the concatenative word vocabulary
(Label, Button, HStack/VStack, Spacer), the modifier set, the sealed-`Widget` +
component-bag model, the `UI` core-op API, runtime stack diagnostics, and the
build → invalidate → rebuild loop over a `BumpAllocator` arena. "Basic words/widgets,
modifiers" is therefore the **starting line**, not remaining work — new widgets/modifiers
from here are incremental factoring, not a milestone.

The stand-in renderer is a console tree dump; "input" is `SimulateClick(label)` matched by
text. There is no window, no pixels, no real event source yet.

## Reframing the wish-list

The six items are not peers and not independently sequenceable:

- **basic words/widgets, modifiers** — done (above).
- **memory & runtime constraints** — *not a phase*. It is a cross-cutting concern to be
  **measured**, not built upfront (DESIGN.md already commits to "memoize only when
  measurably needed"). Threaded through the milestones as checkpoints; see below.
- **layout, rendering, event handling** — a hard dependency spine, not a menu:

```
SDL2 (window + event loop + renderer + event source)
        │
        ▼
Layout pass  ───────────────►  produces a Rect per widget
        │                               │
        ├───────────────┐               │
        ▼               ▼               ▼
   Rendering        Input hit-test   (rects are the shared currency)
   (draw rects/     (pointer → rect
    text)            → Clickable)
```

Layout is the gate: rendering needs rects to draw; input needs rects to hit-test. Layout in
turn waits on **text measurement**. Rendering waits on **text rasterization**. Text/fonts
is therefore the sleeper and it appears **twice**.

**Decoupling worth banking:** layout runs on the *transient* tree each frame and stores
rects on the transient `Widget`; it does **not** need the widget-identity side table.
Identity is forced only by *persistent* state (scroll offset, focus, caret) — so the
identity work is late (M4+), not a prerequisite for a running GUI.

## Sleepers, named and budgeted

1. **Text/fonts — appears twice.** Measurement gates layout of any text (M1, `TTF_SizeUTF8`);
   rasterization gates drawing text (M1, `TTF_RenderUTF8_Blended` → texture). SDL2_ttf covers
   both, so the sleeper is small — but the layout pass calls SDL_ttf directly, so the
   framework touches the backend during M1 no matter what.
2. **Clipping** — hides inside scroll (M4). `SDL_RenderSetClipRect`.
3. **Focus routing** — hides inside text input (M5): focus traversal, focus-follows-click,
   tab order. A subsystem, not a field.
4. **Window resize / DPI** — hides inside "a window" (M0/M1): layout must react to resize;
   text metrics must react to DPI scale.
5. **Repaint-vs-rebuild** — hides inside hover (M3). Without it you either rebuild the whole
   tree every frame (breaks rebuild-on-invalidate) or fail to reflect hover.
6. **Side-table eviction** — hides inside persistent state (M4): when a keyed widget
   disappears, when is its retained state freed? This is the real "memory constraint," and
   it does not exist until M4.

## Decided this session: direct SDL2 now, abstraction deferred

**Revises Locked Decision 6 the same day it was made.** The prior decision was a
renderer/platform-agnostic seam (framework never sees the backend). Reversed explicitly, with
a stronger argument for the project's actual goal:

- The thesis under test is *"can concatenative-style UI work for real apps?"* — answered
  entirely on the framework side (words, layout, composition), where the backend's identity
  is irrelevant. A seam now spends the learning budget off-thesis.
- A one-implementation interface is usually the wrong interface (the critique that motivated
  the seam in the first place). The consistent conclusion is not "design it carefully
  anyway" but "don't design it until SDL2 has shown where the framework genuinely touches the
  backend." **The abstraction will be better extracted from working code than drawn blind.**

So: **the framework uses SDL2 directly for now. Renderer/platform abstraction is deferred**
until the concatenative model is validated.

**The one discipline that keeps "later" cheap (not an abstraction — just tidiness):**
localize the SDL2 calls. Drawing flows through *one concrete rendering module* — a plain
`Painter` class that calls SDL directly, no interface, no virtual dispatch — rather than
`SDL_RenderFillRect` sprinkled through `Component.Draw` overrides across the tree. This costs
nothing now (a concrete class is less work than scattered calls) and turns the eventual
abstraction into a mechanical *extract-interface* refactor instead of a rewrite. Same for the
event source: adapt `SDL_Event` into a WordUI `InputEvent` at one boundary so hit-testing and
dispatch never see SDL types.

**Grounding fact:** Beef ships a first-party `BeefLibs/SDL2` binding covering core (window,
events, `SDL_Renderer` with `FillRect` + textured quads + `SetClipRect`), `SDL2_ttf` (measure
+ rasterize), `SDL2_image`, `SDL2_mixer`, plus an `SDLApp` scaffold.

## Milestones (each ends in a runnable demo)

### M0 — A window that opens
SDL2 window + event loop + clear-to-color + close on ✕. Minimal WordUI involvement; stand up
the SDL2 window/loop directly.
**Exit:** a colored window you can close. *De-risks the one true unknown — does Beef+SDL2
link and run here — before any framework code depends on it.*

### M1 — The static tree renders
`Measure`/`Draw` hooks on `Component`; the flex algorithm DESIGN specifies
(constraints-down/sizes-up, sum-main / max-cross, leftover→`Spacer`); one concrete `Painter`
module over `SDL_Renderer` + `SDL2_ttf` (drawing localized here, per the decision above).
Rects stored on transient widgets. Layout calls `TTF_SizeUTF8` directly to measure text.
**Exit:** the counter UI appears, laid out, in the window — not yet clickable.
**Sleeper lands here: text measurement + rasterization. Budget it by name.**

### M2 — It's alive  ← headline; a real place to stop
Real SDL pointer events (adapted to `InputEvent` at the boundary) → hit-test rects → dispatch
`Clickable` → `Invalidate` → rebuild → repaint. Delete `SimulateClick`.
**Exit:** clicking + / − in the window changes the visible count.
*This is "a minimal framework for simple GUI apps" — the stated goal. Re-decide priorities
here (see Open questions).*

### M3 — Interaction states
Introduces the **repaint-vs-rebuild split** (hover must not trigger a tree rebuild) and the
declarative `HoverColor`/`PressColor` state→style path DESIGN earmarked.
**Exit:** buttons highlight on hover with no rebuild.
*Constraint checkpoint: no per-frame allocation in the repaint loop.*

### M4 — First persistent state: scroll
The widget-identity side table (parent path + call index + `Key`) and a rebuild-surviving
store earn their keep. Pulls in **clipping** (`SDL_RenderSetClipRect`) and wheel events.
Scroll, not text-input, is the identity vehicle: one float per key, no focus/keyboard/caret
drag-in.
**Exit:** scroll a list, click a button (rebuild), scroll position survives.
*Constraint checkpoint: side-table eviction — when a keyed widget disappears, free its
retained state.*

### M5 — Text input, focus, keyboard
Own milestone: focus routing + caret + key events + editing are each non-trivial. Depends on
M4 identity (caret/focus persist) + keyboard events + M1 measurement (caret positioning).
**Exit:** type into and edit a text field. *"Simple apps" becomes "forms."*

## Earmarks (low precision; re-decided at M2)

Memoization (only if profiled slow) · `Model<T>` observables + `Bind` (only if whole-tree
rebuild proves too slow) · animations (needs M4 identity + M3 repaint loop + a clock) · drag
protocol (an input protocol, not a component) · image/asset pipeline (`SDL2_image` is
present) · complex-object primitives · accessibility (semantic roles) · **renderer/platform
abstraction + a second backend (GL/software)** — the deferred seam, extracted from the
concrete `Painter`/event boundary once the concatenative model is proven · core/widgets
package split (mechanical, thanks to cross-project extensions).

## Runtime-constraint checkpoints (threaded, not front-loaded)

- M1: rects on transient widgets (freed with the arena).
- M3: repaint loop allocates nothing per frame.
- M4: the real one — side-table eviction policy for retained state of vanished keys.
- After M2 and M5: profile a real app before any memoization/observer work.

## Open questions (re-decide when M2 runs)

After the minimal GUI app exists, which direction leads: (a) breadth — more widgets +
layout completeness (wrap, alignment, constraints); (b) interaction polish — hover/press →
animation; (c) input richness — text fields/forms? Recommendation stands as M3→M4→M5, but
priorities may shift once a real app is on screen. Do not pre-commit past M2.

## Roads not taken this session

- **Renderer/platform-agnostic seam from day one (proposed and reversed, same session).**
  Set aside to keep focus on the thesis (does concatenative UI work?) and because a
  one-implementation abstraction is best extracted from working SDL2 code later, not designed
  blind now. Kept alive only as the cheap "localize SDL2 in one concrete module" discipline
  so the future extraction is mechanical.
- **Committing to a fixed rendering depth (borrow-canvas vs build-renderer vs software).**
  Moot under direct SDL2: SDL_Renderer + SDL2_ttf is the renderer; a build-your-own renderer
  is a far-future alternate backend, not a near choice.
- **"Memory & runtime constraints" as an early phase.** Set aside: premature optimization;
  reframed as measured checkpoints threaded through milestones.
- **Widget identity before layout.** Set aside: layout works on the transient tree and needs
  no identity; identity is deferred to the first persistent-state milestone (M4).
