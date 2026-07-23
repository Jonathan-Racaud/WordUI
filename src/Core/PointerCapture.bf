using System;

namespace WordUI;

// Per-pointer-session capture state owned by App. When an IInputHandler returns
// true from HandleEvent on MouseDown, the InputDispatcher records a capture on
// the handler's widget. While captured, subsequent HandleEvent and HandleMotion
// calls route exclusively to that widget's behaviors (not the hit chain) until
// MouseUp releases the capture.
//
// Generic — not drag-specific. Any interaction type (drag, long-press, gesture)
// can claim capture. The accumulated offset and last position support drag delta
// computation, but non-drag captures can ignore them.
public struct PointerCapture
{
	public int Key;           // StableKey of the capturing widget, 0 = no capture
	public float LastX;       // last known pointer X (for delta computation)
	public float LastY;       // last known pointer Y

	public bool Active => Key != 0;

	public void Begin(int key, float x, float y) mut
	{
		Key = key;
		LastX = x;
		LastY = y;
	}

	// Returns the incremental delta since the last motion/call.
	public (float dx, float dy) Update(float x, float y) mut
	{
		let dx = x - LastX;
		let dy = y - LastY;
		LastX = x;
		LastY = y;
		return (dx, dy);
	}

	public void End() mut
	{
		Key = 0;
	}
}
