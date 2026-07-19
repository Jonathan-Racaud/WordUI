# PFUI — Design Notes

PFUI is an experiment: capture the *essence* of concatenative programming — Factor's UI
vocabulary in particular — inside Beef, an applicative language, without building an
interpreter. UI is a sequence of **words** operating on an implicit widget stack.
Rendering will be fully custom (Flutter-style, no native widgets); the current prototype
stops at tree construction and uses a console dump as the stand-in renderer.

## The shape

```beef
using static PFUI.UI;

VStack(scope () => {
    Label("Title"); FontSize(24);
    HStack(scope () => {
        Button("+"); OnClick(handler);
        Spacer();
        Button("-"); OnClick(handler2);
    }); Spacing(4);      // modifies the HStack
}); Padding(8);          // modifies the VStack
```

### Locked decisions

1. **Modifiers act on the stack top (Rule B).** Always `Button("+"); OnClick(f);`, never
   `Handler(f); Button();`. Because a closed container is left on the stack top, modifiers
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
5. **One widget class + component composition** (see Architecture below). Widgets are
   never subclassed; capabilities are component objects; the single inheritance point is
   the `Component` base class, one level deep.
6. **Direct SDL2 now; renderer/platform abstraction deferred.** The framework uses SDL2
   directly (via `BeefLibs/SDL2`: `SDL_Renderer` + `SDL2_ttf`) while the concatenative model
   is being validated — the thesis under test lives on the framework side, where the
   backend's identity is irrelevant, and a one-implementation abstraction is best *extracted*
   from working code later than *designed* blind now. The only discipline kept from the
   abandoned seam is **localization** (not abstraction): SDL2 drawing flows through one
   concrete `Painter` module, and `SDL_Event` is adapted to a PFUI `InputEvent` at a single
   boundary, so the eventual abstraction is a mechanical extract-interface refactor rather
   than a rewrite. A build-your-own renderer (GL/software) is a far-future alternate backend.

## Architecture

### The widget model: sealed class + component bag

`Widget` (Core/Widget.bf) is the only widget class and is `sealed` — the no-subclassing
rule is compiler-enforced. It carries
identity (`Name`, `Key`), the one universal layout property (`Padding`), and a bag of
`Component` objects. Everything else — text styling, clickability, stack axis, children —
is a component:

- `Get<T>()` — capability query, null if absent.
- `Require<T>(word)` — capability query that fails with a named error
  ("HStack has no TextStyle — FontSize does not apply to it").
- `Attach(c)` — rejects duplicate component types (a second TextStyle on one widget is
  almost always a construction word firing at the wrong stack top).

**Why not widget subclasses, when Factor subclasses its gadgets?** Factor's gadgets are
*retained, long-lived, stateful actors* — objects that own state and respond to events,
which is what classes with behavior are for, and subclassing is Factor's dispatch
mechanism (generic words dispatch on class). PFUI chose rebuild-on-invalidate, so its
widgets are *transient descriptions*: data records consumed by framework passes. Behavior
polymorphism still needs a home — it moves one level down, to `Component`:

- **Inheritance for behavior polymorphism**: component classes override framework hooks
  (`Describe` today; `Measure`/`Draw` when layout/rendering land). One level deep.
- **Composition for capability mixing**: widgets are bags. A clickable image is
  `Image + Clickable`; no `ClickableImage` class can ever exist. Subclass trees handle
  capability combinations combinatorially; bags handle them trivially.

Framework components and user components are **peers**: every pass dispatches through the
same virtual hooks, so a user's component shows up in the tree dump (and later in layout
and rendering) with no registration step.

### The word model: everything is an extension of a small core

`Core/UI.bf` holds the stack and the **core-op API** — the only functions words build on,
public on purpose (it is the documented extender surface):

- Stack: `Push`, `PopStr/PopInt/PopFloat/PopDouble/PopBool/PopWidget(word)`, `Top(word)`.
- Construction: `NewWidget(name)` (pushes *and* returns), `Attach(component)`,
  `OpenContainer(name)` / `CloseContainer(name)`.
- Infrastructure: `RegisterHandler`, `BuildAlloc` (the build arena), `Fail(word, msg)`.

Every word — framework or user — is an `extension UI` block. Beef extensions add static
methods, access private members, and work **across projects**, so an app can define its
own words, components, and modifiers without touching the framework. `using static
PFUI.UI;` exposes them all identically.

