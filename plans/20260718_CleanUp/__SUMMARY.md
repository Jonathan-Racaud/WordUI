# CleanUp Session Summary — 2026-07-18

How the reorganization went from "split the prototype into folders" to the sealed-Widget +
component-bag architecture with a stack-based construction API. This records the full
brainstorming path, including the branches that were explored and dropped, so future
sessions can see *why* the code looks the way it does.

## Starting point

The first prototype (five flat files) had validated the concatenative API with four locked
decisions: Rule B modifiers (act on stack top; closed containers are modifiable), hybrid
data passing (stack form primitive, argument overloads as sugar), delegate-block
containers over public `_X()`/`X_()` primitives, and rebuild-on-invalidate with a
`BumpAllocator` arena. Runtime diagnostics (typed stack items, named markers, stack-
hygiene assert, `PrintStack`) stand in for Factor's static stack-effect checker.

## The cleanup request

Goals stated up front: maintainable/extensible/modular — adding a widget must not mean
editing one shared file each time. Specific asks:

- **Widget**: is one fat class holding all properties acceptable? Should property sets be
  per-widget? Would focusing them conflict with this kind of framework?
- **UI words as extensions**: open/close pairs, widget words, modifiers, diagnostics each
  in their own file, all building on a small core; same philosophy for App.
- **Primitives**: refactor to a developer-facing set (Str, Int, Float, Bool); Image was
  mislabeled as a primitive and is really an asset concern — removed/deferred; complex
  objects deferred to their own planning.
- **No tests** during experimentation; roadmap planning to follow the cleanup.

Key enabler verified early from the Beef compiler test suite (`IDEHelper/Tests/src/
Extensions.bf`): `extension` blocks add members to a type, can access its **private**
members, and work **across projects** — so one-file-per-concern works for the framework,
and app developers can define words via `extension UI` in their own project.

## Iteration 1 — typed widget hierarchy (superseded)

First plan: `TextWidget : Widget` (text props) with `LabelWidget`/`ButtonWidget` under it,
`ContainerWidget` for stacks, words as `extension UI` per file, a `Words/` folder.
Feedback that reshaped it:

- Composition should be favored over inheritance for widget building.
- Modifiers and Handlers deserve their own folders; Primitives belong in `Core/`; the
  `Words/` folder was framework-developer jargon, foreign to applicative-language users —
  dropped.

## Iteration 2 — flat widgets + component objects (superseded)

Second plan: no intermediate classes; capabilities as component objects (`TextStyle`,
`Clickable`) attached via null-default virtual accessors that each component's file
injects with `extension Widget`. Modifiers query capability, not type — errors get
*sharper* ("FontSize: StackWidget has no text style").

## The ECS detour (explored, consciously not adopted)

Seeing the `Components/` folder, the question arose: flat ECS UIs exist (research +
Bevy) — and concatenative languages are "flat" too. Is PFUI converging on ECS? Buttons as
composed primitives + behavior components (OnClick/OnHover/OnDrag words attaching
Hoverable/Clickable/Dragable), animations later as systems + components, a small core with
widgets as a separate package on top.

The critique that came out of stress-testing it:

- **Two different "flats."** The stack is flat in *construction order*; ECS is flat in
  *storage*; the UI remains a **tree** in logic — layout, hit-testing, bubbling, clipping,
  z-order are tree algorithms. ECS stores the tree awkwardly (Parent/Children components);
  Bevy literally mirrors a separate layout tree. The genuine overlap is philosophical
  instead: both paradigms are anti-encapsulation — small orthogonal operations (words /
  systems) over open shared data (stack / stores), composed by ordering.
- **ECS collides with rebuild-on-invalidate** (the big one). ECS assumes persistent
  entities; PFUI throws the tree away per invalidate. Resolution if ever adopted: entity
  ID = stable widget ID (parent path + call index + `Key`), build-scoped stores
  repopulated per rebuild, persistent stores (hover/press/tween/scroll) surviving keyed by
  the same IDs. ECS doesn't remove the retained-vs-rebuild decision; it sharpens it.
- **Systems are a pipeline, not free composition**: Input → rebuild → Animate → Layout →
  Render; every new system needs placement, unlike words which factor freely.
- **Beef is a good ECS host** (real value-type arrays, no GC) with named footguns:
  by-value struct access needs `ref` returns; no borrow checking (refs dangle if a store
  grows); no variadic generics — which forbids a query DSL and thereby *enforces* ECS-lite.
- **Wishful-thinking spots**: hover is mostly *state → style variant*, not a callback
  (needs a declarative path like `HoverColor(…)` or composed buttons drown in
  boilerplate); drag is an input *protocol* (capture, thresholds, routing), not a
  component attachment; animations-as-components only work once stable identity exists.
- Verdict: park ECS. The composition front-end (capability components, modifier words as
  attachment) survives regardless; the storage back-end (entities/stores/systems) can be
  swapped in later behind `Get<T>`/`Attach` if ever justified. The component bag chosen
  below is the deliberate halfway house.

