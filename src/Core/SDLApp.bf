using System;
using SDL3;
using SDL3_ttf;

namespace WordUI;

// SDL3-backed App: manages a window + renderer lifecycle, font loading,
// layout pass, and rendering. Subclasses override Build() (from App) to
// define the widget tree.
public abstract class SDLApp : App
{
	SDL_Window* mWindow;
	SDL_Renderer* mRenderer;
	String mTitle = new .("WordUI") ~ delete _;
	int32 mWidth = 1024;
	int32 mHeight = 768;
	Color mClearColor = .(30, 30, 30, 255);
	TTF_Font* mDefaultFont;
	Painter mPainter ~ delete _;

	public this()
	{
		App.Instance = this;
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
		DrawWidget(Root, 0, 0);
	}

	// (ox,oy) is the accumulated render-time offset from an ancestor drag. When
	// this widget is the one being dragged, its own offset is added and inherited
	// by its subtree — the visual follows the pointer without any relayout.
	void DrawWidget(Widget w, float ox, float oy)
	{
		if (w == null)
			return;

		var ox, oy;
		if (Store.DragActive && w.StableKey == Store.DragKey)
		{
			let (dx, dy) = Store.DragOffset(w.StableKey);
			ox += dx; oy += dy;
		}

		Rect bounds = .(w.mRect.X + ox, w.mRect.Y + oy, w.mRect.Width, w.mRect.Height);

		// 1. Background — fills behind everything (Interior)
		for (let c in w.Components)
			c.DrawBackground(mPainter, w, bounds);

		// 2. Content — widget's own content (TextStyle, custom drawing)
		for (let c in w.Components)
			c.DrawContent(mPainter, w, bounds);

		// 3. Children — recurse, optionally clipped to this widget's box and
		// translated by its persistent scroll offset (same render-time offset
		// mechanism as drag, folded into a private childOx/childOy).
		var childOx = ox, childOy = oy;

		bool clip = w.GetComponent<ClipRegion>() != null;
		if (clip)
			mPainter.PushClip(bounds);

		if (w.GetComponent<ScrollView>() != null)
		{
			let off = Store.GetScroll(w.StableKey);
			let stack = w.GetComponent<StackLayout>();
			if (stack == null || stack.Axis == .Vertical)
				childOy -= off;
			else
				childOx -= off;
		}

		let children = w.GetComponent<Children>();
		if (children != null)
		{
			for (let child in children.Items)
				DrawWidget(child, childOx, childOy);
		}

		if (clip)
			mPainter.PopClip();

		// 4. Overlay — strokes on top of content and children (Boundary),
		// unclipped so a container's own border draws around its full box.
		for (let c in w.Components)
			c.DrawOverlay(mPainter, w, bounds);
	}

	// Enter the event loop. Returns when the window is closed.
	//
	// Frame-batched and event-driven: when nothing is animating or dragging the
	// loop BLOCKS in SDL_WaitEvent (true zero idle CPU); while a transition or
	// drag is in flight it uses a ~16ms timeout as a frame clock. After each wake
	// it drains all pending events (coalescing motion), advances animation
	// clocks, then rebuilds+lays-out only on mDirty, else repaints only.
	public void Run()
	{
		RebuildIfNeeded();
		Layout.Run(Rect(0, 0, mWidth, mHeight), Root);
		DumpTree();
		Render();

		bool quit = false;
		SDL_Event event = .();
		while (!quit)
		{
			// Block when idle; tick at ~60fps while animating/dragging.
			if (Store.NeedsTick)
			{
				if (SDL_WaitEventTimeout(&event, 16))
					HandleEvent(event, ref quit);
			}
			else if (SDL_WaitEvent(&event))
			{
				HandleEvent(event, ref quit);
			}

			// Drain the rest of the queue, coalescing motion to the last position.
			bool hadMotion = false;
			float motionX = 0, motionY = 0;
			while (SDL_PollEvent(&event))
			{
				if (event.type == (uint32)SDL_EventType.SDL_EVENT_MOUSE_MOTION)
				{
					hadMotion = true;
					motionX = event.motion.x; motionY = event.motion.y;
					continue;
				}
				HandleEvent(event, ref quit);
			}
			if (hadMotion)
				HandleMotion(motionX, motionY);

			// Advance animation clocks against wall-clock time.
			Store.Tick((int)SDL_GetTicks());

			if (RebuildIfNeeded())
			{
				Layout.Run(Rect(0, 0, mWidth, mHeight), Root);
				Render();
			}
			else if (NeedsRepaint || Store.NeedsTick)
			{
				Render();
				ClearRepaint();
			}
		}
	}

	void HandleEvent(SDL_Event event, ref bool quit)
	{
		switch (event.type)
		{
		case (uint32)SDL_EventType.SDL_EVENT_QUIT:
			quit = true;
		case (uint32)SDL_EventType.SDL_EVENT_WINDOW_RESIZED:
			mWidth = (int32)event.window.data1;
			mHeight = (int32)event.window.data2;
			Invalidate();
		case (uint32)SDL_EventType.SDL_EVENT_MOUSE_MOTION:
			HandleMotion(event.motion.x, event.motion.y);
		case (uint32)SDL_EventType.SDL_EVENT_MOUSE_WHEEL:
			InputEvent wheel = .() {
				Type = .MouseWheel,
				X = event.wheel.mouse_x, Y = event.wheel.mouse_y,
				WheelX = event.wheel.x, WheelY = event.wheel.y
			};
			ScrollTracker.HandleWheel(Root, wheel);
		case (uint32)SDL_EventType.SDL_EVENT_MOUSE_BUTTON_DOWN:
			if (event.button.button == (uint8)SDL_MouseButtonFlags.SDL_BUTTON_LEFT)
			{
				if (!DragTracker.HandleDown(Root, event.button.x, event.button.y))
				{
					InputEvent input = .() { Type = .MouseDown, X = event.button.x, Y = event.button.y };
					PressTracker.HandleEvent(Root, input);
				}
			}
		case (uint32)SDL_EventType.SDL_EVENT_MOUSE_BUTTON_UP:
			if (event.button.button == (uint8)SDL_MouseButtonFlags.SDL_BUTTON_LEFT)
			{
				if (Store.DragActive)
					DragTracker.HandleUp();
				InputEvent input = .() { Type = .MouseUp, X = event.button.x, Y = event.button.y };
				PressTracker.HandleEvent(Root, input);
			}
		default:
		}
	}

	// A drag capture takes precedence over hover updates while it is active.
	void HandleMotion(float x, float y)
	{
		if (Store.DragActive)
			DragTracker.HandleMotion(Root, x, y);
		else
			HoverTracker.HandleMotion(Root, x, y);
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
