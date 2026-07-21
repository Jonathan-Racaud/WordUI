# M1 Discussion Log

## Dependency churn: stb_truetype → SDL3_ttf

**stb_truetype attempt:** User initially brought `stb_truetype-Beef` as a dependency. After exploring the API, it provided raw C bindings (`stbtt_InitFont`, `stbtt_GetCodepointBitmap`, etc.) with no high-level wrapper. Would have required writing a full `Font` class with glyph caching, UTF-8 codepoint iteration, and bitmap→texture conversion from scratch.

**Switch to SDL3_ttf:** User then brought `SDL3_ttf-Beef` (v3.2.2). This provides:
- `TTF_Init()` / `TTF_Quit()` — lifecycle
- `TTF_OpenFont(path, ptsize)` — font loading
- `TTF_GetStringSize(font, text, length, &w, &h)` — measurement
- `TTF_RenderText_Blended(font, text, length, color)` → `SDL_Surface*` — rasterization
- `TTF_CloseFont(font)` — cleanup

Much simpler: `TTF_RenderText_Blended` handles all glyph iteration and blending internally. Combine with `SDL_CreateTextureFromSurface` for one-call text→texture→render path.

**Impact on plan:** Eliminated the need for a WordUI `Font` wrapper class. The `Painter` module directly uses `TTF_Font*` and the SDL3_ttf C API. Cut implementation from ~8 steps to ~5.

## Font access pattern: static vs dependency injection

**Problem:** `TextStyle.Measure(Size constraint)` needs a font but doesn't receive one as a parameter. The `Component.Measure` hook is deliberately simple.

**Options considered:**
- Store font on `TextStyle` — requires every `Label()`/`Button()` word to pass a font, polluting the word API
- Pass font through the constraint — abuse of the constraint type
- Global/static font — simple, works for M1, easily replaced later

**Decision: Static font.** `SDLApp.sDefaultFont` is set during construction and read by `TextStyle.Measure`. The `Painter` also holds a font reference (passed explicitly). This is acknowledged as temporary — when multi-size fonts land, the pattern will evolve.

## mRoot accessibility

`App.mRoot` was private. Needed by `SDLApp.Draw()` and `SDLApp.Run()` to walk the tree. Added `protected Widget Root => mRoot` property to `App`. Simpler than making the field protected (which would allow mutation).

## Painter design: concrete vs interface

Per roadmap: "localize SDL in one concrete module — no interface, no virtual dispatch." The `Painter` class is a plain concrete class with `SDL_Renderer*` and `TTF_Font*` fields. All SDL drawing calls flow through it. Component `Draw` hooks receive it as a parameter, so components never touch SDL types. When the time comes to extract a renderer abstraction, this becomes a mechanical extract-interface refactor.

## Layout algorithm details

- Spacer identified by `widget.Name == "Spacer"` (no component) — the `Spacer()` word creates a bare widget with no components
- Children measured in one pass, rects assigned in a second pass — sizes stored in a scope-allocated `float[]` array
- Padding applied in `MeasureWidget` (adds to intrinsic size) and `LayoutWidget` (reduces inner rect for children)
- Cross-axis constraint passed to children (e.g., VStack passes full width), main-axis is unbounded (`float.MaxValue`)
- Leftover space distributed equally to spacers via `Math.Max(0, leftover / spacerCount)`

## Window resize

SDL3 event `SDL_EVENT_WINDOW_RESIZED` with `event.window.data1`/`data2` for width/height. Triggers `Invalidate()` → rebuild + relayout on next frame. No separate DPI handling yet (deferred).
