# M1 Summary

## What we built

The widget tree now renders on screen. SDL3_ttf handles text measurement and rasterization. A flex layout pass runs after each rebuild, assigning a `Rect` to every widget. The `Painter` module localizes all SDL drawing calls. `CounterSDLApp` extends `SDLApp` with the CounterApp's widget tree and renders it in a window.

## Files changed

| File | Status | Purpose |
|---|---|---|
| `src/Core/Rect.bf` | New | `struct Rect { X, Y, W, H }` |
| `src/Core/Size.bf` | New | `struct Size { W, H }` |
| `src/Core/Painter.bf` | New | Concrete drawing: `FillRect`, `DrawRect`, `DrawText`, `MeasureText` |
| `src/Core/Layout.bf` | New | Static flex layout pass |
| `src/Core/Component.bf` | Modified | Added `Measure` + `Draw` virtual hooks |
| `src/Core/Widget.bf` | Modified | Added `mRect` field |
| `src/Core/App.bf` | Modified | Added `protected Root` property |
| `src/Core/SDLApp.bf` | Modified | TTF init, font loading, Painter, layout+draw integration, resize handling |
| `src/Components/TextStyle.bf` | Modified | `Measure` via `TTF_GetStringSize`, `Draw` via `painter.DrawText` |
| `src/Program.bf` | Modified | `M0App` → `CounterSDLApp` |

## Decisions

| Decision | Rationale |
|---|---|
| **SDL3_ttf over stb_truetype** | `TTF_RenderText_Blended` + `SDL_CreateTextureFromSurface` handles glyph iteration and blending in two calls; stb_truetype would have required a full glyph cache |
| **Static font access (`SDLApp.sDefaultFont`)** | Keeps `Component.Measure` API simple; acknowledged as temporary until multi-size font support |
| **Concrete Painter (no interface)** | Per roadmap discipline: "localize SDL in one concrete module"; extract interface later |
| **Spacer as bare widget (no component)** | Simple: identified by `widget.Name == "Spacer"`; layout pass handles it directly |
| **`Layout.Run()` as separate pass** | Clean separation: `Build()` → `Layout.Run()` → `Render()` → `Draw()` |
| **Font: FunnelSans-Regular.ttf at 16pt** | Bundled in `assets/fonts/`; single size for M1, font size per TextStyle deferred |

## Roads not taken

- **stb_truetype.** Explored then abandoned once SDL3_ttf became available. More work for no benefit.
- **Per-widget font sizes.** TextStyle has a `FontSize` field that is currently ignored — `TTF_OpenFont` locks the size at load time. Deferred to when multi-size is needed.
- **Glyph/texture caching.** Each `DrawText` call creates a surface → texture → render → destroy. Fine for M1's static tree; caching belongs in the repaint loop (M2+).
- **DPI scaling.** Window resize updates dimensions but doesn't re-scale the font. Deferred.
- **Interface on Painter.** Explicitly deferred per roadmap — extract from working code, not designed blind.

## Exit criteria met

- [x] Counter UI appears, laid out, in the window
- [x] Text measures and renders correctly
- [x] Flex layout: VStack, HStack, Spacer work
- [x] Window resize triggers rebuild + relayout
- [x] Existing `--test-*` flags preserved
