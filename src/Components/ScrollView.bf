using System;

namespace WordUI;

// Marker component: a widget carrying a ScrollView offsets its children along its
// StackLayout axis by a persistent scroll offset stored in the retained Node
// (keyed by StableKey, so it survives rebuilds — the M4 exit criterion). The
// offset is returned via GetRenderOffset, which the draw loop accumulates into
// the child rendering origin — same mechanism as drag, zero hardcoded knowledge
// in the draw pipeline.
//
// A pure marker: it stores nothing itself. The scroll offset lives in the retained
// Node; the content extent used to clamp it is derived from child rects at wheel
// time by ScrollHandlerBehavior.
public class ScrollView : Component
{
	public override (float ox, float oy) GetRenderOffset(Widget w, Node node)
	{
		if (node == null)
			return (0, 0);
		let off = StateSlots.Scroll.Get(node);
		let stack = w.GetComponent<StackLayout>();
		if (stack == null || stack.Axis == .Vertical)
			return (0, -off);
		else
			return (-off, 0);
	}

	public override void Describe(String buf)
	{
		buf.Append(" Scroll");
	}
}
