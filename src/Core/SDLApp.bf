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

		// Register the single input dispatcher. It hit-tests, walks the widget
		// chain leaf→root, and routes events to IInputHandler behaviors on each
		// widget. Any IInputHandler returning true from HandleEvent on MouseDown
		// claims the pointer capture. User-authored interaction types need only
		// implement IInputHandler — no tracker registration needed.
		RegisterTracker(new InputDispatcher());
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
	// and draws each widget at its layout rect. Skips subtrees whose
	// retained RenderNode is paint-clean.
	private void Draw()
	{
		let rootNode = App.Instance.FindNode(Root.StableKey);
		DrawWidget(Root, 0, 0, true, rootNode);
	}

	// (ox,oy) is the accumulated render-time offset from ancestor offsets
	// (drag, scroll, etc.). Each component on a widget may contribute an offset
	// via GetRenderOffset — the draw loop accumulates all of them into the
	// child rendering origin. No hardcoded knowledge of specific interaction
	// types in the draw pipeline.
	//
	// ancestorDirty: true when any ancestor in the chain needs paint. When both
	// ancestorDirty and the current node's RenderNode.NeedsPaint are false, the
	// entire subtree is paint-clean and skipped.
	void DrawWidget(Widget w, float ox, float oy, bool ancestorDirty, Node node)
	{
		if (w == null)
			return;

		// Paint-dirty subtree skip: if no ancestor is dirty and this node's
		// RenderNode reports clean, the entire subtree can be skipped. This is
		// safe because ClearPaintDirty() later does a full recursive clear
		// regardless of what was drawn.
		let rn = node?.RenderNode;
		bool thisDirty = ancestorDirty || (rn != null && rn.NeedsPaint);
		if (!thisDirty)
			return;

		// Accumulate render offsets from every component on this widget.
		var tx = ox;
		var ty = oy;
		for (let c in w.Components)
		{
			let (cox, coy) = c.GetRenderOffset(w, node);
			tx += cox;
			ty += coy;
		}

		// Read layout geometry from the retained RenderNode so rects survive
		// rebuilds and paint-only updates don't need re-layout.
		Rect bounds = rn != null
			? .(rn.Bounds.X + tx, rn.Bounds.Y + ty, rn.Bounds.Width, rn.Bounds.Height)
			: .(tx, ty, 0, 0);

		// 1. Background — fills behind everything (Interior)
		for (let c in w.Components)
			c.DrawBackground(mPainter, w, bounds);

		// 2. Content — widget's own content (TextStyle, custom drawing)
		for (let c in w.Components)
			c.DrawContent(mPainter, w, bounds);

		// 3. Children — recurse, optionally clipped to this widget's box.
		var childOx = tx, childOy = ty;

		bool clip = w.GetComponent<ClipRegion>() != null;
		if (clip)
			mPainter.PushClip(bounds);

		let children = w.GetComponent<Children>();
		if (children != null)
		{
			for (let child in children.Items)
			{
				let childNode = App.Instance.FindNode(child.StableKey);
				DrawWidget(child, childOx, childOy, thisDirty, childNode);
			}
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
		Layout.Run(Rect(0, 0, mWidth, mHeight), Root, mRootNode);
		DumpTree();
		Render();
		mRootNode?.ClearPaintDirty();

		bool quit = false;
		SDL_Event event = .();
		while (!quit)
		{
			// Block when idle; tick at ~60fps while animating/dragging.
			if (App.Instance.NeedsTick)
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
			App.Instance.TickAll((int)SDL_GetTicks());

			if (RebuildIfNeeded())
			{
				Layout.Run(Rect(0, 0, mWidth, mHeight), Root, mRootNode);
				Render();
				// Layout's SetBounds marks every node paint-dirty; clear after render.
				mRootNode?.ClearPaintDirty();
			}
			else if (LayoutIfNeeded(Rect(0, 0, mWidth, mHeight)))
			{
				Render();
			}
			else if (NeedsRepaint || App.Instance.NeedsTick)
			{
				Render();
				ClearRepaint();
				// Clear per-node paint-dirty flags after paint-only pass.
				// After a full rebuild, ClearDirty() handles this via LayoutIfNeeded.
				mRootNode?.ClearPaintDirty();
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
			RequestLayout();  // geometry changed, structure didn't — no rebuild needed
		case (uint32)SDL_EventType.SDL_EVENT_MOUSE_MOTION:
			HandleMotion(event.motion.x, event.motion.y);
		case (uint32)SDL_EventType.SDL_EVENT_MOUSE_WHEEL:
			DispatchEvent(.() {
				Type = .MouseWheel,
				X = event.wheel.mouse_x, Y = event.wheel.mouse_y,
				WheelX = event.wheel.x, WheelY = event.wheel.y
			});
		case (uint32)SDL_EventType.SDL_EVENT_MOUSE_BUTTON_DOWN:
			if (event.button.button == (uint8)SDL_MouseButtonFlags.SDL_BUTTON_LEFT)
				DispatchEvent(.() { Type = .MouseDown, X = event.button.x, Y = event.button.y });
		case (uint32)SDL_EventType.SDL_EVENT_MOUSE_BUTTON_UP:
			if (event.button.button == (uint8)SDL_MouseButtonFlags.SDL_BUTTON_LEFT)
				DispatchEvent(.() { Type = .MouseUp, X = event.button.x, Y = event.button.y });
		case (uint32)SDL_EventType.SDL_EVENT_KEY_DOWN:
			DispatchEvent(.() {
				Type = .KeyDown,
				KeyCode = (int)event.key.key,
				KeyModifiers = (int)event.key.mod
			});
		default:
		}
	}

	// Dispatch an event through registered trackers in priority order.
	// A tracker returning true stops iteration (consumes the event).
	void DispatchEvent(InputEvent input)
	{
		for (let t in App.Instance.Trackers)
			if (t.HandleEvent(Root, input))
				return;
	}

	// Dispatch pointer motion through registered trackers. The InputDispatcher
	// handles hit-testing, capture routing, and hover enter/leave.
	void HandleMotion(float x, float y)
	{
		for (let t in App.Instance.Trackers)
			if (t.HandleMotion(Root, x, y))
				return;
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
