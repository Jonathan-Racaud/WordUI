# Repository Guidelines

## Project Overview

PFUI is an experimental **concatenative UI framework** for the [Beef](https://www.beeflang.org/) language. It captures the essence of Factor's UI vocabulary — a sequence of **words** operating on an implicit widget stack — inside an applicative language without building an interpreter. The project is in early development; the current prototype stops at tree construction and uses a console dump as the stand-in renderer.

---

## Project Structure

```
BeefProj.toml              # Beef project config (name, startup object)
BeefSpace.toml             # Workspace config
DESIGN.md                  # Architecture, locked decisions, and rationale
README.md                  # Quick-start, build instructions, status
plans/                     # Per-session planning docs and brainstorming notes
src/
├── Core/                  # Foundation types: Widget, App, UI (stack + ops), Component, Color, Children, StackItem, Primitives
├── Components/            # Capability types: Clickable, StackLayout, TextStyle
├── Widgets/               # Word definitions: Label, Button, Stack (HStack/VStack), Spacer
├── Modifiers/             # Modifier words: Layout (Padding/Spacing), Text (TextColor/FontSize), Identity (Key)
├── Handlers/              # Event words: OnClick
├── Diagnostics/           # Diagnostics words: StackDump, TreeDump, Simulate
└── Program.bf             # Entry point, demo apps, and negative test harnesses
```

**Key files:** `DESIGN.md` is the source of truth for architectural decisions — read it before proposing API changes.

---

## Build, Test, and Development Commands

```sh
BeefBuild                          # Build from workspace root (Debug Linux64)
./build/Debug_Linux64/PFUI/PFUI   # Run the counter demo (console tree dump)
```

Diagnostics flags (run via the built binary):

| Flag | Purpose |
|---|---|
| `--test-mismatch` | Verify mismatched container close produces a named error |
| `--test-unbalanced` | Verify missing close word trips stack-hygiene check |
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

- **Negative-test CLI flags** in `Program.bf` (`--test-mismatch`, `--test-unbalanced`, `--test-leftover`).
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

- [`DESIGN.md`](DESIGN.md) — architecture, locked decisions, and rationale. **Required reading** for anyone adding API surface.
- [`plans/`](plans/) — session plans, explored paths, and rejected alternatives.
- [`README.md`](README.md) — quick-start, status, and build prerequisites.

---

## Agent-Specific Instructions

- **Do not run `BeefBuild` from the command line.** The SDL3 managed dependency has a cache-state issue with the CLI build tool. The user handles all builds from the Beef IDE. Do not attempt `BeefBuild` or any other build command until the user explicitly lifts this restriction.
- Agent skills and configurations live in `.claude/skills/`.
- **Milestone planning workflow:** When working on a new milestone from the roadmap, create a folder `plans/YYYYMMDD_<MilestoneName>/` containing:
  - `00_Plan.md` — the agreed implementation plan
  - `_DISCUSSION.md` — raw ongoing discussion log (decisions, tradeoffs, questions)
  - `__SUMMARY.md` — final summary of decisions made, paths taken, and alternatives rejected with reasoning (does not need to repeat the full discussion; the discussion file is the detailed record)
- Before modifying API surface or adding words, consult `DESIGN.md` — especially **Rule B** (modifiers act on stack top), the **hybrid data passing** convention, and the **delegate block** pattern for containers.
- Respect the principle: new widgets are created by factoring words, never by subclassing `Widget`.
- When adding new components, validate that no duplicate component types are attached (enforced by `Widget.Attach`).
