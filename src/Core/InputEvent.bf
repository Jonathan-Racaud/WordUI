using System;

namespace WordUI;

// Backend-neutral input event forwarded to hit-testing and handlers.
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
	public int KeyCode;          // KeyCode value (KeyDown only)
	public int KeyModifiers;     // KeyModifier bitmask (KeyDown only)
}
