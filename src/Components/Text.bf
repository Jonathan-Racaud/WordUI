using System;

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
		let painter = App.Instance != null ? App.Instance.Painter : null;
		if (painter == null || Content == null)
			return .(0, 0);
		return painter.MeasureText(Content);
	}

	public override void DrawContent(IPainter painter, Widget widget, Rect bounds)
	{
		if (Content == null)
			return;

		var ts = widget.GetProperty<TextStyleProperty>();
		Color baseColor = ts != null ? ts.TextColor : .Black;
		Color color = StyleResolve.Color(widget, baseColor, .TextColor);
		painter.DrawText(Content, bounds.X, bounds.Y, color);
	}
}
