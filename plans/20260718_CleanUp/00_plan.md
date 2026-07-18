# PFUI — Production-Oriented Reorganization Plan (approved & implemented)

## Context

The first prototype validated the concatenative API (delegate-block containers, Rule B
modifiers, hybrid data passing, rebuild-on-invalidate). This reorganization makes the
code modular (one file per widget/modifier/handler/component) and replaces widget
inheritance with the **sealed-Widget + component-bag** design plus the **stack-based
construction API**, both approved after the brainstorming documented in `__SUMMARY.md`.
No tests — explicit user preference while experimenting. Roadmap planning follows as a
separate session.

## Design

1. **One widget class, ever.** `Widget` (sealed) = `Name` (StringView), `Key`, `Padding`,
   component bag (`List<Component>`), `Get<T>`, `Require<T>(word)` (capability query with
   named error), `Attach` (rejects duplicate component types with a named error). No
   subclasses — widgets are transient descriptions, consistent with rebuild-on-invalidate;
   behavior polymorphism lives one level down.
2. **`Component` is the single inheritance point**: abstract base with virtual
   `Describe(String)` now; `Measure`/`Draw` hooks arrive with their phases. Framework
   components (TextStyle, Clickable, StackLayout, Children) and user components are peers
   on the same hooks — a user component participates in diagnostics (and later layout and
   rendering) with no registration step.
3. **Stack-based construction API** (canonical form for word authors): `NewWidget(name)`
   pushes *and returns* the widget (the return value is the applicative escape hatch);
   `Attach(component)` acts on the stack top; `CloseContainer(name)` pops the container
   off the top, collects children down to the name-matched marker beneath it, fills a
   `Children` component, re-pushes. Stack effect: `( mark c1 … cN container -- container )`.
   Documented discipline: **pop inputs before pushing the widget.** Widget words can reuse
   modifier words as defaults — the framework is written in its own word language.
4. **Primitives**: `Str` plus the `PushStr/PushInt/PushFloat/PushBool` family mirroring the
   `Pop*` core ops. Image removed entirely (deferred to asset planning). StackItem union:
   `.Str .Int .Float .Bool .Elem(Widget) .Mark(StringView)`.
5. **Markers by name** (StringView literals); `WidgetKind`/`KindName` deleted — new
   container types never touch core or a shared enum.

## File layout (replaced the previous five flat files in `src/`)

```
src/
  Core/
    Color.bf         Color struct (+ [Commutable] operator==)
    Component.bf     abstract Component (virtual Describe; future Measure/Draw)
    Widget.bf        the one sealed Widget class (bag, Get/Require/Attach)
    Children.bf      Children : Component (the one component core knows about)
    StackItem.bf     tagged union + ToString
    UI.bf            thread-local stack, BeginBuild/EndBuild, core-op API:
                     Push, PopStr/PopInt/PopFloat/PopBool/PopWidget, Top,
                     NewWidget, Attach, OpenContainer/CloseContainer(name),
                     RegisterHandler, BuildAlloc (build arena), Fail
    App.bf           rebuild-on-invalidate driver, arena + handler ownership
    Primitives.bf    extension UI: Str + Push* data words
  Components/
    TextStyle.bf     TextStyle : Component (Text, FontSize, TextColor) + Describe
    Clickable.bf     ClickHandler delegate + Clickable : Component + Describe
    StackLayout.bf   Axis enum + StackLayout : Component (Axis, Spacing) + Describe
  Widgets/           words only — zero classes
    Label.bf         Label(), Label(s)
    Button.bf        Button(), Button(s)
    Stack.bf         _HStack/HStack_/HStack(body) + VStack trio
    Spacer.bf        Spacer()
  Modifiers/
    Layout.bf        Padding (base field), Spacing (Require<StackLayout>)
    Text.bf          TextColor, FontSize (Require<TextStyle>)
    Identity.bf      Key
  Handlers/
    OnClick.bf       OnClick (get-or-attach Clickable, RegisterHandler)
  Diagnostics/
    StackDump.bf     extension UI: PrintStack
    TreeDump.bf      extension App: DumpTree (Name + base props + each component's
                     Describe, recurse via Children)
    Simulate.bf      extension App: SimulateClick (generic: Clickable + TextStyle match)
  Program.bf         demo + --test-mismatch / --test-unbalanced / --test-leftover
```

## Deviations discovered during implementation

- **Bare `Int(…)`/`Float(…)` words are impossible in Beef**: `Int` and `Float` are corlib
  struct names, and type constructors win resolution over `using static` methods (compile
  error proved it; `Str` and `Bool` are collision-free). Resolution: the `Push*` family
  mirroring `Pop*`, with `Str` kept as the established app-facing content word.
- Beef supports `sealed` on the Widget class.

## Post-implementation adjustments (current repo state)

- `StackItem` gained a `.Double(double)` case with `PushDouble`/`PopDouble`.
- Convenience overloads added in Primitives: `Number(int)`, `Number(float)`,
  `Number(double)`, and `Bool(bool)` (collision-free friendly names over the Push* family).

## Verification (all passed)

- `BeefBuild` clean; `./build/Debug_Linux64/PFUI/PFUI` output structurally equivalent to
  the pre-refactor run (tree nesting, modifier values, Count 0→1 click cycle,
  `rebuilt: False` when state unchanged).
- `--test-mismatch`: "mismatched containers: closing HStack found an open _VStack()
  marker" + stack dump. `--test-unbalanced`: stack-hygiene failure at EndBuild.
  `--test-leftover`: "unconsumed Int(42) …" with Float/Bool visible in the dump.
- Grep: no `WidgetKind`, `KindName`, `Image`, or widget-subclass references remain.
- `DESIGN.md` updated: architecture, component model, construction API +
  pop-inputs-first rule, the Factor comparison (retained actors vs transient
  descriptions), updated file map and deferred list.
