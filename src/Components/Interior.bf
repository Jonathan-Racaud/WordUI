using System;

namespace PFUI;

// Fills the widget's bounds with a solid color and an optional corner radius.
// Attached by the Background() focusing word; drawn in the DrawBackground pass
// (beneath content and children).
public class Interior : Component
{
	public Color FillColor = .(0, 0, 0, 0);
	public float Radius;   // 0 = rectangular; rounded rect drawn when > 0

	public override void Describe(String buf)
	{
		buf.Append(scope $" Fill={FillColor}");
		if (Radius > 0)
			buf.Append(scope $" Radius={Radius}");
	}

	public override void DrawBackground(Painter painter, Widget widget, Rect bounds)
	{
		if (FillColor.A == 0)
			return;
		if (Radius > 0)
			painter.FillRoundRect(bounds, Radius, FillColor);
		else
			painter.FillRect(bounds, FillColor);
	}
}
