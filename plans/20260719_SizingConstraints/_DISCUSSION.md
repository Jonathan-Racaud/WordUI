# Sizing Constraints Discussion Log

## Shape of the constraint type

**Proposal/Context:** Widgets need to express "I want a specific width/height,"
"at least this much," "at most this much," or "a fraction of my parent" — more
than the boolean Stretch-vs-intrinsic choice `CrossAlignment` already covers.

**Analysis:** Two shapes were possible: (a) a handful of nullable float fields on
`LayoutHint` (`FixedWidth`, `MinWidth`, `MaxWidth`, ...), or (b) a closed enum with
one active case per axis. The field approach scales linearly in fields per new
constraint kind and pushes the resolution logic (which field wins if several are
set) into `Layout`. The enum approach makes "what kind of constraint is this"
exhaustive and puts resolution (`Apply(intrinsic, parentConstraint)`) next to the
data it resolves.

**Decision:** `SizingConstraints` enum with cases `Unconstrained | Fixed(float) |
Min(float) | Max(float) | Percent(float) | Range(float, float)`, each axis
(`Width`, `Height`) holding exactly one case. `Range` subsumes "min and max both
set" without a second active field.

---

## Where the constraint applies: measurement vs. positioning

**Context:** The flex layout pass already has two places that decide a child's
final size: `MeasureWidget` (intrinsic size, bottom-up) and the cross-axis
positioning block in `LayoutWidget` (which previously only consulted
`CrossAlign` to decide whether to stretch).

**Analysis:** Applying `hint.Width/Height.Apply(...)` inside `MeasureWidget` is
enough to make main-axis constraints work automatically — `MeasureWidget`'s
return value directly becomes `mainSizes[i]`, which the main-axis placement loop
already respects. It is *not* enough for the cross axis: cross-axis placement
defaults to `Stretch` (fill available space) unless `CrossAlign != .Stretch`, so a
`Height(.Fixed(20))` child of an `HStack` would be measured correctly but then
stretched back to the row height during positioning.

**Decision:** Added a second check, `hasCrossConstraint`, in the positioning loop:
if the cross axis has a non-`Unconstrained` `SizingConstraints` (regardless of
`CrossAlign`), it now takes the same "use the measured size, position at start"
path that explicit `CrossAlign` values use. This means a sizing constraint on the
cross axis implicitly forces `Start` positioning unless `CrossAlign` is also set —
acceptable for now since the two words are meant to be combined
(`Height(.Fixed(20)); Center();` composes fine — `CrossAlign` wins over the plain
sizing-only branch since it's checked first).

---

## `Percent` against an unconstrained main axis

**Context:** `Percent(v)` resolves as `parentConstraint * v / 100`. The cross
axis always has a concrete `parentConstraint` (`inner.Width`/`inner.Height`,
bounded by the actual container). The main axis does not: `MeasureWidget`'s
child constraint on the main axis is `float.MaxValue` (deliberately unconstrained,
so intrinsic content size can grow and the flex pass distributes real leftover
space to `Spacer`s afterward).

**Analysis:** `Height(.Percent(50))` on a child of a `VStack` would therefore
resolve against `float.MaxValue`, producing a nonsensical multi-billion-pixel
size instead of an error or a sane fallback. This was noticed while wiring
`Apply` into `MeasureWidget` but not fixed — fixing it properly means threading
"is this axis actually bounded" through the constraint call, which touches the
same measurement path used by every widget and felt like scope creep for a
"first sizing constraints" pass.

**Decision:** Ship `Percent` as correct-on-the-cross-axis, documented-as-risky-on-
the-main-axis. No guard added. Flagged here explicitly so it isn't mistaken for
a resolved question later — the fix (probably: only accept `Percent` where
`parentConstraint < float.MaxValue`, falling back to intrinsic otherwise) is
future work, not a known-good corner.

---

## The `Width` naming collision with border stroke width

**Context:** `Modifiers/Styling.bf` already had a pen-scoped `Width(float)` word
that set `Boundary.Width` (border stroke thickness), used inside `Border(scope
() => { Stroke(...); Width(1); Radius(4); })` — including in the `Button` widget
word itself.

**Analysis:** The new sizing-constraint word is also naturally named `Width`
(`Width(SizingConstraints)`), and both live as `static` methods on the `UI`
extension — Beef would need to disambiguate purely by argument type
(`float` vs `SizingConstraints`), which works at call sites with a literal but
gets confusing to read (`Width(1)` inside a `Border` block vs. `Width(.Fixed(1))`
at the widget level look almost the same but mean unrelated things).

**Decision:** Renamed the border-scoped word/field to `StrokeWidth`
(`Boundary.Width` → `Boundary.StrokeWidth`, `Styling.Width` → `Styling.StrokeWidth`),
freeing `Width` to mean "this widget's width constraint" everywhere. Updated the
one caller (`Button`'s `Border(scope () => { ...StrokeWidth(1)... })`) and
`DESIGN.md`'s vocabulary table.
