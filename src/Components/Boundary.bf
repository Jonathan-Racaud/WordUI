using System;

namespace WordUI;

// Strokes the widget's bounds with a solid color, width, and optional corner
// radius. Attached by the Border() focusing word; drawn in the DrawOverlay
// pass (on top of content and children).
public class Boundary : Component
{
	public Color StrokeColor = .(0, 0, 0, 0);
	public float StrokeWidth = 1;
	public float Radius;   // 0 = rectangular; rounded rect drawn when > 0

	public override void Describe(String buf)
	{
		buf.Append(scope $" Stroke={StrokeColor} StrokeWidth={StrokeWidth}");
		if (Radius > 0)
			buf.Append(scope $" Radius={Radius}");
	}

	public override void DrawOverlay(IPainter painter, Widget widget, Rect bounds)
	{
		let stroke = StyleResolve.Color(widget, StrokeColor, .Stroke);
		let width = StyleResolve.Float(widget, StrokeWidth, .StrokeWidth);
		if (stroke.A == 0 || width <= 0)
			return;
		if (Radius > 0)
			painter.DrawRoundRect(bounds, Radius, width, stroke);
		else
			painter.DrawRect(bounds, stroke);
	}
}
