using System;

namespace PFUI;

// Strokes the widget's bounds with a solid color, width, and optional corner
// radius. Attached by the Border() focusing word; drawn in the DrawOverlay
// pass (on top of content and children).
public class Boundary : Component
{
	public Color StrokeColor = .(0, 0, 0, 0);
	public float Width = 1;
	public float Radius;   // 0 = rectangular; rounded rect drawn when > 0

	public override void Describe(String buf)
	{
		buf.Append(scope $" Stroke={StrokeColor} Width={Width}");
		if (Radius > 0)
			buf.Append(scope $" Radius={Radius}");
	}

	public override void DrawOverlay(Painter painter, Widget widget, Rect bounds)
	{
		if (StrokeColor.A == 0 || Width <= 0)
			return;
		if (Radius > 0)
			painter.DrawRoundRect(bounds, Radius, Width, StrokeColor);
		else
			painter.DrawRect(bounds, StrokeColor);
	}
}
