# WordUI — Design Notes

> **Canonical documentation is in [`docs/`](docs/).** This file remains the root-level source
> of truth for architecture decisions but is no longer the sole reference. See
> [`docs/concepts/`](docs/concepts/) for expanded explanations and
> [`docs/design/decisions.mdx`](docs/design/decisions.mdx) for locked decisions with rationale.

WordUI is an experiment: capture the *essence* of concatenative programming — Factor's UI
vocabulary in particular — inside Beef, an applicative language, without building an
interpreter. UI is a sequence of **words** operating on an implicit widget stack.
Rendering uses SDL3 directly; the current prototype renders the counter demo with real
mouse hit-test → click → rebuild → repaint.

## The shape

```beef
using static WordUI.UI;

VStack(scope () => {
    Label("Title"); FontSize(24);
    HStack(scope () => {
        Button("+"); {
            TextColor(.White);
            IfPressed(scope () => {
                Background(scope () => { Fill(.(120, 120, 120, 255)); Radius(4); });
            });
            OnClick(handler);
        }
        Spacer();
        Button("-"); OnClick(handler2);
    }); Spacing(4);
}); Padding(8);
```

### Locked decisions

1. **Modifiers act on the stack top (Rule B).** Always `Button("+"); OnClick(f);`, never
   `OnClick(f); Button();`. Because a closed container is left on the stack top, modifiers
   compose onto whole containers for free: `...); Padding(8);`.
2. **Hybrid data passing.** The stack form is primitive (`Str("x"); Label();`) and
   convenience overloads are sugar (`Label("x")` ≡ `Str("x"); Label();`). Modifier
   parameters are always applicative (`TextColor(.Red)`).
3. **Delegate blocks are the user-facing container form**, implemented on top of the
   public paired primitives (`_VStack()`/`VStack_()`), which remain available for
   cross-function factoring. (The mixin-block alternative is empirically impossible:
   Beef evaluates mixin arguments eagerly, before the body.)
4. **Rebuild-on-invalidate** (Flutter's model minus diffing). `Build()` re-runs only after
   `Invalidate()`; each run produces a fresh tree in a `System.BumpAllocator` arena; the
   old tree is freed wholesale. State is plain Beef fields; reactivity is `Invalidate()`.
5. **One widget class + three type-safe bags** (see Architecture below). `Widget` is
   `sealed` — never subclassed. Capabilities split across three bags: `Component`
   (pipeline participants — `Measure`, `Draw*`), `Property` (pure data), and `Behavior`
   (event handlers). The single inheritance points are `Component`, `Property`, and
   `Behavior`, each one level deep.
6. **Direct SDL3 now; renderer/platform abstraction deferred.** The framework uses SDL3
   directly (via `BeefLibs/SDL2`: `SDL_Renderer` + `SDL2_ttf`) while the concatenative model
   is being validated — the thesis under test lives on the framework side, where the
   backend's identity is irrelevant, and a one-implementation abstraction is best *extracted*
   from working code later than *designed* blind now. The only discipline kept from the
   abandoned seam is **localization** (not abstraction): SDL drawing flows through one
   concrete `Painter` module, and `SDL_Event` is adapted to a WordUI `InputEvent` at a single
   boundary, so the eventual abstraction is a mechanical extract-interface refactor rather
   than a rewrite. A build-your-own renderer (GL/software) is a far-future alternate backend.

## Architecture

### The widget model: sealed class + three bags

`Widget` (Core/Widget.bf) is the only widget class and is `sealed` — the no-subclassing
rule is compiler-enforced. It carries identity (`Name`, `Key`), the one universal layout
property (`Padding`), a `BuildIndex` for stable per-build identity, and three separate
type-safe bags:

| Bag | Base class | What goes in it | Framework passes |
|---|---|---|---|
| **Component** | `Component` (abstract) | Pipeline participants | `Measure`, `DrawBackground`, `DrawContent`, `DrawOverlay` |
| **Property** | `Property` (abstract) | Pure data | `Describe` only — queried by other code |
| **Behavior** | `Behavior` (abstract) | Event handlers | `Describe` only — iterated by input dispatch |

Why three? A single `Component` bag forced no-op virtual dispatches for data-only types.
`TextStyleProperty` has no `Measure` or `Draw` — it's pure data the `TextComponent` reads.
`OnClickBehavior` has no pipeline hooks — it's a delegate the input system invokes. Three
bags let each subsystem iterate exactly what it needs: the draw loop iterates Components
only; layout queries both Components and Properties; input dispatch iterates Behaviors.

Each bag has its own typed accessors:
- `GetComponent<T>()` / `RequireComponent<T>(word)` / `AttachComponent(c)` / `ReplaceComponent(c)`
- `GetProperty<T>()` / `RequireProperty<T>(word)` / `AttachProperty(p)`
- `GetBehavior<T>()` / `RequireBehavior<T>(word)` / `AttachBehavior(b)`

`Require*<T>` is the modifier workhorse — it produces a named error when a modifier is
applied to a widget that doesn't carry the expected type. `ReplaceComponent` (Component
bag only) handles the pen-block pattern: `Background { ... }` replaces any existing
`Interior` instead of triggering a duplicate error.

