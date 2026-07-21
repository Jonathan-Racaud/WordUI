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

	public override void ToString(String buf)
	{
		buf.AppendF("#{:X2}{:X2}{:X2}{:X2}", R, G, B, A);
	}
}
