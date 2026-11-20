using System;
using SDL3;
using SDL3_ttf;

namespace WordUI;

// SDL3 host adapter. It owns the SDL window/event loop while App owns the
// backend-neutral build, layout, input dispatch, and draw traversal.
public abstract class SDLApp : App
{
	SDL_Window* mWindow;
	SDL_Renderer* mRenderer;
	String mTitle = new .("WordUI") ~ delete _;
	int32 mWidth = 1024;
	int32 mHeight = 768;
	Color mClearColor = .(30, 30, 30, 255);
	TTF_Font* mDefaultFont;
	SDLPainter mPainter ~ delete _;

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
		mPainter = new SDLPainter(mRenderer, mDefaultFont);
		Painter = mPainter;
	}

	public ~this()
	{
		Dispose();
		if (App.Instance == this)
			App.Instance = null;
		Painter = null;
		if (mDefaultFont != null)
			TTF_CloseFont(mDefaultFont);
		if (mRenderer != null)
			SDL_DestroyRenderer(mRenderer);
		if (mWindow != null)
			SDL_DestroyWindow(mWindow);
		TTF_Quit();
		SDL_Quit();
	}

	public int32 Width => mWidth;
	public int32 Height => mHeight;
	public SDL_Renderer* Renderer => mRenderer;
	public TTF_Font* DefaultFont => mDefaultFont;
	public Color ClearColor { get => mClearColor; set => mClearColor = value; }

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

			if (UpdateFrame(Rect(0, 0, mWidth, mHeight), (int)SDL_GetTicks()))
				Render();
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
			ProcessInput(.() {
				Type = .MouseWheel,
				X = event.wheel.mouse_x, Y = event.wheel.mouse_y,
				WheelX = event.wheel.x, WheelY = event.wheel.y
			});
		case (uint32)SDL_EventType.SDL_EVENT_MOUSE_BUTTON_DOWN:
			if (event.button.button == (uint8)SDL_MouseButtonFlags.SDL_BUTTON_LEFT)
				ProcessInput(.() { Type = .MouseDown, X = event.button.x, Y = event.button.y });
		case (uint32)SDL_EventType.SDL_EVENT_MOUSE_BUTTON_UP:
			if (event.button.button == (uint8)SDL_MouseButtonFlags.SDL_BUTTON_LEFT)
				ProcessInput(.() { Type = .MouseUp, X = event.button.x, Y = event.button.y });
		case (uint32)SDL_EventType.SDL_EVENT_KEY_DOWN:
			ProcessInput(.() {
				Type = .KeyDown,
				KeyCode = NormalizeKey((int)event.key.key),
				KeyModifiers = NormalizeModifiers((int)event.key.mod)
			});
		default:
		}
	}

	static int NormalizeKey(int key)
	{
		if (key >= 97 && key <= 122)
			return key - 32;
		switch (key)
		{
		case 13: return (int)KeyCode.Enter;
		case 27: return (int)KeyCode.Escape;
		case 8: return (int)KeyCode.Backspace;
		case 9: return (int)KeyCode.Tab;
		case 127: return (int)KeyCode.Delete;
		case 1073741897: return (int)KeyCode.Insert;
		case 1073741898: return (int)KeyCode.Home;
		case 1073741899: return (int)KeyCode.PageUp;
		case 1073741901: return (int)KeyCode.End;
		case 1073741902: return (int)KeyCode.PageDown;
		case 1073741903: return (int)KeyCode.Right;
		case 1073741904: return (int)KeyCode.Left;
		case 1073741905: return (int)KeyCode.Down;
		case 1073741906: return (int)KeyCode.Up;
		case 1073741882: return (int)KeyCode.F1;
		case 1073741883: return (int)KeyCode.F2;
		case 1073741884: return (int)KeyCode.F3;
		case 1073741885: return (int)KeyCode.F4;
		case 1073741886: return (int)KeyCode.F5;
		case 1073741887: return (int)KeyCode.F6;
		case 1073741888: return (int)KeyCode.F7;
		case 1073741889: return (int)KeyCode.F8;
		case 1073741890: return (int)KeyCode.F9;
		case 1073741891: return (int)KeyCode.F10;
		case 1073741892: return (int)KeyCode.F11;
		case 1073741893: return (int)KeyCode.F12;
		case 1073741881: return (int)KeyCode.CapsLock;
		case 1073741894: return (int)KeyCode.PrintScreen;
		case 1073741895: return (int)KeyCode.ScrollLock;
		case 1073741896: return (int)KeyCode.Pause;
		case 1073741907: return (int)KeyCode.NumLock;
		case 1073741908: return (int)KeyCode.KeypadDivide;
		case 1073741909: return (int)KeyCode.KeypadMultiply;
		case 1073741910: return (int)KeyCode.KeypadSubtract;
		case 1073741911: return (int)KeyCode.KeypadAdd;
		case 1073741912: return (int)KeyCode.KeypadEnter;
		case 1073741913: return (int)KeyCode.Keypad1;
		case 1073741914: return (int)KeyCode.Keypad2;
		case 1073741915: return (int)KeyCode.Keypad3;
		case 1073741916: return (int)KeyCode.Keypad4;
		case 1073741917: return (int)KeyCode.Keypad5;
		case 1073741918: return (int)KeyCode.Keypad6;
		case 1073741919: return (int)KeyCode.Keypad7;
		case 1073741920: return (int)KeyCode.Keypad8;
		case 1073741921: return (int)KeyCode.Keypad9;
		case 1073741922: return (int)KeyCode.Keypad0;
		case 1073741923: return (int)KeyCode.KeypadDecimal;
		case 1073741927: return (int)KeyCode.KeypadEqual;
		case 1073742049: return (int)KeyCode.LeftShift;
		case 1073742053: return (int)KeyCode.RightShift;
		case 1073742048: return (int)KeyCode.LeftControl;
		case 1073742052: return (int)KeyCode.RightControl;
		case 1073742050: return (int)KeyCode.LeftAlt;
		case 1073742054: return (int)KeyCode.RightAlt;
		case 1073742051: return (int)KeyCode.LeftSuper;
		case 1073742055: return (int)KeyCode.RightSuper;
		default: return key;
		}
	}

	static int NormalizeModifiers(int modifiers)
	{
		int result = 0;
		if ((modifiers & 0x0003) != 0)
			result |= (int)KeyModifier.Shift;
		if ((modifiers & 0x00C0) != 0)
			result |= (int)KeyModifier.Control;
		if ((modifiers & 0x0300) != 0)
			result |= (int)KeyModifier.Alt;
		if ((modifiers & 0x0C00) != 0)
			result |= (int)KeyModifier.Super;
		return result;
	}

	// Dispatch pointer motion through registered trackers. The InputDispatcher
	// handles hit-testing, capture routing, and hover enter/leave.
	void HandleMotion(float x, float y)
	{
		ProcessMotion(x, y);
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
		DrawFrame(mPainter);
		SDL_RenderPresent(mRenderer);
	}
}
