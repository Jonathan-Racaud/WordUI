# M0 Discussion Log

## Should we use SDL2.SDLApp as a base class?

**Proposal:** Use the existing `SDL2.SDLApp` scaffold from the BeefLibs SDL2 package as the basis for `WordUI.SDLApp`.

**Analysis of SDL2.SDLApp:**
- Provides: window + renderer creation, event loop, input dispatch (KeyDown, MouseDown, etc.), resize handling, 60Hz fixed-timestep with catch-up ticks, SDLImage/SDLMixer/SDLTTF init, letterboxing/scaling
- Game-loop semantics: `Update()` called every frame, render every frame — burns CPU regardless of UI changes
- ~470 lines, most irrelevant to WordUI (Image, Sound, Font, BMFont classes bundled inline)

**Decision: Do not use SDL2.SDLApp.** Write minimal direct SDL calls (~80 lines). Rationale:
- The fixed-timestep game loop is the wrong model for a GUI (redraw-on-demand vs. render-every-frame)
- M3 explicitly introduces a repaint-vs-rebuild split to avoid frame-burning; we'd be fighting the base class by then
- For M0 we need ~40 lines of SDL init + event loop; SDL2.SDLApp doesn't save meaningful effort
- Roadmap explicitly says "stand up the SDL window/loop directly"

## SDL2 → SDL3 switch

**Decision:** Mid-implementation, switched from SDL2 to SDL3. The SDL3 Beef binding (`SDL3-Beef.git`) is a raw C-style wrapper with no convenience classes — but that actually helps: no temptation to lean on a game-loop scaffold.

**Key API differences:**
- `SDL3.Raw` namespace, C-style function names (`SDL_Init`, `SDL_PollEvent`, etc.)
- `SDL_Init` returns `c_bool` (not int32); `SDL_INIT_VIDEO` implies `SDL_INIT_EVENTS`
- `SDL_CreateWindowAndRenderer` combines window + renderer creation in one call
- `SDL_Event` is a C union (`event.type` is `uint32`, compare with `SDL_EventType.SDL_EVENT_QUIT`)
- `SDL_PollEvent(&event)` takes a pointer, returns bool
- No `SDL_Color` struct — cleanly forces use of WordUI's own `Color`

## Color type: backend-specific vs. WordUI-native

**Decision:** Use `WordUI.Color` (already exists in `src/Core/Color.bf`) for the clear color property. Keeps SDLApp backend-agnostic at the property boundary; the render path does the trivial `mClearColor.R/G/B/A` pass-through to `SDL_SetRenderDrawColor`.

## Build tool restriction

`BeefBuild` CLI has a managed-dependency cache-state issue with the SDL3 package. All builds go through the Beef IDE. Recorded in `AGENTS.md`.