## Iteration 3 — the capability-query challenge

Concern raised: does the virtual-accessor pattern mean touching the base `Widget` for
every new capability, locking users out? Two-part answer:

1. Misreading corrected — the accessor is injected by `extension Widget` from the
   component's own file (or the *user's own project*); the base class file is never
   edited.
2. But the deeper objection stood: accessor + override is still class-shaped
   extensibility. The requirement crystallized as: **new widgets are created by factoring
   words, like in Factor — not by subclassing.**

Proposed resolution: kill widget subclasses entirely — one sealed `Widget` (Name, Key,
Padding) + a component bag with `Get<T>`/`Require<T>`/`Attach`; even `Children` becomes a
component, dissolving `ContainerWidget`.

## The Factor challenge (the decisive argument)

Pushback: Factor itself subclasses gadgets — why would a stricter approach be better than
what experienced concatenative programmers use? Demand: no agreement out of politeness.
The honest analysis:

- Factor subclasses because (a) **subclassing is Factor's dispatch mechanism** — generic
  words dispatch on class; (b) **gadgets are retained, long-lived, stateful actors** —
  exactly what behavior-carrying classes are for; (c) their subclassing is already open
  extension (no framework edits) — so "inheritance is un-concatenative" is *not* a valid
  argument, and the earlier "improvement on Factor" framing was retracted.
- It doesn't transfer because PFUI chose rebuild-on-invalidate: its widgets are
  **transient descriptions**, not actors — Flutter's regime, where dumb-data widgets are
  the standard shape.
- **The bag does not eliminate dispatch — it relocates it.** Per-kind behavior (measure,
  draw) still needs polymorphism; it moves to the `Component` base class as virtual
  hooks. Final formula: **inheritance for behavior polymorphism (Component subclasses,
  one level), composition for capability mixing (widgets as bags)** — each mechanism
  where it's the right tool. What inheritance is genuinely bad at is capability
  *combinations* (ClickableImage, HoverableClickableLabel…), which bags handle trivially.
- Keeping one-level widget subclasses wouldn't be wrong, but with transient widgets they'd
  be empty names duplicating the bag — two overlapping mechanisms with a fuzzy boundary.

Design was then shown concretely: framework internals (Component hooks, sealed Widget,
words for Label/Button/Stack, attach-on-demand OnClick) and three user tiers — factored
word (90% case, zero classes), new capability (component + modifier word, user project),
new drawable primitive (component overriding behavior hooks).

## The construction-API refinement

Proposal: embrace the stack fully inside widget words — `NewWidget("Label"); Attach(…)`
instead of `let w = NewWidget(…); w.Attach(…); PushWidget(w)`. Feedback:

- The proposed sketch contained an instructive bug: `Label`'s text arrives on the stack,
  so `NewWidget` must come *after* popping inputs — Factor's own **pop-inputs-first**
  discipline surfacing in Beef. (Now documented in DESIGN.md.)
- Decisive pro: with the widget on the stack during construction, **widget words can
  reuse modifier words as defaults** (`NewWidget("Button"); …; FontSize(14);`) and default
  sets factor into ordinary words — the framework becomes written in its own word
  language, the essence-of-concatenative payoff.
- Genuine new con: a misplaced `Attach` silently hits the previous sibling. Mitigations:
  `Attach` rejects duplicate component types (named error), plus the existing stack/tree
  diagnostics.
- Adopted; containers became fully stack-based too: closing word pushes the container,
  attaches its layout component, `CloseContainer(name)` collects children beneath it.

## Implementation results

Executed per `00_plan.md`: Core/Components/Widgets/Modifiers/Handlers/Diagnostics
folders, all words as extensions over the public core-op API, demo preserved, all
negative tests pass (`--test-mismatch`, `--test-unbalanced`, new `--test-leftover`).

Empirical findings during implementation:

- **`Int(…)`/`Float(…)` words are impossible in Beef** — corlib struct names `Int`/`Float`
  win resolution over `using static` methods (`Str`/`Bool` are free). Resolution: the
  `PushStr/PushInt/PushFloat/PushBool` family mirroring `Pop*`, `Str` retained as the
  app-facing content word. Post-implementation: `.Double` case + `PushDouble` added,
  plus collision-free conveniences `Number(int/float/double)` and `Bool(bool)`.
- Beef accepts `sealed` on `Widget`, making the no-subclassing rule compiler-enforced.

## Deferred / next

Immediate next step: **roadmap planning session** (basic words/widgets, modifiers, event
handling, layout implementation, rendering, memory & runtime constraints — a minimal
framework for simple GUI apps). Separately earmarked planning: state management &
reactivity system, complex-object primitives, image/asset pipeline. Carried design notes:
widget identity (path + call index + `Key`) becomes the persistent-state key when the
first stateful feature lands; hover needs a declarative state→style path; drag is an
input protocol; the core/widgets two-package split is mechanical later thanks to
cross-project extensions; ECS-lite storage remains a possible future swap behind
`Get<T>`/`Attach`.
