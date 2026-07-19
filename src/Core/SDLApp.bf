using System;
using SDL3;
using SDL3_ttf;

namespace PFUI;

// SDL3-backed App: manages a window + renderer lifecycle, font loading,
// layout pass, and rendering. Subclasses override Build() (from App) to
// define the widget tree.
public abstract class SDLApp : App
{
	SDL_Window* mWindow;
	SDL_Renderer* mRenderer;
	String mTitle = new .("PFUI") ~ delete _;
	int32 mWidth = 1024;
	int32 mHeight = 768;
	Color mClearColor = .(30, 30, 30, 255);
	TTF_Font* mDefaultFont;
	Painter mPainter ~ delete _;

	public this()
	{
		SDL_Init(.SDL_INIT_VIDEO);
		TTF_Init();
		SDL_CreateWindowAndRenderer(
			mTitle,
			mWidth,
			mHeight,
			0,
			&mWindow,
			&mRenderer
		);
		mDefaultFont = TTF_OpenFont(
			"assets/fonts/Funnel_Sans/FunnelSans-Regular.ttf",
			16
		);
		mPainter = new Painter(mRenderer, mDefaultFont);
		sDefaultFont = mDefaultFont;
	}

	public static TTF_Font* sDefaultFont;

	public ~this()
	{
		if (mDefaultFont != null)
			TTF_CloseFont(mDefaultFont);
		if (mRenderer != null)
			SDL_DestroyRenderer(mRenderer);
		if (mWindow != null)
			SDL_DestroyWindow(mWindow);
		sDefaultFont = null;
		TTF_Quit();
		SDL_Quit();
	}

	public int32 Width => mWidth;
	public int32 Height => mHeight;
	public SDL_Renderer* Renderer => mRenderer;
	public TTF_Font* DefaultFont => mDefaultFont;
	public Color ClearColor { get => mClearColor; set => mClearColor = value; }

	// Called each frame after the clear. Default walks the widget tree
	// and draws each widget at its layout rect.
	private void Draw()
	{
		DrawWidget(Root);
	}

	void DrawWidget(Widget w)
	{
		if (w == null)
			return;

		// 1. Background — fills behind everything (Interior)
		for (let c in w.Components)
			c.DrawBackground(mPainter, w, w.mRect);

		// 2. Content — widget's own content (TextStyle, custom drawing)
		for (let c in w.Components)
			c.DrawContent(mPainter, w, w.mRect);

		// 3. Children — recurse
		let children = w.Get<Children>();
		if (children != null)
		{
			for (let child in children.Items)
				DrawWidget(child);
		}

		// 4. Overlay — strokes on top of content and children (Boundary)
		for (let c in w.Components)
			c.DrawOverlay(mPainter, w, w.mRect);
	}

	// Enter the event loop. Returns when the window is closed.
	public void Run()
	{
		RebuildIfNeeded();
		Layout.Run(Rect(0, 0, mWidth, mHeight), Root);
		DumpTree();

		bool quit = false;
		SDL_Event event = .();
		while (!quit)
		{
			while (SDL_PollEvent(&event))
			{
				switch (event.type)
				{
				case (uint32)SDL_EventType.SDL_EVENT_QUIT:
					quit = true;
				case (uint32)SDL_EventType.SDL_EVENT_WINDOW_RESIZED:
					mWidth = (int32)event.window.data1;
					mHeight = (int32)event.window.data2;
					Invalidate();
				case (uint32)SDL_EventType.SDL_EVENT_MOUSE_BUTTON_DOWN:
					if (event.button.button == (uint8)SDL_MouseButtonFlags.SDL_BUTTON_LEFT)
					{
							InputEvent input = .() { Type = .MouseDown, X = event.button.x, Y = event.button.y };
						PressTracker.HandleEvent(Root, input);
					}
				case (uint32)SDL_EventType.SDL_EVENT_MOUSE_BUTTON_UP:
					if (event.button.button == (uint8)SDL_MouseButtonFlags.SDL_BUTTON_LEFT)
					{
							InputEvent input = .() { Type = .MouseUp, X = event.button.x, Y = event.button.y };
						PressTracker.HandleEvent(Root, input);
					}
				default:
				}
			}

			if (RebuildIfNeeded())
				Layout.Run(Rect(0, 0, mWidth, mHeight), Root);
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
