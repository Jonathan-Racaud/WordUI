# M1 — The Static Tree Renders

**Goal:** Layout + render the CounterApp widget tree in the SDL3 window. Text measurement and rasterization are the core sleeper — SDL3_ttf covers both. Exit: the counter UI appears, laid out, in the window — not yet clickable.

## Plan

1. **Data types** — new files `src/Core/Rect.bf` (`struct Rect { X, Y, W, H }`) and `src/Core/Size.bf` (`struct Size { W, H }`). Add `Rect mRect` to `Widget`.

2. **Component hooks** — add `virtual Size Measure(Size constraint)` and `virtual void Draw(Painter painter, Rect bounds)` to `Component`. Default: zero size / no-op.

3. **SDL3_ttf + font in SDLApp** — `TTF_Init()` in constructor, `TTF_OpenFont("assets/fonts/Funnel_Sans/FunnelSans-Regular.ttf", 16)`, expose `TTF_Font*` via static `sDefaultFont` and instance property. `TTF_CloseFont` + `TTF_Quit` in destructor.

4. **Painter module** (`src/Core/Painter.bf`) — concrete class over `SDL_Renderer*` + `TTF_Font*`. Methods: `FillRect`, `DrawRect`, `DrawText`, `MeasureText`. All SDL drawing localized here; no interface (extracted later).

5. **Flex layout pass** (`src/Core/Layout.bf`) — static class, recursive. Constraints-down → sizes-up → sum-main/max-cross → leftover→Spacer. Runs after `RebuildIfNeeded()`, before `Render()`.

6. **TextStyle.Measure/Draw** — `Measure` calls `TTF_GetStringSize` via static font. `Draw` calls `painter.DrawText`.

7. **SDLApp integration** — `Painter` constructed after renderer. Layout runs after rebuild. `Draw()` walks tree → calls `Component.Draw` on each. Window resize (`SDL_EVENT_WINDOW_RESIZED`) → `Invalidate()`.

8. **Demo** — `M0App` replaced with `CounterSDLApp`: CounterApp's Build() content rendered in the window.