**Why not widget subclasses, when Factor subclasses its gadgets?** Factor's gadgets are
*retained, long-lived, stateful actors* — objects that own state and respond to events,
which is what classes with behavior are for, and subclassing is Factor's dispatch
mechanism (generic words dispatch on class). WordUI chose rebuild-on-invalidate, so its
widgets are *transient descriptions*: data records consumed by framework passes. Behavior
polymorphism still needs a home — it moves one level down, to the bag base classes:

- **Inheritance for pipeline behavior**: `Component` subclasses override framework hooks
  (`Measure`/`Draw*`). One level deep.
- **Inheritance for data**: `Property` subclasses carry typed data (`TextStyleProperty`,
  `LayoutHint`, `PressState`). Queried by pipeline participants and modifier words.
- **Inheritance for events**: `Behavior` subclasses carry delegates (`OnClickBehavior`).
  Iterated by input dispatch.
- **Composition for capability mixing**: widgets are three bags. A clickable styled label
  is `TextComponent + TextStyleProperty + Interior + Boundary + OnClickBehavior`; no
  `ClickableLabel` class can ever exist. Subclass trees handle capability combinations
  combinatorially; bags handle them trivially.

Framework components, properties, and behaviors are **peers** with user-authored ones:
every pass dispatches through the same virtual hooks, so a user's type shows up in the
tree dump (and later in layout and rendering) with no registration step.

### The word model: everything is an extension of a small core

`Core/UI.bf` holds the stack and the **core-op API** — the only functions words build on,
public on purpose (it is the documented extender surface):

- Stack: `Push`, `PopStr/PopInt/PopFloat/PopDouble/PopBool/PopWidget(word)`, `PopPen(word)`,
  `Top(word)`, `TopPen(word)`.
- Construction: `NewWidget(name)` (pushes *and* returns), `AttachComponent`/`AttachProperty`/
  `AttachBehavior`, `ReplaceComponent`, `OpenContainer(name)` / `CloseContainer(name)`.
- Pens: `PushPen(pen)` / `ClosePen(name)`.
- Infrastructure: `RegisterHandler`, `BuildAlloc` (the build arena), `Fail(word, msg)`,
  `CurrentBuildPosition()`.

Every word — framework or user — is an `extension UI` block. Beef extensions add static
methods, access private members, and work **across projects**, so an app can define its
own words, components, and modifiers without touching the framework. `using static
WordUI.UI;` exposes them all identically.

### Stack-based construction (the word-author API)

Widget words are written in the framework's own word language:

```beef
public static void Label()
{
    let text = PopStr("Label");   // 1. pop inputs FIRST
    NewWidget("Label");           // 2. then push the widget
    AttachComponent(new:BuildAlloc TextComponent() { Content = text });
    AttachProperty(new:BuildAlloc TextStyleProperty() { FontSize = 12, TextColor = .Black });
}
```

**The pop-inputs-first rule matters**: `NewWidget` pushes on top of any pending inputs, so
popping after it finds the widget, not the input. This is Factor's own discipline
(consume inputs before pushing outputs) surfacing in Beef.

Because the widget is on the stack during construction, **widget words can reuse modifier
words as defaults** — `NewWidget("Button"); …; FontSize(14); TextColor(.White);` — and
default sets factor into ordinary words. Containers use the same idiom: the closing word
pushes its container, attaches its layout component, then `CloseContainer(name)` pops it,
collects children down to the name-matched marker, fills a `Children` component, and
re-pushes. Stack effect: `( mark child1 … childN container -- container )`.

