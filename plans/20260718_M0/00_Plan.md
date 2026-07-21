# M0 — A window that opens

**Goal:** SDL window + event loop + clear-to-color + close on ✕. Minimal WordUI involvement; de-risk "does Beef+SDL link and run" before any framework code depends on it.

## Plan

1. **Create `src/Core/SDLApp.bf`** — `WordUI.SDLApp : App`
   - Fields: `SDL_Window*`, `SDL_Renderer*`, title, dimensions, clear color
   - Constructor: `SDL_Init(SDL_INIT_VIDEO)`, `SDL_CreateWindowAndRenderer`
   - Destructor: destroy renderer → destroy window → `SDL_Quit`
   - `protected virtual void Draw()` — empty hook for subclasses (M1+)
   - `public void Run()` — event loop: inner poll loop drains events, outer loop rebuilds + renders
   - `private void Render()` — set draw color → clear → `Draw()` → present

2. **Wire a minimal demo in `src/Program.bf`**
   - `M0App : SDLApp` — sets a non-black clear color, overrides `Build()` with empty `VStack`
   - Default run path (no flags) launches the SDL window via `app.Run()`
   - Existing `--test-*` flags preserved unchanged
   - CounterApp console demo preserved behind `--test-counter`

3. **Decisions made in plan phase**
   - Do not use the SDL library's bundled `SDLApp` class (game-loop scaffold, wrong semantics for a GUI)
   - Direct SDL calls only; no backend abstraction yet (per roadmap's "localize SDL in one concrete module" discipline)
   - `SDLApp` is abstract — subclasses provide `Build()` (from `App`) and optionally `Draw()` (for rendering)
   - Clear color uses WordUI's own `Color` struct, not any backend-specific color type
