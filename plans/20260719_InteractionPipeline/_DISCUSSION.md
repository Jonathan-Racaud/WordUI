# Interaction Pipeline Discussion Log

## Reviewing the "Retained Interaction Variants" (layers) plan

**Proposal/Context:** An earlier plan proposed per-`Component`/`Property`
`InteractionLayer` tags. Each state (`IfHover`, `IfPressed`) produced variant
tree nodes tagged with a layer id; the draw pass filtered by "highest active
layer wins". The plan was reviewed against the future need for animation and
drag.

**Analysis:** The layer model held for discrete boolean states but failed the
future test:
- **No time.** `IsLayerActive` is a bool; animation needs a continuous `t` and a
  clock. The event-driven loop produces no frames at idle — hostile to animation.
- **No composition.** Variants clone a whole property and replace it, so two
  active states touching the same property type (hover→FontSize + focus→Color)
  clobber each other instead of merging.
- **Drag doesn't fit.** Drag is positional (needs a transform/offset + pointer
  capture), and "hover target changed" as a repaint trigger is wrong for a drag
  that stays on the same target while moving.
- **Positional identity.** Keying state by `BuildIndex` (a build-order counter)
  silently reassigns state to a neighbour when structure changes. The existing
  `Widget.Key` (stable-identity hook) was ignored.
- **Global per-type layer ids** contradicted "nesting = z-order".

**Decision:** Reject the layer model. Rework around draw-time resolution, since
property resolution already happens at draw (`TextComponent.DrawContent` reads
`TextStyleProperty` when it draws).

---

## Three reworked options (no layers)

**Proposal/Context:** With layers dropped, present three options differing on
*where resolved style lives and how much `Build()` changes*.

**Analysis:**
- **A — Draw-time Style Patches:** state bodies record field-level patches onto
  the widget; draw blends base ⊕ active patches. Smallest change; keeps "a widget
  owns its look"; field-level composition.
- **B — Centralized Controller:** a per-frame controller computes a `Key→style`
  table; components become dumb readers. Clean for adding state kinds, but adds
  indirection and machinery not needed yet.
- **C — Retained/Reconciled Tree:** replace destroy-and-rebuild with reconcile;
  persistent nodes carry state/animation/drag natively. Highest ceiling (the only
  one that natively does layout-affecting animation and live-reflow drag) but the
  biggest departure and risk.

**Decision:** Option A, with A's resolver + persistent store deliberately left as
the seam to graduate to C later. B's centralization trades away locality for
machinery the milestone doesn't need.

---

## Fork: does animation survive a mid-flight rebuild?

**Proposal/Context:** A hover fade at t=0.1s when app data changes and `Build()`
re-runs (arena freed). Transient vs persistent state.

**Analysis:** Transient (rebuild patches each build, persist only the clock) fits
the current model and is simpler, but a rebuild mid-animation can snap/restart.
Persistent (clocks + interaction state in a non-arena store keyed by stable id)
is robust but forces stable identity to become mandatory.

**Decision:** **Must survive rebuild.** → `InteractionStore` lives outside the
arena, keyed by `Widget.StableKey`. This also decided the identity work
(KeyAssign) and retired `BuildIndex`.

---

## Fork: what does "drag" mean?

**Proposal/Context:** Render-offset drag (cheap, no relayout) vs live reflow
(siblings shift as you drag) vs a staged approach.

**Analysis:** Reflow needs a per-move layout pass and more machinery; offset is a
bounds add at draw. The milestone doesn't need reflow yet, but the model
shouldn't have to be reworked to add it.

**Decision:** **Offset now, reflow later.** `DrawWidget` applies the dragged
subtree's offset at draw; the `DragState`/`DragTracker` seam extends to a
layout-only pass in a future phase. Pointer capture is included now so events
keep routing to the grabbed widget when the cursor leaves it.

---

## Fork: how is animation expressed?

**Proposal/Context:** Implicit transitions (any state-vs-base delta animates by a
default curve, CSS-like) vs explicit `Transition(...)` words vs both.

**Analysis:** Implicit is ergonomic but surprising (everything moves); explicit is
verbose but controlled and composes naturally with the concatenative word style.

**Decision:** **Explicit words.** `Transition(ms, curve, body)` marks the enclosed
fields animated; unwrapped state changes are instant. One duration/curve per patch
(last `Transition` wins); per-field `*Anim` flags decide which fields interpolate.

---

## Patch-mode word interception (the cost of Option A)

**Proposal/Context:** Reusing the concatenative styling vocabulary at draw-time
resolution means the styling words need two modes: base construction vs patch
recording.

**Analysis:** This is the same "modifiers must be state-aware" cost flagged in the
layer review — inherent to any resolve-at-draw approach that reuses the words. A
thread-static `sPatch` set by `IfActive` routes `Fill`/`Stroke`/`TextColor`/…
into the patch; block words `Background`/`Border` pass through their body; `Radius`
is a no-op in patch mode (not yet an animatable field). Field-level patches
compose, which the layer clones could not — so the cost buys real capability.

**Decision:** Accept it. Record helpers (`RecordFill`, …) keep each word a
one-line guard: `if (RecordX(v)) return;`.

---

## Clock initialization bug (found during verification)

**Proposal/Context:** New animation clocks were initialized `P = active ? 1 : 0`.

**Analysis:** A hover turning active created a clock already at `P=1`, so the fill
snapped to target instead of fading in.

**Decision:** New clocks always start at `P=0` (the base) and animate toward the
target. Fade-out works because flipping `target=false` eases `P` back down while
`NeedsTick` keeps the loop rendering.

---

## Verification approach

**Proposal/Context:** How to validate without a test harness for input.

**Analysis:** `ps %cpu` reports a lifetime average inflated by startup; it read
~4% even when idle. Interactive hover/drag needs pointer input, but the session
runs on the user's live X/Wayland display — injecting synthetic mouse events would
move their real cursor.

**Decision:** Measure idle CPU via `/proc/<pid>/stat` utime+stime delta over a 2s
idle window → **0 ticks (0.0%)**, confirming the loop blocks. Confirm patch
recording via the tree dump (`states=2` on the `+` button). Skip synthetic input
injection. Regression `--test-*` apps run headless and still emit named errors.
