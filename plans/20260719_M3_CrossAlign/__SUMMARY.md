# M3 Summary

## What we built

Cross-axis child alignment modifiers let widgets declare how they position themselves on the perpendicular axis within the space their parent allocates. A new `LayoutHint` Component carries the `CrossAlign` preference; four one-liner words (`Center`, `AlignStart`, `AlignEnd`, `AlignStretch`) attach it on demand via a GetOrCreate pattern. The flex layout pass reads `LayoutHint` during child positioning: when alignment is anything other than the default `Stretch`, the child is sized to its intrinsic cross-axis measurement and positioned at the start, center, or end of the available space. Existing widgets without alignment modifiers continue to stretch full-width/full-height — zero behavioral change.

## Files changed

| File | Status | Purpose |
|---|---|---|
| `src/Components/LayoutHint.bf` | New | `CrossAlignment` enum + `LayoutHint : Component` carrying `CrossAlign` |
| `src/Modifiers/Alignment.bf` | New | `Center()`, `AlignStart()`, `AlignEnd()`, `AlignStretch()` — direct mutators with GetOrCreate |
| `src/Core/Layout.bf` | Modified | Track `crossSizes[]` per child; apply `LayoutHint.CrossAlign` during cross-axis positioning |
| `src/Program.bf` | Modified | Demo: `Center()` on title, `AlignStart()` on count label and list items |

## Decisions

| Decision | Rationale |
|---|---|
| **Direct mutator pattern, not pen/block** | Cross-axis alignment is typically a single word. A `Layout { }` block is overkill; can be added as sugar later without breaking one-liners |
| **LayoutHint : Component, not Widget field** | Consistent with component-bag model. Alignment isn't truly universal (meaningless on root widgets). Extensible for flex-grow, min/max size later |
| **GetOrCreate pattern** | First alignment word creates the LayoutHint; subsequent ones overwrite the field. Neither `Require<T>` nor `ReplaceComponent` fit this use case |
| **Default = Stretch** | Preserves existing behavior for all code that doesn't use alignment words. `hint == null` falls through to full cross-axis fill |
| **Inlined GetOrCreate per word** | Keeps `Top("word")` error messages precise ("error in word 'Center': stack is empty") vs. a shared helper with a generic name |
| **Cross-axis only, no container justification** | Container-side `Justify(.SpaceBetween)` modifies the parent's layout algorithm — a different code path, left for a separate milestone |

## Roads not taken

- **Pen/block mechanism (`Layout(scope () => { Center(); })`).** Rejected: the common case is one word; the pen exists for multi-property grouping (`Fill`+`Radius`) which doesn't apply here. Can be added later as sugar.
- **Alignment as Widget fields (like Padding).** Rejected: alignment isn't truly universal (root widgets have no parent to align within). Component approach avoids bloating Widget and is extensible.
- **Shared GetOrCreate helper.** Rejected: loses word-specific error context in `Top()`. The four words are short enough that inlining is acceptable.
- **Container justification in same milestone.** Rejected: different code path (container layout algorithm vs. child positioning). Keeps the milestone focused and self-contained.

## Exit criteria met

- [x] Alignment words compile and run (`Center`, `AlignStart`, `AlignEnd`, `AlignStretch`)
- [x] Layout pass reads `LayoutHint` and positions children on the cross axis accordingly
- [x] Widgets without alignment continue to stretch (default behavior preserved)
- [x] Demo shows centered title and start-aligned items in the SDL window
- [x] All existing negative tests pass (`--test-mismatch`, `--test-unbalanced`, `--test-unclosed-pen`, `--test-leftover`)
