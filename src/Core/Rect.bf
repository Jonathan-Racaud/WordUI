using System;

namespace PFUI;

// Axis-aligned rectangle in layout space — the shared currency between
// layout, rendering, and hit-testing.
public struct Rect
{
	public float X, Y, Width, Height;

	public this(float x, float y, float w, float h)
	{
		X = x; Y = y; Width = w; Height = h;
	}

	public float Right => X + Width;
	public float Bottom => Y + Height;
}
