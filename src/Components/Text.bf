using System;
using SDL3_ttf;

namespace WordUI;

// A widget's text content: the string to render, plus the Measure and
// DrawContent pipeline hooks. Styling (font size, color) is read from the
// widget's TextStyleProperty; sensible defaults apply when it is absent.
public class TextComponent : Component
{
	public String Content;

	public override void Describe(String buf)
	{
		buf.Append(scope $" Text=\"{Content}\"");
	}

	public override Size Measure(Size constraint)
	{
		let font = SDLApp.sDefaultFont;
		if (font == null || Content == null)
			return .(0, 0);

		let cStr = Content.CStr();
		int32 w = 0, h = 0;
		TTF_GetStringSize(font, cStr, 0, &w, &h);
		return .((float)w, (float)h);
	}

	public override void DrawContent(Painter painter, Widget widget, Rect bounds)
	{
		if (Content == null)
			return;

		var ts = widget.GetProperty<TextStyleProperty>();
		Color color = ts != null ? ts.TextColor : .Black;
		painter.DrawText(Content, bounds.X, bounds.Y, color);
	}
}
