using System;
using System.Collections;

namespace PFUI;

public delegate void ClickHandler();

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

public enum WidgetKind
{
	Label,
	Image,
	Button,
	HStack,
	VStack,
	Spacer
}

public class Widget
{
	public WidgetKind Kind;
	public List<Widget> Children;   // containers only; allocated in the build arena
	public String Text;             // label text / image name / button text; arena copy
	public float FontSize = 12;
	public Color TextColor = .Black;
	public float Padding;
	public float Spacing;
	public ClickHandler OnClick;
	public int Key = -1;

	public this(WidgetKind kind)
	{
		Kind = kind;
	}
}

// The build stack holds three kinds of items; every pop validates the tag so a
// misused word fails with a named error instead of building a scrambled tree.
public enum StackItem
{
	case Text(String);
	case Elem(Widget);
	case Mark(WidgetKind);

	public void ToString(String buf)
	{
		switch (this)
		{
		case .Text(let s): buf.AppendF("Str(\"{}\")", s);
		case .Elem(let w): buf.AppendF("Widget({})", UI.KindName(w.Kind));
		case .Mark(let k): buf.AppendF("Marker({})", UI.KindName(k));
		}
	}
}
