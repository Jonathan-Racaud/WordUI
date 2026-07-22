using System;

namespace WordUI;

// Adapted SDL event at the framework boundary: SDL types never cross into
// hit-testing, dispatch, or any tracker.
public struct InputEvent
{
	public enum Kind
	{
		MouseDown,
		MouseUp,
		MouseMotion,
		MouseWheel
	}

	public Kind Type;
	public float X, Y;          // pointer position in window coords
	public float WheelX, WheelY; // scroll amounts (MouseWheel only)
}
