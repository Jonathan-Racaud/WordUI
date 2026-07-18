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
   parameters are always applicative (`TextColor(.Red)`). This kills the need for
   `dup`/`swap`/`rot` — the part of concatenative style that does not translate pleasantly.
3. **Delegate blocks are the user-facing container form**, implemented on top of the
   public paired primitives:
   ```beef
   public static void VStack(delegate void() body) { _VStack(); body(); VStack_(); }
   ```
   The primitives (`_VStack()`/`VStack_()`) stay public for purist code and for factored
   words that open in one function and close in another. Beef lambdas capture by value;
   mutating a local from inside a body needs `scope [&] () => { ... }` (fields via `this`
   work as-is).
4. **Rebuild-on-invalidate** (Flutter's model minus diffing). `Build()` re-runs only after
   `Invalidate()`; each run produces a fresh tree in a bump arena (`System.BumpAllocator`);
   the old tree is freed wholesale by deleting the arena. Layout/draw will run per frame
   from the retained current tree.

### Rejected alternatives (and why)

- **Cascade operator** (`app.._VStack()`): ties words to an instance; reads as method
  chaining, not word sequences.
- **Defer-mixin containers** (`{ VStack!(); ... }` with an injected `defer` closing at
  block end): the close word is invisible at `}`, so a modifier after the brace is
  unreadable — you must know the brace secretly ran `HStack_()`.
- **Mixin with block argument** (`VStack!({ ... })`): *empirically impossible.* Beef
  evaluates mixin arguments once, eagerly, before the mixin body — a scratch test printed
  the body before the open marker, nested containers inverted their open order, and
  `defer:mixin` closes fired bunched at end of `Main`. A mixin argument reference is also
  only usable as an expression, never a bare statement.
- **Encoding stack effects in generic types**: Beef has no HList/variadic-generic
  ergonomics; it would destroy the flat word aesthetic. Runtime checking instead (below).

## What survives the translation, what doesn't

**Survives — and is the payoff:**
- *Point-free factoring.* Any contiguous run of words extracts into a
  zero-parameter-plumbing function and drops back in anywhere:
  `static void TitleLabel(StringView s) { Label(s); FontSize(24); }`
- *Uniform extensibility.* With `using static`, user words are indistinguishable from
  framework words at the call site.
- *Implicit dataflow.* Widgets flow through the stack; no builder objects, no variables.
- *Control flow for free.* Native `for`/`if` around word sequences replaces Factor's
  `each`/`map`/`if*` combinators — the hybrid beats Factor for approachability here.

**Doesn't survive (accepted):**
- *Static stack-effect checking.* Compensated at runtime: type-tagged stack items, every
  pop validates its tag and reports the failing word plus a stack dump (`PrintStack()` is
  Factor's `.s`), containers use **named markers** so a mismatched close is an immediate
  error, and the stack must be empty after every build (the "stack hygiene" assert — the
  poor-man's stack-effect checker).
- *Quotations / higher-order words.* Delegates substitute where needed.
- *Interactive listener development.* Out of scope.

## Key corrections to the original concept

- **A global thread-safe stack is a mis-port of Factor.** Factor's data stack is per
  execution context. Locking individual push/pops cannot stop two interleaved word
  sequences from corrupting the tree — safety must be whole-build-grained. The stack is
  `[ThreadStatic]`; the prototype is single-UI-thread; parallel per-window builds remain
  possible later.
- **The stack is a construction workspace, not a store.** No state lives on it between
  builds; `EndBuild` enforces emptiness.
- **Strings are copied into the arena at push time.** `Label(scope $"Count: {n}")` is safe
  because `Str` copies; callers never transfer ownership.
- **Handler lifetime.** Delegates passed to `OnClick` are owned by the framework, stored
  per build, and freed on the next rebuild. Events always dispatch against the current
  tree, so a handler can never outlive the widgets it references.

## State management & reactivity

**Now:** state = plain Beef fields; UI = f(state); reactivity = `Invalidate()`. Handlers
mutate fields, call `Invalidate()`; the driver re-runs `Build()` before the next frame.
No diffing, no observers, no dirty-tracking below whole-window granularity.

**Growth path, only when measurably needed:**
1. Memoized subtrees (`Memo(key)`) reusing the previous build's subtree — requires widget
   identity.
2. Factor-style `Model<T>` observables with a `Bind` modifier word — the retained-mode
   vocabulary; port only if whole-tree rebuild proves too slow.

**Widget identity is the known hard problem.** Scroll offset, caret, and focus cannot live
in widgets that are rebuilt. The standard fix is a stable ID (call order + optional
`Key(id)` for list items) into a persistent side table. The `Key` word exists today so the
ID slot is designed in from the start; the side table comes with the first stateful widget.

## Deferred

Real renderer (custom drawing), layout pass (constraints-down/sizes-up: sum on main axis,
max on cross axis, leftover to `Spacer`s), widget-ID side table, memoization, models,
text input, focus/hit-testing, animations, accessibility.

## Prototype map

| File | Contents |
|---|---|
| `src/Widget.bf` | `Widget`, `WidgetKind`, `Color`, `StackItem` tagged union, `ClickHandler` |
| `src/UI.bf` | the word vocabulary, thread-local stack, marker validation, diagnostics |
| `src/App.bf` | rebuild-on-invalidate driver, arena + handler ownership, tree dump, click simulation |
| `src/Program.bf` | counter + list demo; `--test-mismatch` / `--test-unbalanced` negative tests |
