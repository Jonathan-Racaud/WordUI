using System;

namespace WordUI;

// Adapted SDL event at the framework boundary: SDL types never cross into
// hit-testing, dispatch, or any handler.
public struct InputEvent
{
	public enum Kind
	{
		MouseDown,
		MouseUp,
		MouseMotion,
		MouseWheel,
		KeyDown
	}

	public Kind Type;
	public float X, Y;          // pointer position in window coords
	public float WheelX, WheelY; // scroll amounts (MouseWheel only)
	public int KeyCode;          // SDL keycode (KeyDown only)
	public int KeyModifiers;     // SDL keymod bitmask (KeyDown only)
}
