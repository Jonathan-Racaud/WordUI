# M3.2 Discussion Log

## TextStyle as a pen/container — and why it was rejected

**Proposal/Context:** Apply the Interior/Border pen pattern to TextStyle: `TextStyle(scope () => { TextColor(.Red); FontSize(16); })` would create a fresh TextStyle, mutate it via pen words, then `ReplaceComponent` swap it onto the widget.

**Analysis:** The pen pattern works for Interior/Border because they have replacement semantics — "this IS the background." But TextStyle carries content (`Text`). Inside `IfHovered(scope () => { TextStyle(scope () => { TextColor(.Red); }); })`, the pen block would create a fresh TextStyle with `Text = null`, then `ReplaceComponent` would discard the original TextStyle that held the Button's label text. The button's label would disappear on hover.

**Decision:** No pen/container for TextStyle. Bare modifier words (`TextColor(.Red)`, `FontSize(16)`) use `Require<TextStyleProperty>` to mutate the existing one. This preserves the Text content during conditional mutations. The Interior/Border pen pattern remains correct for its purpose (replacement semantics for complete visual definitions).

---

## TextStyle should not hold Text content

**Proposal/Context:** Split `TextStyle` into two separate concerns: the text string (content) and the visual styling (color, font size).

**Analysis:** Conflating content and styling in one component made conditional styling unsafe (see above). Splitting them lets `TextComponent` own Measure/DrawContent and `TextStyleProperty` be a pure data bag modified by `TextColor`/`FontSize`. Conditional scopes can mutate `TextStyleProperty` without touching `TextComponent.Content`.

**Decision:** `TextStyle` split into `TextComponent : Component` (Content, Measure, DrawContent) and `TextStyleProperty : Property` (FontSize, TextColor). `TextComponent.DrawContent` reads styling from `widget.GetProperty<TextStyleProperty>()`.

---

## Should TextStyleProperty even be a Component?

**Proposal/Context:** After the split, `TextStyleProperty` has no Measure, DrawContent, or any pipeline hook. It's pure data. Should it still inherit from `Component`?

**Analysis:** Keeping it as a Component means the draw loop still iterates it (no-op virtual calls), and it pollutes the Components list. Making it a non-Component data bag avoids that, but requires a new storage mechanism.

**Decision:** This question prompted the entire three-bag architecture. Rather than a one-off for TextStyle, we introduced `Property` as a peer base class to `Component`, with its own bag on Widget. This cleanly separates pipeline participants from passive data for all existing and future types.

---

## The dual-context TextColor escape hatch — explored and rejected

**Proposal/Context:** `TextColor` could dispatch on stack context: if the stack top is a Pen(TextStyle), mutate the pen; if it's a Widget, GetOrCreate TextStyle and mutate it. One word, two behaviors.

**Analysis:** Elegant but fragile. The dispatch depends on runtime stack state, making the behavior of `TextColor(.Red)` context-dependent. Inside a TextStyle block it means one thing; at widget level it means another. This is a source of subtle bugs.

**Decision:** Rejected in favor of bare modifier words with `Require<TextStyleProperty>` always — no pen, no dual context, no dispatch. One behavior, one meaning, always. The type system and the `Require` guard provide safety.

---

## Require\<T\> vs GetOrCreate for TextStyle

**Proposal/Context:** Should `TextColor`/`FontSize` use `Require<TextStyleProperty>` (fail if absent) or `GetOrCreate` (autocreate if absent)?

**Analysis:** `GetOrCreate` is safer for conditional scopes — it never fails. But it silently autocreates dead `TextStyleProperty` on non-text widgets (e.g., `TextColor(.Red)` on a Spacer), producing no error and no visual effect. `Require<TextStyleProperty>` fails loud, catching misapplication at dev time.

**Decision:** `Require<TextStyleProperty>` (strict). The framework is young — failing loudly is more valuable than silently tolerating mistakes. Conditional scopes work fine with `Require` because the base widget definition always provides the `TextStyleProperty` via `Label`/`Button`.

---

## WidgetId for tracker identity — deferred

**Proposal/Context:** Trackers (PressTracker, HoverTracker) need a stable widget identity across rebuilds. The proposal was `WidgetId = (List<int> parentKeyChain, int childIndex)` with a precomputed `uint64 Hash`.

**Analysis:** Full path-based identity is debuggable but allocates a `List<int>` per `CurrentBuildPosition()` call. Hash-only is allocation-free but opaque. The compromise (struct with both path and hash) still heap-allocates the list on the fast path.

**Decision:** Start with `BuildIndex` (a simple `int32` monotonic counter assigned by `NewWidget`). Allocation-free, deterministic, sufficient for the prototype. Full `WidgetId` with debuggable paths can be added later when debugging interaction state actually hurts.

---

## Clickable → Behavior bag: the third category

**Proposal/Context:** `Clickable` doesn't render anything — it holds a delegate. With the Property/Component split, it fits neither bag. Should we add a third category?

**Analysis:** Behaviors are event handlers invoked by the runtime (not the draw pipeline). They're fundamentally different from both Components (pipeline participants) and Properties (passive data). A third bag gives the input system a clean iteration target.

**Decision:** `Behavior` base class with its own bag on Widget. `Clickable` becomes `OnClickBehavior : Behavior`. The word `OnClick` lives in the same file. Input dispatch (PressTracker) queries `GetBehavior<OnClickBehavior>()`.

---

## IsPressed naming — game-engine terminology vs user-facing words

**Proposal/Context:** Game engines distinguish `IsBeingPressed` (currently held) from `IsPressed` (completed click). Which should the tracker property be named?

**Analysis:** The completed-action case (`OnClick`) is already handled by the runtime callback mechanism — it's not a build-time conditional. The tracker only needs to expose "currently being held" for visual feedback conditionals. The shortest clear name is `IsPressed`.

**Decision:** Tracker property is `IsPressed`, user-facing word is `IfPressed`. If a build-time "was clicked this frame" conditional is needed later, it becomes `IfClicked` with a separate `ClickState` — no naming collision.

---

## File organization: co-locating classes with their words

**Proposal/Context:** Currently, class definitions live in `Components/` but their modifier words live in `Modifiers/` or `Handlers/`. This requires cross-file navigation to understand a single concept.

**Analysis:** Co-locating each class with its associated words makes the codebase navigable: open one file, see the class, its fields, and every word that touches it. This matters more as the framework grows.

**Decision:** Each bag directory (`Components/`, `Properties/`, `Behaviors/`) now contains files where the class definition and its words live together. `Modifiers/` shrinks to pen/styling words (`Styling.bf`), widget-field modifiers (`Layout.bf`), and identity (`Identity.bf`).
