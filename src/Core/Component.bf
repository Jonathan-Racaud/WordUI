using System;

namespace PFUI;

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

	// Fills behind content and children. Default: no-op.
	public virtual void DrawBackground(Painter painter, Widget widget, Rect bounds)
	{
	}

	// Draws the widget's own content (text, custom shapes). Default: no-op.
	public virtual void DrawContent(Painter painter, Widget widget, Rect bounds)
	{
	}

	// Strokes on top of content and children. Default: no-op.
	public virtual void DrawOverlay(Painter painter, Widget widget, Rect bounds)
	{
	}
}
