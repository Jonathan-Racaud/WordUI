# WordUI architectural refactor plan

## Guiding principles

This refactor should **not** turn WordUI into a Flutter clone.

Flutter provides useful answers to difficult runtime problems:

* retained identity
* rebuild reconciliation
* rendering separation
* scheduling
* invalidation

However, WordUI's defining characteristics must remain:

1. **The user-facing API remains concatenative.**

   * Words compose behavior.
   * Higher-level UI concepts are factored from lower-level words.
   * The framework and users should use the same vocabulary system.

2. **Widgets remain descriptions, not objects with behavior.**

   * A widget is a temporary result of executing words.
   * Persistent behavior belongs to runtime structures.

3. **Capabilities remain user-extensible.**

   * New properties, components, behaviors, and states should not require modifying framework internals.
   * The framework should provide mechanisms, not concepts.

4. **State is owned by capabilities, not by nodes.**

   * Nodes provide identity and storage.
   * Capabilities decide what state they need.

5. **Rendering remains a separate concern.**

   * Components can provide specialized rendering.
   * Painter remains backend-independent.
   * Rendering extensibility should not compromise framework control.

---

# Phase 1 — Establish the architectural boundaries

## Goal

Clarify and stabilize the concepts that currently overlap:

* Widget
* Component
* Property
* Behavior
* Interaction state
* Runtime identity

Before adding features, the framework needs a clear separation between:

### Build-time structures

Created by executing words:

* widget descriptions
* attached capabilities
* configuration

### Runtime structures

Persist across rebuilds:

* identity
* state storage
* lifecycle
* subscriptions

### Output structures

Consumed by later phases:

* layout information
* render information
* accessibility information

---

## Tasks

### Define Widget as a pure description

Ensure widgets do not become long-lived objects.

The widget should describe:

* what capabilities exist
* what children exist
* what configuration exists

It should not own:

* focus state
* animation state
* scroll position
* input history

---

### Introduce the retained runtime concept

Create the conceptual equivalent of Flutter's Element tree, but avoid Flutter terminology and ownership rules.

The runtime structure should provide:

* stable identity
* parent/child relationships
* lifecycle
* access to persistent storage

It should not know:

* what a button is
* what hover means
* what animation means

---

### Define capability ownership rules

Establish rules such as:

* Components may request persistent state.
* Behaviors may request persistent state.
* Properties should remain mostly immutable descriptions.
* State storage is generic.

---

## Completion criteria

The framework has a clear answer to:

> "What survives rebuilds?"

without introducing framework-owned widget state.

---

# Phase 2 — Introduce generic state storage

## Goal

Replace specialized interaction state handling with a general capability-based state mechanism.

The purpose is not to create a global UI state system.

The purpose is:

> Allow any capability to store information across rebuilds.

---

## Tasks

### Replace interaction-specific assumptions

Move away from a model where state is only:

* active/inactive
* pressed/not pressed
* hovered/not hovered

Support arbitrary state:

Examples:

* hover state
* pressed state
* cursor position
* scroll offset
* animation progress
* user-defined application state

---

### Separate state from conditions

Do not make every state a condition.

A state is data.

A condition is a query over state.

Examples:

State:

* hover tracker
* animation progress
* text buffer

Condition:

* currently hovered
* animation completed
* text empty

---

### Preserve conditional words

Conditional words remain build-time operations.

Their responsibility:

1. Query relevant state.
2. Decide whether to execute their body.
3. Produce a different widget description.

They do not become rendering conditions.

---

## Completion criteria

A user can create a new stateful capability without:

* modifying Node
* adding framework fields
* adding framework-specific logic

---

# Phase 3 — Implement retained identity and reconciliation

## Goal

Make rebuilds efficient and enable advanced UI features.

---

## Tasks

### Add stable identity mapping

The runtime must determine:

* whether a previous node corresponds to a new widget description
* whether state can be reused
* whether lifecycle events should happen

---

### Introduce state lifetime management

Define:

* creation
* reuse
* cleanup
* disposal

for persistent capability state.

---

### Avoid widget-owned state

A widget disappearing from a build should not automatically mean its state disappears immediately.

The runtime should manage lifetime.

---

## Completion criteria

Features requiring continuity work correctly:

* text cursor
* focus
* animations
* scroll position

---

# Phase 4 — Build the invalidation system

## Goal

Allow capabilities to update the UI without rebuilding everything unnecessarily.

---

## Tasks

Create distinct invalidation levels:

### Full rebuild

Used when structure changes.

Examples:

* conditional children
* dynamic composition

---

### Layout invalidation

Used when geometry changes.

Examples:

* text changes
* resizing

---

### Paint invalidation

Used when only appearance changes.

Examples:

* animation progress
* color changes

---

### Define who can invalidate

Capabilities should be able to request invalidation.

The framework should not need to know why.

---

## Completion criteria

A capability can update itself without requiring special framework support.

---

# Phase 5 — Introduce scheduling and frame lifecycle

## Goal

Support time-dependent capabilities.

---

## Tasks

Create a framework scheduler responsible for:

* frame progression
* time updates
* tick subscriptions

---

Capabilities that need time receive ticks:

Examples:

* animation
* blinking cursor
* physics
* inertia scrolling

---

The scheduler should not know what is being animated.

It only provides:

