# M3 Discussion Log

## Pen/block mechanism vs. direct mutator for layout modifiers

**Context:** The existing `Background`/`Border` modifiers use a pen mechanism — `OpenContainer` + `PushPen` create a marker+pen sandwich, property words inside the block mutate the pen, `ClosePen` finds the marker and attaches the component to the widget below it. The user asked whether cross-axis alignment should follow the same pattern with a `Layout(scope () => { ... })` block.

**Analysis:** The pen mechanism exists for one reason: grouping multiple related property words (`Fill` + `Radius`, `Stroke` + `Width` + `Radius`) that all target the same component instance. For cross-axis alignment, the common case is a single word — `Center()` on its own. Requiring `Layout { Center(); }` for the 80% case is ceremony without benefit. Background/Border properties naturally come in pairs (you always need the block to create the Interior); alignment doesn't share that coupling.

Additionally, alignment properties are orthogonal — `Center()` and a hypothetical `Size(200)` describe unrelated concerns (positioning vs. sizing). There's no semantic reason they must share a block.

**Decision:** Use the direct-mutator pattern (like `Padding`, `Spacing`, `TextColor`). If later we add flex-grow, min/max size, aspect-ratio, and users routinely set three at once, a `Layout { }` block can be added as sugar. The one-liners remain valid by checking "is there a LayoutHint pen on the stack? if so mutate it; otherwise GetOrCreate on the stack-top widget."

---

## Cross-axis child alignment vs. container justification vs. other layout properties

**Context:** The user initially asked about "center elements, justify them, align them" — a mix of child-side and container-side properties. The design partner surfaced the full taxonomy: cross-axis alignment (child), main-axis self-justification (child), container justification (container), cross-axis container alignment (container), sizing constraints (child), position override (child), spacing (container), padding (widget).

**Analysis:** Cross-axis alignment (e.g., `Center()` on a Label inside a VStack makes it horizontally centered) is the smallest, most self-contained slice. It touches only the child widget and a single point in the layout pass (the cross-axis position calculation). Container justification requires modifying the parent's layout algorithm — more invasive and a different code path. Sizing constraints interact with the two-pass measure-layout algorithm and are a known sleeper task.

**Decision:** Scope to cross-axis child alignment only. Container justification (`Justify(.SpaceBetween)` on stacks) and sizing constraints are separate milestones.

---

## Widget field vs. Component for alignment

**Context:** `Padding` is a direct `float` field on `Widget`, justified as "universal layout." The user considered whether alignment should also be a Widget field, noting Widget already has padding and rect properties.

**Analysis:** The DESIGN.md says "identity + universal layout live here, every other property is a component in the bag." Padding qualifies as truly universal — every widget has padding regardless of context. Alignment is not truly universal: it only matters inside a parent layout (a root widget with no parent has nothing to align within). Putting it on Widget would bloat the core type for a property many widgets never use. A `LayoutHint` Component is consistent with the component-bag model, extensible (flex-grow, min/max size join later without touching Widget), and only widgets that use alignment pay the allocation.

**Decision:** `LayoutHint : Component` with a `CrossAlign` field. The four alignment words GetOrCreate the component on demand.

---

## GetOrCreate pattern

**Context:** The alignment words need to create a `LayoutHint` if one doesn't exist, or mutate the existing one if it does. Neither `Require<T>` (fails on absent) nor `ReplaceComponent` (replaces by type family) fits.

**Analysis:** `Widget.Attach` rejects duplicate component types, so a naive "create and attach" on every call would fail on the second alignment word. The solution: check `Get<LayoutHint>()` first; if null, `new:BuildAlloc LayoutHint()` + `Attach()`; then set the field. This is a new pattern in the codebase but a natural third option alongside `Require` and `ReplaceComponent`.

**Decision:** Each alignment word inlines the GetOrCreate logic. A shared helper was considered but would lose the word-specific error message in `Top("word")` — inlining keeps error messages precise (e.g., "PFUI error in word 'Center': stack is empty").
