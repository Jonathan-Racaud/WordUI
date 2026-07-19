using System;
using SDL3.Raw;

namespace PFUI;

// SDL3-backed App: manages a window + renderer lifecycle and runs an
// event-driven loop. Subclasses override Build() (from App) plus the
// virtual Draw() hook to add framework rendering.
public abstract class SDLApp : App
{
	SDL_Window* mWindow;
	SDL_Renderer* mRenderer;
	String mTitle = new .("PFUI") ~ delete _;
	int32 mWidth = 1024;
	int32 mHeight = 768;
	Color mClearColor = .(30, 30, 30, 255);

	public this()
	{
		SDL_Init(.SDL_INIT_VIDEO);
		SDL_CreateWindowAndRenderer(
			mTitle,
			mWidth,
			mHeight,
			0,
			&mWindow,
			&mRenderer
		);
	}

	public ~this()
	{
		if (mRenderer != null)
			SDL_DestroyRenderer(mRenderer);
		if (mWindow != null)
			SDL_DestroyWindow(mWindow);
		SDL_Quit();
	}

	public int32 Width => mWidth;
	public int32 Height => mHeight;
	public SDL_Renderer* Renderer => mRenderer;
	public Color ClearColor { get => mClearColor; set => mClearColor = value; }

	// Override to add custom drawing after the clear.
	protected virtual void Draw()
	{
	}

	// Enter the event loop. Returns when the window is closed.
	public void Run()
	{
		RebuildIfNeeded();

		bool quit = false;
		SDL_Event event = .();
		while (!quit)
		{
			while (SDL_PollEvent(&event))
			{
				if ((SDL_EventType)event.type == .SDL_EVENT_QUIT)
					quit = true;
			}

			RebuildIfNeeded();
			Render();
		}
	}

	private void Render()
	{
		SDL_SetRenderDrawColor(
			mRenderer,
			mClearColor.R,
			mClearColor.G,
			mClearColor.B,
			mClearColor.A
		);
		SDL_RenderClear(mRenderer);
		Draw();
		SDL_RenderPresent(mRenderer);
	}
}
