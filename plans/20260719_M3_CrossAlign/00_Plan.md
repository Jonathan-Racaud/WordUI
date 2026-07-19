# M3 — Cross-Axis Alignment

**Goal:** Add child-side cross-axis alignment modifiers (`Center`, `AlignStart`, `AlignEnd`, `AlignStretch`) that let widgets position themselves within the space their parent allocates on the perpendicular axis. Exit: alignment words compile, layout pass respects them, demo shows centered and start-aligned elements in the running SDL window, all existing negative tests pass.

## Plan

1. **LayoutHint Component** — new `src/Components/LayoutHint.bf`
   - `CrossAlignment` enum: `Stretch` (default), `Start`, `Center`, `End`
   - `LayoutHint : Component` class carrying `CrossAlign` field
   - `Describe` only appends when `CrossAlign != .Stretch`

2. **Alignment modifier words** — new `src/Modifiers/Alignment.bf`
   - Four words: `Center()`, `AlignStart()`, `AlignEnd()`, `AlignStretch()`
   - Each uses the direct-mutator pattern (no pen/block mechanism)
   - GetOrCreate pattern: `Get<LayoutHint>()`; if null, `new:BuildAlloc` + `Attach`
   - Each calls `Top("word")` for clear error messages on empty stack or non-widget top

3. **Layout pass wiring** — modify `src/Core/Layout.bf`
   - Track `crossSizes[]` alongside `mainSizes[]` during child measurement
   - In the positioning loop: read `child.Get<LayoutHint>()`
   - When `CrossAlign != Stretch`: use child's intrinsic cross-size, position at start/center/end
   - When absent or `Stretch`: use full cross-axis available (preserves existing behavior)

4. **Demo** — modify `src/Program.bf`
   - `Center()` on the counter title
   - `AlignStart()` on the count label and list items

## Decisions made in plan phase

- **No pen/block mechanism.** The four words are single-value setters; the common case is one word alone. A `Layout { }` block grouping is overkill now but can be added later as sugar without breaking these one-liners.
- **LayoutHint is a Component, not a Widget field.** Consistent with the component-bag model. Only widgets that use alignment pay the allocation. Extensible — flex-grow, min/max size, aspect ratio can join later without touching Widget.
- **GetOrCreate pattern (new to the codebase).** Neither `Require<T>` (fails on absent) nor `ReplaceComponent` (replaces by type family). The right fit for optional components with sensible defaults: the first alignment word on a widget creates the LayoutHint; subsequent ones just overwrite the field.
- **Default is Stretch (existing behavior).** Widgets without a LayoutHint continue to fill the full cross-axis — zero behavioral change for all existing code.
- **Cross-axis only; no container justification.** `Justify(.SpaceBetween)` on containers is a different code path (container layout algorithm) and left for a follow-up milestone.
