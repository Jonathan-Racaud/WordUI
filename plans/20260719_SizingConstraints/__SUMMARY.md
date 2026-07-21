# Sizing Constraints Summary

## What we built

Widgets can now declare an explicit sizing constraint on either axis —
`Fixed`, `Min`, `Max`, `Percent`, or `Range` — via a new `SizingConstraints` enum
carried on the existing `LayoutHint` component. The flex layout pass applies the
constraint during intrinsic measurement (so it feeds main-axis sizing for free)
and, separately, treats any non-`Unconstrained` cross-axis constraint as an
override of the default `Stretch` behavior during cross-axis positioning. Two
modifier words, `Width(SizingConstraints)` and `Height(SizingConstraints)`, plus
a `FixedSize` convenience (square or width/height), expose this at the call
site. Along the way, the existing pen-scoped `Width(float)` word for border
stroke thickness was renamed to `StrokeWidth` to free up `Width` for the new
widget-level meaning. The counter demo's +/− buttons now use `FixedSize(120, 20)`
/ `FixedSize(120, 40)` to exercise it.

## Files changed

| File | Status | Purpose |
|---|---|---|
| `src/Components/LayoutHint.bf` | Modified | Added `SizingConstraints` enum (+ `Apply`, `DescribeTo`) and `Width`/`Height` fields |
| `src/Core/Layout.bf` | Modified | Apply sizing constraints in `MeasureWidget` (both branches); override cross-axis `Stretch` when a cross constraint is present |
| `src/Modifiers/Alignment.bf` | Modified | Added `Width`, `Height`, `FixedSize` (×2 overloads) modifier words |
| `src/Components/Boundary.bf` | Modified | `Width` field renamed to `StrokeWidth` |
| `src/Modifiers/Styling.bf` | Modified | `Width(float)` word renamed to `StrokeWidth(float)` |
| `src/Widgets/Button.bf` | Modified | Updated `Border` block to use `StrokeWidth(1)` |
| `src/Program.bf` | Modified | Demo: `FixedSize(120, 20)` / `FixedSize(120, 40)` on counter buttons |
| `DESIGN.md` | Modified | Vocabulary table: `Alignment` modifier list now includes `Width, Height, FixedSize` |

## Decisions

| Decision | Rationale |
|---|---|
| **`SizingConstraints` as a closed enum with `Apply`** | Keeps constraint-resolution logic next to the constraint's definition instead of branching on multiple nullable fields inside `Layout` |
| **Reused `LayoutHint`, no new component** | Sizing and cross-alignment are both child→parent layout preferences; one component avoids a second `Get<T>()` per child in the layout hot path |
| **Applied in both `MeasureWidget` and cross-axis positioning** | Measurement alone fixes the main axis (flows into `mainSizes[i]` naturally) but not the cross axis, which defaults to `Stretch` unless explicitly told otherwise |
| **`StrokeWidth` rename over type-based overload disambiguation** | Beef could technically overload `Width(float)`/`Width(SizingConstraints)`, but pen-scoped and widget-scoped words share one namespace and near-identical call sites (`Width(1)` vs `Width(.Fixed(1))`); a rename is clearer than relying on the reader to track argument types |
| **`Percent` left unguarded against unbounded main-axis parents** | Fixing it requires threading "is this constraint bounded" through every measurement call; out of scope for a first pass — documented as a known sharp edge, not silently shipped as correct |

## Roads not taken

- **Separate nullable min/max/fixed fields on `LayoutHint`.** Rejected: scales
  linearly per new constraint kind and moves "which field wins" logic into
  `Layout` instead of the constraint type itself.
- **Guarding `Percent` against `float.MaxValue` parent constraints.** Deferred,
  not rejected outright — correct fix touches the shared measurement path used
  by every widget; flagged in `_DISCUSSION.md` as future work.
- **Disambiguating `Width(float)` vs `Width(SizingConstraints)` by overload
  instead of renaming.** Rejected: technically possible but confusing at call
  sites that look nearly identical (`Width(1)` inside `Border` vs. `Width(.Fixed(1))`
  on a widget) while meaning unrelated things.

## Exit criteria met

- [x] `SizingConstraints` enum with `Fixed`/`Min`/`Max`/`Percent`/`Range`/`Unconstrained`
- [x] `Width`/`Height` modifier words + `FixedSize` convenience
- [x] Layout pass honors sizing constraints during measurement (main axis)
- [x] Layout pass honors sizing constraints during positioning (cross axis, overrides `Stretch`)
- [x] `Boundary`/`Styling` `Width` → `StrokeWidth` rename resolves the naming collision
- [x] Demo exercises `FixedSize` on the counter buttons
- [ ] `Percent` guarded against unbounded (unconstrained) parent axes — **known
      limitation, not done this pass**
