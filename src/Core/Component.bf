using System;

namespace WordUI;

// The single inheritance point of the framework. A component carries one
// capability's data and overrides framework hooks for its behavior. Framework
// components and user components are peers: every pass dispatches through the
// same virtual hooks, so a user's component participates in diagnostics,
// layout, and rendering without any registration step.
public abstract class Component
{
	// Contributes this component's detail to the tree dump. Append nothing to
	// stay silent (e.g. when all fields hold default values).
	public virtual void Describe(String buf) {}

	// Intrinsic sizing for the layout pass. The constraint is the available
	// space in the cross axis (unbounded in the main axis). Default: zero.
	public virtual Size Measure(Size constraint)
	{
		return .(0, 0);
	}

	// ---- Render pipeline hooks (called in fixed z-order by DrawWidget) ----

	// Optional render-time offset contributed by this component. The draw loop
	// accumulates offsets from all components on a widget and applies them to
	// the child rendering origin — same mechanism drag and scroll both use.
	// Default: (0, 0).
	public virtual (float ox, float oy) GetRenderOffset(Widget w, Node node)
	{
		return (0, 0);
	}

	// Fills behind content and children. Default: no-op.
	public virtual void DrawBackground(IPainter painter, Widget widget, Rect bounds)
	{
	}

	// Draws the widget's own content (text, custom shapes). Default: no-op.
	public virtual void DrawContent(IPainter painter, Widget widget, Rect bounds)
	{
	}

	// Strokes on top of content and children. Default: no-op.
	public virtual void DrawOverlay(IPainter painter, Widget widget, Rect bounds)
	{
	}
}
