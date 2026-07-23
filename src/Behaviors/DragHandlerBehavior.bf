using System;
using System.Collections;

namespace WordUI;

// 2D offset stored as a single value type in the retained Node's state dictionary.
// Used by DragHandlerBehavior to accumulate pointer delta during a drag capture.
// Stored via StateSlot<DragOffset> — zero per-frame allocation after the initial set.
public struct DragOffset
{
	public float X;
	public float Y;
}

// Drag capture and delta dispatch. Carries its own DragHandler delegate — no separate
// delegate-holder behavior. On press, returns true from HandleEvent to claim capture
// (only when Handler != null). While captured, all motion routes here regardless of
// pointer position — computes the incremental delta, accumulates it into
// StateSlots.DragOffset on the retained Node, fires the handler, and marks the node
// paint-dirty. On release, clears the offset.
//
// The visual offset is applied at draw by RenderDragOffset (a Component), which
// reads StateSlots.DragOffset from the retained Node — same mechanism as ScrollView.
//
// Implements IHasStateSlots so the reconciliation pass preserves the DragOffset
// state slot on this widget's Node.
//
// State slot: StateSlots.DragOffset (4) — DragOffset stored on the retained Node.
public class DragHandlerBehavior : Behavior, IInputHandler, IHasStateSlots
{
	public DragHandler Handler;   // null = not draggable

	public bool HandleEvent(Widget root, Widget owner, InputEvent event)
	{
		if (event.Type == .MouseDown)
		{
			if (Handler == null)
				return false;

			// Claim capture — InputDispatcher will route subsequent events here.
			let node = App.Instance.FindNode(owner.StableKey);
			node?.MarkNeedsPaint();
			App.Instance.RequestRepaint();
			return true;
		}

		if (event.Type == .MouseUp)
		{
			// Clear accumulated offset.
			let node = App.Instance.FindNode(owner.StableKey);
			StateSlots.DragOffset.Set(node, .() { X = 0, Y = 0 });
			node?.MarkNeedsPaint();
			App.Instance.RequestRepaint();
			return false;
		}

		return false;
	}

	public bool HandleMotion(Widget root, Widget owner, float x, float y)
	{
		let app = App.Instance;
		if (!app.CaptureActive || app.CaptureKey != owner.StableKey)
			return false;

		let (dx, dy) = app.CaptureUpdate(x, y);

		// Accumulate offset into retained Node state.
		let node = app.FindNode(owner.StableKey);
		var off = StateSlots.DragOffset.Get(node);
		off.X += dx;
		off.Y += dy;
		StateSlots.DragOffset.Set(node, off);

		// Fire the drag handler.
		if (Handler != null)
			Handler(dx, dy);

		node?.MarkNeedsPaint();
		app.RequestRepaint();
		return true; // consume motion — suppress hover during drag
	}

	public void CollectSlots(HashSet<int> slots)
	{
		slots.Add(StateSlots.DragOffset.Id);
	}

	public override void Describe(String buf)
	{
		buf.Append(" OnDrag");
	}
}

// Arena-allocated component that contributes the accumulated drag offset at draw
// time. SDLApp.DrawWidget calls GetRenderOffset on every component and accumulates
// the result — this is how drag visual offset reaches the renderer without
// hardcoded drag knowledge in the draw loop.
public class RenderDragOffset : Component
{
	public override (float ox, float oy) GetRenderOffset(Widget w, Node node)
	{
		if (node == null)
			return (0, 0);
		var off = StateSlots.DragOffset.Get(node);
		return (off.X, off.Y);
	}

	public override void Describe(String buf)
	{
		buf.Append(" RenderDragOffset");
	}
}
