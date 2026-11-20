using RaylibBeef;
using static RaylibBeef.Raylib;

namespace WordUI;

// Host-driven Raylib adapter. The host owns the window and calls Update before
// its BeginDrawing/EndDrawing pair, then Draw inside that pair.
public class RaylibBackend
{
	App mApp;
	RaylibPainter mPainter ~ delete _;
	int32 mNowMs;
	int32 mWidth;
	int32 mHeight;
	float mMouseX;
	float mMouseY;
	bool mHasMouse;

	public this(App app, Font font, float fontSize = 16)
	{
		mApp = app;
		mPainter = new RaylibPainter(font, fontSize);
		mApp.Painter = mPainter;
	}

	public ~this()
	{
		if (mApp != null && mApp.Painter == mPainter)
			mApp.Painter = null;
	}

	// Polls the host's current Raylib input state and advances WordUI by one frame.
	// The host remains responsible for BeginDrawing, clearing, and EndDrawing.
	public bool Update()
	{
		let mouse = GetMousePosition();
		if (!mHasMouse || mouse.x != mMouseX || mouse.y != mMouseY)
		{
			mApp.ProcessMotion(mouse.x, mouse.y);
			mMouseX = mouse.x;
			mMouseY = mouse.y;
			mHasMouse = true;
		}

		if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT))
			mApp.ProcessInput(.() { Type = .MouseDown, X = mouse.x, Y = mouse.y });
		if (IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT))
			mApp.ProcessInput(.() { Type = .MouseUp, X = mouse.x, Y = mouse.y });

		let wheel = GetMouseWheelMoveV();
		if (wheel.x != 0 || wheel.y != 0)
			mApp.ProcessInput(.() {
				Type = .MouseWheel,
				X = mouse.x, Y = mouse.y,
				WheelX = wheel.x, WheelY = wheel.y
			});

		int32 key = GetKeyPressed();
		while (key != 0)
		{
			mApp.ProcessInput(.() {
				Type = .KeyDown,
				KeyCode = key,
				KeyModifiers = ReadModifiers()
			});
			key = GetKeyPressed();
		}

		int32 width = GetScreenWidth();
		int32 height = GetScreenHeight();
		if (width != mWidth || height != mHeight)
		{
			mWidth = width;
			mHeight = height;
			mApp.RequestLayout();
		}

		mNowMs = (int32)(GetTime() * 1000);
		return mApp.UpdateFrame(
			Rect(0, 0, (float)width, (float)height),
			mNowMs
		);
	}

	// Draws into the current Raylib drawing frame.
	public void Draw()
	{
		mApp.DrawFrame(mPainter);
	}

	static int ReadModifiers()
	{
		int result = 0;
		if (IsKeyDown(KeyboardKey.KEY_LEFT_SHIFT) || IsKeyDown(KeyboardKey.KEY_RIGHT_SHIFT))
			result |= (int)KeyModifier.Shift;
		if (IsKeyDown(KeyboardKey.KEY_LEFT_CONTROL) || IsKeyDown(KeyboardKey.KEY_RIGHT_CONTROL))
			result |= (int)KeyModifier.Control;
		if (IsKeyDown(KeyboardKey.KEY_LEFT_ALT) || IsKeyDown(KeyboardKey.KEY_RIGHT_ALT))
			result |= (int)KeyModifier.Alt;
		if (IsKeyDown(KeyboardKey.KEY_LEFT_SUPER) || IsKeyDown(KeyboardKey.KEY_RIGHT_SUPER))
			result |= (int)KeyModifier.Super;
		return result;
	}
}
