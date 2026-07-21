# M3.2 Summary

## What we built

The single `Component` bag was split into three type-safe bags — `Component` (pipeline participants with Measure/Draw* hooks), `Property` (pure data queried by other code), and `Behavior` (event handlers invoked by the runtime). Each bag has its own `Get*/Require*/Attach*` API on Widget with duplicate-type guards. The `IfActive<T>` generic conditional mechanism was added, driven by `PressTracker` over a `Dictionary<int32, bool>` keyed by per-widget `BuildIndex`, with `IfPressed` as the first convenience alias driving visual press feedback on buttons. All 7 existing types were migrated: `TextStyle` split into `TextComponent` + `TextStyleProperty`, `Clickable` became `OnClickBehavior`, `LayoutHint` moved to Property. Files were reorganized so each class lives with its words.

## Files changed

| File | Status | Purpose |
|---|---|---|
| `src/Core/Property.bf` | New | `Property` abstract base class (Describe only, no pipeline hooks) |
| `src/Core/Behavior.bf` | New | `Behavior` abstract base class (Describe only, no pipeline hooks) |
| `src/Core/Widget.bf` | Modified | Three bags (Components/Properties/Behaviors) with `GetComponent<T>`/`GetProperty<T>`/`GetBehavior<T>` + `Require*`/`Attach*` per bag, `ReplaceComponent` on Component bag, `BuildIndex` field |
| `src/Core/UI.bf` | Modified | `sBuildIndex` counter, `CurrentBuildPosition()`, `AttachComponent`/`AttachProperty`/`AttachBehavior` wrappers, updated `NewWidget` |
| `src/Core/App.bf` | Modified | Added `static App Instance` for tracker-initiated invalidation |
| `src/Core/PressTracker.bf` | Modified | `Dictionary<int32, bool>` keyed by `BuildIndex`, `IsPressed()` query, dispatches via `GetBehavior<OnClickBehavior>()` |
| `src/Core/SDLApp.bf` | Modified | `App.Instance = this`, draw loop unchanged (iterates Components only) |
| `src/Core/Layout.bf` | Modified | `GetComponent<Children/StackLayout>` + `GetProperty<LayoutHint>` (3 call sites) |
| `src/Core/HitTest.bf` | Modified | `GetComponent<Children>()` |
| `src/Diagnostics/TreeDump.bf` | Modified | Iterates all three bags (Components, Properties, Behaviors) |
| `src/Properties/PressState.bf` | New | `IInteractionState` interface, `PressState : Property, IInteractionState`, `IfActive<T>`, `IfPressed` |
| `src/Properties/TextStyle.bf` | New | `TextStyleProperty : Property` + `TextColor`/`FontSize` words |
| `src/Properties/LayoutHint.bf` | New | `LayoutHint : Property` + all alignment/sizing words (was `Components/LayoutHint.bf` + `Modifiers/Alignment.bf`) |
| `src/Behaviors/OnClick.bf` | New | `OnClickBehavior : Behavior` + `ClickHandler` delegate + `OnClick` word (was `Components/Clickable.bf` + `Handlers/OnClick.bf`) |
| `src/Components/Text.bf` | New | `TextComponent : Component` with Content, Measure, DrawContent (split from `TextStyle`) |
| `src/Widgets/Label.bf` | Modified | Attaches `TextComponent` + `TextStyleProperty` |
| `src/Widgets/Button.bf` | Modified | Attaches `TextComponent` + `TextStyleProperty`, button comment updated |
| `src/Widgets/Stack.bf` | Modified | `AttachComponent(StackLayout)` |
| `src/Modifiers/Layout.bf` | Modified | `RequireComponent<StackLayout>` |
| `src/Program.bf` | Modified | `IfPressed` demo on Button "+" |
| `src/Components/TextStyle.bf` | Deleted | Split into `TextComponent` + `TextStyleProperty` |
| `src/Components/Clickable.bf` | Deleted | Renamed to `OnClickBehavior` in `Behaviors/` |
| `src/Components/LayoutHint.bf` | Deleted | Moved to `Properties/LayoutHint.bf` |
| `src/Handlers/OnClick.bf` | Deleted | Merged into `Behaviors/OnClick.bf` |
| `src/Modifiers/Text.bf` | Deleted | Merged into `Properties/TextStyle.bf` |
| `src/Modifiers/Alignment.bf` | Deleted | Merged into `Properties/LayoutHint.bf` |

## Decisions

| Decision | Rationale |
|---|---|
| **Three bags, not one** | Eliminates no-op virtual dispatches for data-only types; each subsystem iterates exactly what it needs |
| **Property is a peer to Component (not a subclass)** | If Property inherited Component, the draw loop would still iterate it |
| **`IfActive<T>` constrained `where T : Property`** | Interaction states are pure data — no pipeline hooks needed |
| **`TextStyleProperty` uses `Require<T>` (strict)** | Fails loud on misapplication; conditional scopes are safe because Label/Button always provide the property |
| **No pen/container for TextStyle** | Pen pattern = replacement semantics; TextStyle wants merging to preserve Text content during conditional mutations |
| **`TextStyle` split into `TextComponent` + `TextStyleProperty`** | Content and styling are different concerns; splitting makes conditional styling safe |
| **`Clickable` → `OnClickBehavior`** | Event handlers are a third category (neither pipeline nor passive data) |
| **`BuildIndex` for tracker identity (not full WidgetId)** | Allocation-free monotonic counter; sufficient for prototype; debuggable paths deferred |
| **Files co-locate classes with their words** | Navigable: open one file, see the class, its fields, and every word that touches it |

## Roads not taken

- **TextStyle as a pen/container block (`TextStyle(scope => { ... })`).** Rejected because `ReplaceComponent` would discard the Text content during conditional mutations.
- **Dual-context `TextColor` (pen-or-widget dispatch).** Rejected because context-dependent behavior is fragile. One behavior, one meaning.
- **`GetOrCreate` for TextStyleProperty (silent autocreate).** Rejected in favor of `Require<T>` — failing loudly is more valuable in a young framework.
- **Full `WidgetId = (List<int> path, int childIndex, uint64 hash)` for tracker keys.** Deferred; `BuildIndex` is allocation-free and sufficient now.
- **`IfActive<T>` constrained to `Component`.** Rejected because interaction states have no Measure/Draw hooks; `Property` is the correct bag.

## Exit criteria met

- [x] Build passes
- [x] All 4 negative tests pass with correct error messages
- [x] CounterSDLApp tree dump shows all three bags correctly (Components: Text/Interior/Boundary; Properties: TextStyleProperty/LayoutHint/PressState; Behaviors: OnClickBehavior)
- [x] `IfPressed` drives visual feedback on Button "+" (tree dump shows "pressed")
- [x] All 7 existing types migrated to correct bags
- [x] Files co-located: each class lives with its words
