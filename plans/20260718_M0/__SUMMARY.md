# M0 Summary

## What we built

`PFUI.SDLApp` — an abstract subclass of `PFUI.App` that manages an SDL3 window + renderer lifecycle. A minimal `M0App` demo opens a colored window you can close.

## Files changed

- **`src/Core/SDLApp.bf`** (new) — the bridge class. ~80 lines of direct SDL3 calls.
- **`src/Program.bf`** (modified) — default run path now launches `M0App`; existing `--test-*` flags preserved.
- **`AGENTS.md`** (modified) — added milestone planning workflow + build restriction.
- **`plans/20260718_M0/`** (new) — this planning record.

## Decisions

| Decision | Rationale |
|---|---|
| **Direct SDL3 calls, no scaffold inheritance** | The SDL library's bundled `SDLApp` is a game-loop scaffold (fixed 60Hz, catch-up ticks) — wrong model for a GUI. Direct calls are fewer lines and better fit. |
| **Abstract class** | `SDLApp` doesn't implement `Build()`; subclasses do. Keeps the framework's rebuild-on-invalidate contract intact. |
| **PFUI.Color for clear color** | Backend-agnostic at the property boundary; avoids coupling to SDL's color type. |
| **Event-driven loop (inner/outer)** | Inner loop drains all queued events; outer loop does one rebuild + render per iteration. Cleaner than the single-while-with-`\|\| true` pattern, and no game-style fixed-timestep. |
| **SDL3 over SDL2** | User preference; the raw C-style SDL3 binding is actually a better fit (no bundled scaffold to avoid). |

## Roads not taken

- **Using SDL2.SDLApp as a base class.** Rejected: game-loop semantics would need unwinding by M3; saves no meaningful effort for M0.
- **SDL2 with separate CreateWindow + CreateRenderer.** Rendered moot by the SDL3 switch, where `SDL_CreateWindowAndRenderer` is the natural single call.
- **Exposing SDL types in SDLApp's public API (beyond `SDL_Renderer*`).** Kept minimal — `Width`, `Height`, `Renderer`, `ClearColor` are the only public surface. The `Draw()` hook is the extension point for M1+ rendering.

## Exit criteria met

- [x] Colored window opens
- [x] Window closes on ✕ (SDL_EVENT_QUIT handled)
- [x] Existing test flags (`--test-mismatch`, `--test-unbalanced`, `--test-leftover`) preserved
- [x] Beef+SDL3 links and runs