### Stack-based construction (the word-author API)

Widget words are written in the framework's own word language:

```beef
public static void Label()
{
    let text = PopStr("Label");   // 1. pop inputs FIRST
    NewWidget("Label");           // 2. then push the widget
    Attach(new:BuildAlloc TextStyle() { Text = text });   // 3. then attach/modify
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
`let w = NewWidget("X"); w.Attach(…)` may, with the same function.

### Three tiers of "custom widget" (user side)

1. **Factored word** (the 90% case, zero classes): `static void IconButton(...)` composing
   existing words. This is Factor-style factoring and the framework's core payoff.
2. **New capability**: a `Component` subclass + a modifier word that attaches it on
   demand (see Handlers/OnClick.bf for the pattern) — works on *any* widget, in the
   user's own project.
3. **New drawable primitive** (rare): a `Component` subclass overriding the behavior
   hooks (`Describe` now, `Measure`/`Draw` later) + a word that news the widget and
   attaches it.

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
close = immediate named error); the stack must be empty after every build; `Attach`
rejects duplicate component types; `Require<T>` names both the word and the widget.

### Memory & ownership

Everything a build allocates — widgets, components, bags, string copies — goes through
`new:BuildAlloc` and dies wholesale when the arena is deleted on rebuild. Handlers passed
to `OnClick` are framework-owned, stored per build, freed on the next rebuild; events only
ever dispatch against the current tree, so a handler cannot outlive what it references.

## State management & reactivity

**Now:** state = plain Beef fields; UI = f(state); reactivity = `Invalidate()`. No
diffing, no observers.

**Growth path, only when measurably needed:** memoized subtrees (needs widget identity);
Factor-style `Model<T>` observables + `Bind` (retained-mode vocabulary; only if
whole-tree rebuild proves too slow).

**Widget identity is the known hard problem.** Scroll offset, caret, focus, and animation
progress cannot live in rebuilt widgets. Standard fix: stable ID (parent path + call
order + optional `Key`) into a persistent side table. The `Key` word exists today so the
slot is designed in; the side table comes with the first stateful widget.

## Deferred

Roadmap set in `plans/20260718_Roadmap/00_roadmap.md`. Milestone spine (each ends in a
runnable demo): **M0** SDL2 window opens · **M1** static tree lays out (flex:
constraints-down/sizes-up, sum-main/max-cross, leftover→`Spacer`) and paints via a concrete
SDL2 `Painter` module · **M2** real pointer input → hit-test → dispatch (the minimal GUI-app
goal; `SimulateClick` retired) · **M3** hover/press states + the repaint-vs-rebuild split ·
**M4** first persistent state (scroll) forcing the widget-ID side table + clipping · **M5**
text input + focus + keyboard. Text/fonts is the twice-appearing sleeper (measure gates
layout, raster gates render), largely covered by SDL2_ttf. Earmarked beyond: memoization
and `Model<T>` (only if profiled slow), animations, drag protocol, image/asset pipeline,
complex-object primitives, accessibility, the deferred **renderer/platform abstraction +
alternate backend** (extracted from the concrete SDL2 `Painter` once the model is proven),
core/widgets split (mechanical later, thanks to cross-project extensions).

## Prototype map

| Path | Contents |
|---|---|
| `src/Core/` | `Color`, `Component` (base), `Widget` (the one class), `Children`, `StackItem`, `UI` (stack + core ops), `App` (rebuild driver), `Primitives` |
| `src/Components/` | `TextStyle`, `Clickable` (+ `ClickHandler`), `StackLayout` (+ `Axis`), `LayoutHint` (+ `CrossAlignment`) |
| `src/Widgets/` | words only: `Label`, `Button`, `Stack` (HStack/VStack trios), `Spacer` |
| `src/Modifiers/` | `Layout` (Padding, Spacing), `Text` (TextColor, FontSize), `Identity` (Key), `Alignment` (Center, AlignStart, AlignEnd, AlignStretch, Width, Height, FixedSize) |
| `src/Handlers/` | `OnClick` (attach-on-demand Clickable) |
| `src/Diagnostics/` | `StackDump` (PrintStack), `TreeDump`, `Simulate` (SimulateClick) |
| `src/Program.bf` | counter + list demo; `--test-mismatch` / `--test-unbalanced` / `--test-leftover` |
