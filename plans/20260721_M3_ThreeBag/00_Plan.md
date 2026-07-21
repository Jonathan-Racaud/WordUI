# M3.2 — Three-Bag Architecture & IfActive\<T\>

**Goal:** Split the single `Component` bag into three type-safe bags (`Component`, `Property`, `Behavior`) with distinct pipeline roles, add the `IfActive<T>` conditional mechanism for interaction-state-driven rebuilds, and migrate all existing types to the new model with co-located files. Exit: build passes, all 4 negative tests pass, CounterSDLApp tree dump shows all three bags correctly, `IfPressed` drives visual feedback on Button "+".

## Plan

1. **Add Property and Behavior base classes, update Widget to three-bag API**
   - Create `src/Core/Property.bf` — `public abstract class Property` with `virtual void Describe(String buf) {}`
   - Create `src/Core/Behavior.bf` — `public abstract class Behavior` with `virtual void Describe(String buf) {}`
   - Update `src/Core/Widget.bf`:
     - Add `List<Property> mProperties` and `List<Behavior> mBehaviors` fields
     - Rename `Get<T>` → `GetComponent<T>`, `Require<T>` → `RequireComponent<T>`, `Attach` → `AttachComponent`
     - Add `GetProperty<T>`, `RequireProperty<T>`, `AttachProperty` for Property bag
     - Add `GetBehavior<T>`, `RequireBehavior<T>`, `AttachBehavior` for Behavior bag
     - Keep `ReplaceComponent` on Component bag only (pens are Components)
     - Add `BuildIndex int32` field (stable per-build identity for trackers)
   - Update `src/Core/UI.bf`:
     - Add `sBuildIndex` counter, `CurrentBuildPosition()` returning stack-top widget's `BuildIndex`
     - Rename `Attach(Component)` → `AttachComponent(Component)`
     - Add `AttachProperty(Property)`, `AttachBehavior(Behavior)` wrappers
     - Update `NewWidget` to create all three bags and assign `BuildIndex`
   - Update all ~20 call sites: `Attach(...)` → `AttachComponent(...)`, `w.Get<T>()` → `w.GetComponent<T>()`, `w.Require<T>(...)` → `w.RequireComponent<T>(...)`
   - Update pipeline files: `SDLApp.bf` (draw loop iterates Components only), `Layout.bf` (queries Children/StackLayout as Components, LayoutHint as Component for now), `TreeDump.bf` (iterates all three bags), `PressTracker.bf` (queries Behaviors)

2. **Add IfActive\<T\> mechanism with PressState end-to-end**
   - Create `src/Properties/PressState.bf`:
     - `IInteractionState` interface: `bool IsActive { get; }`
     - `PressState : Property, IInteractionState` — `IsActive => PressTracker.IsPressed(UI.CurrentBuildPosition())`
     - `IfActive<T>(delegate void() body) where T : Property, IInteractionState` — GetOrCreate + query pattern
     - `IfPressed(delegate void() body)` convenience alias
   - Update `src/Core/PressTracker.bf`:
     - Change storage from `Widget?` to `Dictionary<int32, bool>` keyed by `BuildIndex`
     - Add `IsPressed(int32 buildIndex)` query, `SetPressed` updates + `App.Instance.Invalidate()`
     - `HandleEvent` dispatches via `GetBehavior<OnClickBehavior>()`
   - Update `src/Core/App.bf` — add `public static App Instance` for tracker-initiated invalidation
   - Demo in `src/Program.bf` — `Button("+")` gets `IfPressed(scope () => { Background(...); })`

3. **Refactor existing types to three-bag model + co-locate files**
   - Split `TextStyle` → `TextComponent : Component` (content, Measure, DrawContent) + `TextStyleProperty : Property` (FontSize, TextColor)
   - Rename `Clickable` → `OnClickBehavior : Behavior`; move `OnClick` word into same file
   - Move `LayoutHint` from Component to Property bag; co-locate alignment words (`Center`, `AlignStart`, etc.)
   - Update widget factories: `Label.bf`, `Button.bf` attach both `TextComponent` + `TextStyleProperty`; `Stack.bf` uses renamed APIs
   - Delete superseded files: `Components/TextStyle.bf`, `Components/Clickable.bf`, `Components/LayoutHint.bf`, `Handlers/OnClick.bf`, `Modifiers/Text.bf`, `Modifiers/Alignment.bf`

## Decisions made in plan phase

- **Three bags, not a unified bag.** The old single `Component` list forced no-op virtual dispatches for data-only types (TextStyle, LayoutHint). Splitting into Component (pipeline), Property (data), Behavior (handlers) gives each subsystem exactly what it needs and eliminates wasted draw-loop iterations.
- **Property is a peer to Component, not a subclass.** If Property inherited from Component, the draw loop would still iterate it. A separate base class keeps the draw loop clean.
- **IfActive\<T\> constrained to Property, not Component.** Interaction states (`PressState`, `HoverState`, `FocusState`) are pure data — no Measure, no Draw. Constraining to `Property` keeps the taxonomy honest.
- **TextStyle uses Require\<T\>, not GetOrCreate.** The strict posture (fail loud on missing TextStyle) catches misapplication at dev time rather than silently creating dead components.
- **No pen/container block for TextStyle.** Unlike Interior/Border (replacement semantics), TextStyle wants merging semantics. Bare modifier words with `Require<TextStyleProperty>` preserve the Text content during conditional mutations.
- **Files co-locate class definitions with their words.** Each `Properties/*.bf`, `Components/*.bf`, `Behaviors/*.bf` contains both the class and its associated words/sugar, making the codebase navigable without cross-file hunting.