* time
* execution opportunity

---

## Completion criteria

A user can create a custom time-based behavior without modifying the framework.

---

# Phase 6 — Refactor interaction capabilities

## Goal

Rebuild current interaction features on top of the generic capability system.

---

## Tasks

Migrate:

* hover
* pressed
* focus
* keyboard input
* pointer capture

into behaviors and states.

---

The framework should no longer think:

"Buttons have pressed states."

Instead:

"Some capability tracks pointer interaction."

---

## Completion criteria

A custom user-defined component can participate in interaction without inheriting from framework widgets.

---

# Phase 7 — Introduce a retained render layer

## Goal

Separate declarative composition from rendering persistence.

---

## Tasks

Create a render representation between components and Painter.

The purpose:

* retain expensive rendering information
* cache resources
* support efficient updates

---

The architecture becomes:

```
Words
 |
Widget descriptions
 |
Runtime nodes
 |
Render representation
 |
Painter
 |
Backend
```

---

The render layer should not replace components.

Components remain the user extension point.

---

## Completion criteria

A custom component can:

* define its rendering
* participate in layout
* invalidate its rendering

without modifying the renderer.

---

# Phase 8 — Expand Painter API carefully

## Goal

Provide enough rendering power without exposing backend details.

---

## Tasks

Expand Painter with backend-independent concepts:

* paths
* transformations
* clipping
* text drawing
* images
* gradients
* effects

---

Avoid exposing:

* GPU concepts
* backend objects
* platform-specific operations

---

## Completion criteria

Advanced custom visuals can be implemented entirely through components.

---

# Phase 9 — Layout system maturation

## Goal

Bring layout closer to mature frameworks.

---

## Tasks

Improve:

* constraint propagation
* intrinsic sizing
* text measurement
* baseline alignment
* scrolling containers
* complex arrangements

---

Keep layout capabilities compositional.

Avoid creating large widget classes.

---

## Completion criteria

Common UI structures can be factored from vocabulary words.

---

# Phase 10 — Accessibility architecture

## Goal

Create accessibility without coupling it to rendering.

---

## Tasks

Introduce a separate accessibility representation.

A component may produce:

* visual representation
* interaction representation
* accessibility representation

---

Accessibility should not inspect Painter commands.

---

## Completion criteria

A user-created component can expose accessibility information without modifying framework internals.

---

# Phase 11 — Advanced application-level capabilities

Only after the foundation is stable.

Possible additions:

* reactive application state helpers
* data binding
* async task integration
* animations library
* gestures
* transitions
* theming
* persistence

These should all be built as vocabulary and capabilities, not framework primitives.

---

# Final target architecture

The end state should look like:

```
                Concatenative words
                       |
                       v

              Transient Widget Tree

                       |
                       v

                Runtime Node Tree
        (identity + lifecycle + state storage)

                       |
        +--------------+--------------+
        |              |              |

   Components     Behaviors     Properties

        |              |
        +--------------+

              Invalidation / Events / Ticks

                       |
                       v

             Layout + Render + Accessibility

                       |
                       v

                    Backend
```

The important design constraint:

**The runtime becomes more sophisticated, but the user model becomes simpler.**

Users should still think:

> "I compose words to describe capabilities."

They should not need to know:

* there is reconciliation
* there are nodes
* there are state slots
* there is scheduling
* there are render objects

Those mechanisms exist to preserve the concatenative model at scale, not replace it.

---

# Phase 2.1 — Review findings & remediation (2026-07-22)

Architectural review of Phase 2 (generic state storage) identified four classes of issue.
The fixes below were applied; the remainder is deferred to planned phases.

## Fixed (this phase)

| # | Finding | Fix |
|---|---|---|
| 4a | Stale state slots accumulate in reused Nodes (memory leak) | `Node.PruneState/PruneClocks` + `StateSlots.FrameworkIds` + live-slot collection in `App.ReconcileWidget` |
| 4b | Clock key collision risk (two IInteractionState types sharing a StateId) | Runtime collision check in `Interaction.RecordPatch` — fails with named error |
| 4c | Dictionary mutation during enumeration in `Node.Tick()` | Collect-then-apply pattern via `List<(int, Clock)>` |
| 4d | `StateSlot<T>.Get` no null guard | `if (node == null) return default;` |

## Design artifacts added

- `src/Core/ITickable.bf` — target interface for Phase 5 tick dispatch
- `Node.bf` — `[Phase5Extract]` tags on `Clock`, `Blend()`, `Tick()`, `NeedsTick`
- `DESIGN.md` — per-node state slots/pruning section + time-based state direction

## Deferred to planned phases

| Issue | Phase | Rationale |
|---|---|---|
| Animation clocks in Node (issue 1) | Phase 5 | Scheduler + tick subscriptions replace hardcoded clocks with `ITickable` |
| `App.Instance` / `Node.Blend()` public (issue 3) | Phase 5/6 | `Blend()` disappears with clock extraction; `App.Instance` narrows as interaction features migrate to capabilities |
| Reconcile-time state validity hooks (issue 4e) | Phase 3 | State lifetime management: creation/reuse/cleanup/disposal callbacks |
| `mNodeIndex` unbounded growth under key churn (issue 4f) | Phase 3 | State lifetime management covers index cleanup for dead keys |
