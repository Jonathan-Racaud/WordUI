using System;

namespace PFUI;

// Intrinsic size returned by Component.Measure during the layout pass.
public struct Size
{
	public float Width, Height;

	public this(float w, float h)
	{
		Width = w; Height = h;
	}
}
