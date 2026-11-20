# WordUI

An experimental UI framework for [Beef](https://www.beeflang.org/) that captures the
essence of **concatenative programming** — inspired by [Factor](https://factorcode.org/)'s
UI vocabulary — inside an applicative language, without building an interpreter.

UI is a sequence of **words** operating on an implicit widget stack:

```beef
using static WordUI.UI;

VStack(scope () => {
    Label("Title"); FontSize(24);
    HStack(scope () => {
        Button("+"); OnClick(increment);
        Spacer();
        Button("-"); OnClick(decrement);
    }); Spacing(4);
}); Padding(8);
```

## Documentation

Canonical documentation lives in [`docs/`](docs/):

| | |
|---|---|
| [Getting Started](docs/getting-started.mdx) | Build, run, your first app |
| [Concepts](docs/concepts/concatenative-model.mdx) | Words, stack, widget model, rebuild |
| [API Reference](docs/api/) | Every word with stack effects |
| [Guides](docs/guides/) | Authoring custom widgets and components |
| [Design Decisions](docs/design/decisions.mdx) | Locked architecture and rationale |
| [Roadmap](docs/roadmap.mdx) | Milestone status |

- [`DESIGN.md`](DESIGN.md) — architecture source of truth (points to `docs/` for expanded treatment)
- [`plans/`](plans/) — per-session planning and brainstorming

## Build & run

```sh
build
./build/Debug_Linux64/WordUI/WordUI
```

Status: early experiment — word vocabulary, modifiers, styling, alignment + sizing constraints, SDL3 and Raylib rendering backends, hit-test, click dispatch, press/hover interaction states with animated transitions, drag with pointer capture, scrollable containers, focus management, and keyboard input all working. The Raylib backend embeds into a host-owned window and frame loop. A retained `Node` tree provides rebuild-surviving generic state storage (`StateSlot<T>` accessors over `Dictionary<int, Variant>` per-node) with slot pruning and tick-based animation clocks. Text input (TextField widget) is upcoming.
