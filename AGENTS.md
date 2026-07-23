# Repository Guidelines

## Project Overview

WordUI is an experimental **concatenative UI framework** for the [Beef](https://www.beeflang.org/) language. It captures the essence of Factor's UI vocabulary — a sequence of **words** operating on an implicit widget stack — inside an applicative language without building an interpreter. The project is in early development: it renders a real SDL3 GUI (flex layout, text, mouse input) with a draw-time interaction pipeline (press/hover highlights, `Transition` animation, `OnDrag`) over a persistent, rebuild-surviving retained `Node` tree. A console tree dump remains available as a diagnostic.

---

## Project Structure

```
BeefProj.toml              # Beef project config (name, startup object)
BeefSpace.toml             # Workspace config
DESIGN.md                  # Architecture, locked decisions, and rationale
README.md                  # Quick-start, build instructions, status
plans/                     # Per-session planning docs and brainstorming notes
src/
├── Core/                  # Foundation: Widget (sealed, 3 bags), App, UI (stack + ops), Component/Property/Behavior base classes, Color, Children, StackItem, Primitives, Rect, Size, Layout, Painter, HitTest, InputEvent, SDLApp
│                          #   + interaction pipeline: KeyAssign (StableKey), Node (retained tree), StateSlot (typed per-node state accessors), StateSlots (framework-reserved slots), Interaction (IfActive/Transition), StyleResolve, Easing, ITracker, HoverTracker, DragTracker, PressTracker, ScrollTracker
│                          #   + forward-looking: ITickable (design artifact for Phase 5 tick dispatch)
├── Components/            # Pipeline participants (Component bag): TextComponent, Interior, Boundary, StackLayout, Children
├── Properties/            # Pure data (Property bag) + their setter words: TextStyleProperty/TextColor/FontSize, LayoutHint/Center/Align/Width/Height, PressState/HoverState (IInteractionState), StatePatch/InteractionStyle
├── Behaviors/             # Event handlers (Behavior bag): OnClickBehavior/OnClick, OnDragBehavior/OnDrag
├── Widgets/               # Word definitions: Label, Button, Stack (HStack/VStack), Spacer
├── Modifiers/             # Modifier words: Layout (Padding/Spacing), Identity (Key), Styling (Background/Border pens)
├── Diagnostics/           # Diagnostics words: StackDump, TreeDump
└── Program.bf             # Entry point, demo apps, and negative test harnesses
docs/                      # Canonical documentation (MDX — source of truth)
├── concepts/              # Architecture: concatenative model, widget model, modifiers, rebuild
├── api/                   # API reference: every word with stack effect and examples
├── guides/                # Authoring guides: factoring words, components, primitives, state
├── design/                # Locked decisions with rationale
├── index.mdx              # Project overview
├── getting-started.mdx    # Build, run, first app walkthrough
└── roadmap.mdx            # Milestone status
doc-website/               # Astro Starlight documentation site (reads from docs/ via symlink)
```

**Key files:** `DESIGN.md` is the source of truth for architectural decisions — read it before proposing API changes. Canonical documentation lives in [`docs/`](docs/); the doc website is in [`doc-website/`](doc-website/).

---

## Build, Test, and Development Commands

```sh
build                             # Build from workspace root (Debug Linux64)
./build/Debug_Linux64/WordUI/WordUI   # Run the counter demo (console tree dump)
```

Diagnostics flags (run via the built binary):

| Flag | Purpose |
|---|---|
| `--test-mismatch` | Verify mismatched container close produces a named error |
| `--test-unbalanced` | Verify missing close word trips stack-hygiene check |
| `--test-unclosed-pen` | Verify a pen block left open (missing `Interior_`/`Border_`) is reported |
| `--test-leftover` | Verify unconsumed stack values are reported by name |

---

## Coding Style & Naming Conventions

- **Language:** Beef (`.bf` files), with `using static` to expose word-based APIs.
- **Naming:** PascalCase for types, methods, namespaces, and public fields. Member fields use `m` prefix (`mCount`, `mRoot`, `mComponents`).
- **Brace style:** Allman — opening brace on its own line.
- **Conciseness:** Prefer single-expression blocks and expression-bodied members where clear.
- **Modifiers:** Always attach a modifier to the stack top it acts on (`Button("+"); OnClick(f);`, never `OnClick(f); Button();`). See Rule B in `DESIGN.md`.
- **No formatter/linter** is configured yet — maintain consistency by following the patterns in existing files.

---

## Testing Guidelines

The project has **no formal test framework or CI**. Testing is done via:

- **Negative-test CLI flags** in `Program.bf` (`--test-mismatch`, `--test-unbalanced`, `--test-unclosed-pen`, `--test-leftover`).
- **Manual validation** through `RebuildIfNeeded()` + `DumpTree()` in demo apps.
- **Stack diagnostics** (`PrintStack`) for runtime introspection during development.

When adding new features, add a corresponding negative test app class in `Program.bf` and register it under a new `--test-*` flag.

---

## Commit & Pull Request Guidelines

Check the project's Git history for established conventions:

```sh
git log --oneline -20
```

General expectations:

- Use descriptive, imperative commit messages (e.g., "Add Spacer word", "Fix container close marker mismatch").
- Keep commits focused on a single logical change.
- Pull requests should include a description of what changed, why, and any links to related plans or issues in `plans/`.
- Run all `--test-*` flags before opening a PR to confirm no regressions.

---

## Documentation & References

- [`docs/`](docs/) — **canonical documentation** (MDX). Source of truth for all user-facing docs: concepts, API reference, guides, design decisions, roadmap.
- [`doc-website/`](doc-website/) — Astro Starlight site that reads `docs/` as its content directory. `bun run dev` from `doc-website/` starts the dev server.
- [`DESIGN.md`](DESIGN.md) — architecture, locked decisions, and rationale. **Required reading** for anyone adding API surface. Points to `docs/` for expanded treatment.
- [`plans/`](plans/) — session plans, explored paths, and rejected alternatives.
- [`README.md`](README.md) — short landing page with links into `docs/`.

### Documentation maintenance rules

- **When adding a new public word** (widget, modifier, handler, pen): add its entry in the corresponding `docs/api/*.mdx` file with stack effect, parameter types, description, and a code example.
- **When changing a locked decision**: update both [`DESIGN.md`](DESIGN.md) and [`docs/design/decisions.mdx`](docs/design/decisions.mdx).
- **When completing a milestone**: update [`docs/roadmap.mdx`](docs/roadmap.mdx).
- **When adding a new concept or pattern**: add it to the appropriate `docs/concepts/*.mdx` or `docs/guides/*.mdx`.
- **Doc files are MDX** — they render as plain Markdown on GitHub and as styled pages in Starlight. Keep MDX-specific syntax minimal; use frontmatter for metadata only.

---

## Agent-Specific Instructions

- Build the project with the command `build` (uses the project's devenv build script).
- Agent skills and configurations live in `.claude/skills/`.
- **Milestone planning workflow:** When working on a new milestone from the roadmap, create a folder `plans/YYYYMMDD_<MilestoneName>/` containing:
  - `00_Plan.md` — the agreed implementation plan
  - `_DISCUSSION.md` — raw ongoing discussion log (decisions, tradeoffs, questions)
  - `__SUMMARY.md` — final summary of decisions made, paths taken, and alternatives rejected with reasoning (does not need to repeat the full discussion; the discussion file is the detailed record)
- Before modifying API surface or adding words, consult `DESIGN.md` — especially **Rule B** (modifiers act on stack top), the **hybrid data passing** convention, and the **delegate block** pattern for containers.
- Respect the principle: new widgets are created by factoring words, never by subclassing `Widget`.
- When adding new components, validate that no duplicate component types are attached (enforced by `Widget.Attach`).