`NewWidget` returning the widget is the applicative escape hatch: authors who prefer
`let w = NewWidget("X"); w.AttachComponent(…)` may, with the same function.

### Three tiers of "custom widget" (user side)

1. **Factored word** (the 90% case, zero classes): `static void IconButton(...)` composing
   existing words. This is Factor-style factoring and the framework's core payoff.
2. **New capability**: a `Component`, `Property`, or `Behavior` subclass + a modifier word
   that get-or-creates it on the stack-top widget — works on *any* widget, in the user's
   own project. The pattern is the same for all three bags.
3. **New drawable primitive** (rare): a `Component` subclass overriding the behavior
   hooks (`Describe` now, `Measure`/`Draw*` later) + a word that news the widget and
   attaches it.

### Interaction states (M3)

The `IfActive<T>` mechanism powers conditional build during interaction — the first
implementation is `IfPressed`:

```beef
Button("+"); {
    TextColor(.White);
    IfPressed(scope () => {
        Background(scope () => { Fill(.(120, 120, 120, 255)); Radius(4); });
    });
    OnClick(new => { mCount++; Invalidate(); });
}
```

`IfActive<T>` where `T : Property, IInteractionState` get-or-creates a `Property` on the
stack-top widget, then runs the body only when `T.IsActive` is true. `PressState`
implements `IInteractionState` by querying `App.Instance.FindNode(ownerKey)?.GetBool(PressTracker.SlotPress)`. The
pattern is rebuild-safe: on the first build the `PressState` property is created; on
subsequent rebuilds `GetProperty<T>` finds it and reuses it. The `IsActive` query returns
false when the widget isn't being pressed, so the highlight body doesn't run — the widget
renders its default appearance. When the user presses, `IsActive` is true, the body runs
and replaces the `Interior` with a brighter fill.

### Primitives

Data words: the `PushStr/PushInt/PushFloat/PushDouble/PushBool` family, mirroring the
`Pop*` core ops, plus collision-free friendly aliases: `Str(s)` (arena-copies; the
established content word), `Number(int)`/`Number(float)`/`Number(double)`, and
`Bool(b)`. Bare `Int(…)` and `Float(…)` words are **impossible in Beef**: `Int` and
`Float` are corlib struct names and type constructors win resolution over using-static
methods. Complex objects (structs, lists, dictionaries) are deferred to their own
planning phase, as is image/asset support (the earlier `Image` widget was removed).

### Diagnostics (the stand-in for Factor's stack-effect checker)

Type-tagged stack items; every pop validates its tag and reports the failing word plus a
stack dump (`PrintStack()` = Factor's `.s`); containers use **named markers** (mismatched
close = immediate named error); the stack must be empty after every build; each bag's
`Attach*` rejects duplicate types; `Require*<T>` names both the word and the widget.
The tree dump iterates all three bags so every attached type — Component, Property, or
Behavior — appears without the framework knowing it exists.

### Memory & ownership

Everything a build allocates — widgets, components, properties, behaviors, bags, string
copies — goes through `new:BuildAlloc` and dies wholesale when the arena is deleted on
rebuild. Handlers passed to `OnClick` are framework-owned, stored per build, freed on the
next rebuild; events only ever dispatch against the current tree, so a handler cannot
outlive what it references.

## State management & reactivity

**Now:** state = plain Beef fields; UI = f(state); reactivity = `Invalidate()`. No
diffing, no observers. `IfActive<T>` handles interaction-state-driven conditional build
without triggering extra rebuilds — the body runs or doesn't run during the normal build
cycle, and tracker state is read from the retained `Node` tree at draw.

**Growth path, only when measurably needed:** memoized subtrees (needs widget identity);
Factor-style `Model<T>` observables + `Bind` (retained-mode vocabulary; only if
whole-tree rebuild proves too slow).

**Widget identity is the known hard problem.** Scroll offset, caret, focus, and animation
progress cannot live in rebuilt widgets. The solution is the retained `Node` tree
(`src/Core/Node.bf`): a heap-allocated tree that survives rebuilds, carrying identity
(`StableKey`), parent/child links, generic per-node state storage (`Dictionary<int, Variant>`),
and per-state animation clocks. After each build, `ReconcileTree()` matches the new Widget
tree against the existing Node tree by `StableKey`; matched Nodes are reused (state persists),
new ones are created, and orphans are disposed. This is the side table grown into a tree.

