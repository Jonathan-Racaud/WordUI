using System;
using SDL3_ttf;

namespace PFUI;

public class TextStyle : Component
{
	public String Text;
	public float FontSize = 12;
	public Color TextColor = .Black;

	public override void Describe(String buf)
	{
		buf.Append(scope $" Text=\"{Text}\"");
		buf.Append(scope $" FontSize={FontSize}");
		buf.Append(scope $" Color={TextColor}");
	}

	public override Size Measure(Size constraint)
	{
		let font = SDLApp.sDefaultFont;
		if (font == null || Text == null)
			return .(0, 0);

		let cStr = Text.CStr();
		int32 w = 0, h = 0;
		TTF_GetStringSize(font, cStr, 0, &w, &h);
		return .((float)w, (float)h);
	}

	public override void Draw(Painter painter, Rect bounds)
	{
		if (Text == null)
			return;
		painter.DrawText(Text, bounds.X, bounds.Y, TextColor);
	}
}
