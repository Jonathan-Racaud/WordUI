# PFUI

An experimental UI framework for [Beef](https://www.beeflang.org/) that captures the
essence of **concatenative programming** — inspired by [Factor](https://factorcode.org/)'s
UI vocabulary — inside an applicative language, without building an interpreter.

UI is a sequence of **words** operating on an implicit widget stack. Modifiers act on the
stack top; any run of words factors into a new word with zero parameter plumbing:

```beef
using static PFUI.UI;

VStack(scope () => {
    Label("Title"); FontSize(24);
    HStack(scope () => {
        Button("+"); OnClick(increment);
        Spacer();
        Button("-"); OnClick(decrement);
    }); Spacing(4);      // modifies the HStack
}); Padding(8);          // modifies the VStack
```

Widgets are a single sealed class composed of **components** (capabilities); new widgets
are created by factoring words, not by subclassing. State management is
rebuild-on-invalidate: plain fields + `Invalidate()`, with each build allocated in a bump
arena. Rendering will be fully custom (Flutter-style, no native widgets); the current
prototype stops at tree construction and uses a console dump as the stand-in renderer.

## Status

Early experiment. Working today: the word vocabulary (Label, Button, HStack/VStack,
Spacer + modifiers and OnClick), runtime stack diagnostics, and the
build → invalidate → rebuild cycle. Layout, rendering, input, and animations are future
phases.

## Build & run

Requires the Beef toolchain (`BeefBuild`).

```sh
BeefBuild                          # build (from the workspace root)
./build/Debug_Linux64/PFUI/PFUI    # run the counter demo (console tree dump)
```

Diagnostics demos: `--test-mismatch` (mismatched container close), `--test-unbalanced`
(missing close word), `--test-leftover` (unconsumed stack values).

## Documentation

- [`DESIGN.md`](DESIGN.md) — architecture, locked decisions, and rationale. Read this
  before proposing API changes.
- [`plans/`](plans/) — per-session plans and brainstorming summaries, including the
  paths explored and rejected.
