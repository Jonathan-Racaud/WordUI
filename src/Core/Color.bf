using System;

namespace WordUI;

public struct Color
{
	public uint8 R, G, B, A;

	public this(uint8 r, uint8 g, uint8 b, uint8 a = 255)
	{
		R = r; G = g; B = b; A = a;
	}

	[Commutable]
	public static bool operator==(Color a, Color b)
	{
		return a.R == b.R && a.G == b.G && a.B == b.B && a.A == b.A;
	}

	public static readonly Color Black = .(0, 0, 0);
	public static readonly Color White = .(255, 255, 255);
	public static readonly Color Red = .(255, 0, 0);
	public static readonly Color Green = .(0, 255, 0);
	public static readonly Color Blue = .(0, 0, 255);

	// Component-wise linear interpolation. t is clamped to [0,1] by the caller
	// (the easing curve already maps into that range). Used by the draw-time
	// resolver to blend a base color toward an animated target.
	public static Color Lerp(Color a, Color b, float t)
	{
		uint8 lerp(uint8 x, uint8 y)
		{
			return (uint8)(x + (int)((y - x) * t));
		}
		return .(lerp(a.R, b.R), lerp(a.G, b.G), lerp(a.B, b.B), lerp(a.A, b.A));
	}

	public override void ToString(String buf)
	{
		buf.AppendF("#{:X2}{:X2}{:X2}{:X2}", R, G, B, A);
	}
}
