# Sizing Constraints

**Goal:** widgets can declare an explicit width/height constraint (fixed, min, max,
percent, or range) that the layout pass honors during measurement and cross-axis
positioning, so a widget no longer has to accept whatever size the flex algorithm
would otherwise give it. Exit: `FixedSize(120, 20)` on a widget inside a stack
produces exactly that box, overriding both intrinsic measurement and cross-axis
Stretch.

## Plan

1. **`SizingConstraints` enum** — a closed set of constraint kinds, not separate
   min/max/fixed fields on `LayoutHint`.
   - Cases: `Unconstrained`, `Fixed(float)`, `Min(float)`, `Max(float)`,
     `Percent(float)`, `Range(float, float)`
   - `Apply(intrinsic, parentConstraint)` resolves a case against a measured
     intrinsic size and the incoming parent constraint
   - `DescribeTo` for tree-dump diagnostics

2. **Extend `LayoutHint`** — add `Width`/`Height : SizingConstraints` fields
   (default `Unconstrained`) alongside the existing `CrossAlign`, since both are
   "how a child wants to be sized/placed" data carried the same way.

3. **Wire into `Layout.MeasureWidget`** — after computing intrinsic `w`/`h` for
   both the container and leaf branches, run `hint.Width.Apply(w, constraint.Width)`
   / `hint.Height.Apply(h, constraint.Height)` before returning.

4. **Wire into cross-axis positioning** — a sizing constraint on the cross axis
   must override the default `Stretch` behavior (previously only `CrossAlign`
   could do that), otherwise `Height(.Fixed(20))` on a child of an `HStack` would
   still be stretched to the row's full height.

5. **Modifier words** — `Width(SizingConstraints)`, `Height(SizingConstraints)`
   as direct-mutator words via the existing `GetOrCreateLayoutHint` helper, plus
   `FixedSize(wh)` / `FixedSize(w, h)` as convenience sugar over `Width`+`Height`.

6. **Resolve the `Width` name collision** — `Modifiers/Styling.bf` already
   defines a pen-scoped `Width(float)` word for `Boundary.Width` (border stroke
   thickness). Introducing a top-level `Width(SizingConstraints)` word collides.
   Rename the border-scoped word and field to `StrokeWidth` throughout
   (`Boundary.Width` → `Boundary.StrokeWidth`, `Styling.Width` → `Styling.StrokeWidth`,
   and the `Button` word that used it).

7. **Demo** — apply `FixedSize(120, 20)` / `FixedSize(120, 40)` to the counter
   demo's +/− buttons so the constraint is visibly exercised in the running app.

## Decisions made in plan phase

- **Enum over fields**: a `SizingConstraints` enum with an `Apply` method keeps
  "how to resolve a constraint" colocated with the constraint's definition,
  rather than spreading `if hint.HasFixedWidth`-style branching through `Layout`.
- **Reuse `LayoutHint`, don't add a new component**: sizing and cross-alignment
  are both "child → parent layout preference" data; one component avoids doubling
  the `Get<T>()` lookups per child in the hot layout path.
- **`StrokeWidth` rename over an overload**: Beef could in principle disambiguate
  `Width(float)` vs `Width(SizingConstraints)` by signature, but pen-scoped words
  (`Border(scope () => { ...Width(1)... })`) and widget-scoped words share the same
  `UI` namespace and the same call-site shape, so keeping them textually distinct
  is worth the one-time rename.