**Per-node state slots and pruning.** Each `Node` carries `Dictionary<int, Variant> mState`
for generic capability-owned state (hover, press, scroll, user-defined). Slots are typed via
`StateSlot<T>` accessors; the framework reserves slots 1–99 (`StateSlots.FrameworkIds`) for
built-in trackers, and user capabilities pick ≥100. After each reconciliation, stale slots
are pruned: any slot key not referenced by the current widget's `IInteractionState` properties
(or the framework-reserved set) is removed, preventing unbounded growth.

**Time-based state (Phase 5 direction).** Currently `Node` carries hardcoded animation clocks
(`Clock` struct, `mClocks`, `Blend()`/`Tick()`/`NeedsTick`). Phase 5 will replace this with a
generic `ITickable` interface (`src/Core/ITickable.bf` — design artifact): capabilities
implement `ITickable`, store their own per-frame data in `mState`, and `Node.Tick(dtMs)`
iterates registered tickables. This lets users author custom time-based behaviours (blinking
cursor, physics, inertial scroll, custom animation curves) as capabilities without framework
modification. The `Easing` enum will become an interface or delegate so users can supply
custom interpolation curves.

## Deferred

Roadmap set in `plans/20260718_Roadmap/00_roadmap.md`. Milestone spine (each ends in a
runnable demo): **M0** SDL window opens · **M1** static tree lays out (flex:
constraints-down/sizes-up, sum-main/max-cross, leftover→`Spacer`) and paints via a concrete
SDL `Painter` module · **M2** real pointer input → hit-test → dispatch (the minimal GUI-app
goal; `SimulateClick` retired) · **M3** hover/press states + the repaint-vs-rebuild split ·
**M4** first persistent state (scroll) forcing the widget-ID side table + clipping · **M5**
text input + focus + keyboard. Text/fonts is the twice-appearing sleeper (measure gates
layout, raster gates render), largely covered by SDL2_ttf. Earmarked beyond: memoization
and `Model<T>` (only if profiled slow), animations, drag protocol, image/asset pipeline,
complex-object primitives, accessibility, the deferred **renderer/platform abstraction +
alternate backend** (extracted from the concrete SDL `Painter` once the model is proven),
core/widgets split (mechanical later, thanks to cross-project extensions).

## Prototype map

| Path | Contents |
|---|---|
| `src/Core/` | `Color`, `Component` (base), `Property` (base), `Behavior` (base), `Widget` (the one class, 3 bags), `Children`, `StackItem`, `UI` (stack + core ops), `App` (rebuild driver + retained Node tree), `Node` (retained runtime elements), `SDLApp`, `Painter`, `Layout`, `HitTest`, `KeyAssign`, `Interaction` (IfActive/Transition), `StyleResolve`, `Easing`, `HoverTracker`, `PressTracker`, `DragTracker`, `ScrollTracker`, `InputEvent`, `Rect`, `Size`, `Primitives` |
| `src/Components/` | `TextComponent`, `Interior` (fill), `Boundary` (stroke), `StackLayout` (+ `Axis`) |
| `src/Properties/` | `TextStyleProperty`, `LayoutHint` (+ `CrossAlignment`, `SizingConstraints`), `PressState`, `HoverState` (+ `IInteractionState`), `StatePatch`, `InteractionStyle` |
| `src/Behaviors/` | `OnClickBehavior` (+ `ClickHandler`), `OnDragBehavior` (+ `DragHandler`) |
| `src/Widgets/` | words only: `Label`, `Button`, `Stack` (HStack/VStack trios), `Spacer` |
| `src/Modifiers/` | `Layout` (Padding, Spacing), `Styling` (Background/Border pens + Fill/Stroke/Radius/StrokeWidth), `Text` (TextColor, FontSize), `Identity` (Key), `Alignment` (Center, AlignStart, AlignEnd, AlignStretch, Width, Height, FixedSize) |
| `src/Handlers/` | `OnClick` (get-or-create OnClickBehavior) |
| `src/Diagnostics/` | `StackDump` (PrintStack), `TreeDump` |
| `src/Program.bf` | counter + list demo with IfPressed; `--test-mismatch` / `--test-unbalanced` / `--test-unclosed-pen` / `--test-leftover` |
| `docs/` | Canonical documentation: concepts, API reference, guides, design decisions, roadmap |
| `doc-website/` | Astro Starlight documentation website (reads from `docs/`) |
