using System;
using System.Collections;

namespace WordUI;

// Wheel/scroll interaction handler. Carries its own ScrollHandler delegate — no
// separate delegate-holder behavior. On MouseWheel, finds the deepest ScrollView-bearing
// widget under the pointer, adjusts its persistent scroll offset in the retained Node
// (clamped to content extent), fires the handler, and requests a repaint — no rebuild.
// The offset is applied at draw by ScrollView.GetRenderOffset.
//
// Does NOT claim capture (returns false from HandleEvent). Wheel events are discrete
// impulses, not a press-drag gesture, so they always route through the hit chain
// regardless of any active capture.
//
// Implements IHasStateSlots so the reconciliation pass preserves the Scroll state
// slot on this widget's Node.
//
// State slot: StateSlots.Scroll (3) — float stored on the retained Node.
public class ScrollHandlerBehavior : Behavior, IInputHandler, IHasStateSlots
{
	public ScrollHandler Handler;   // null = no scroll callback
	const float StepPx = 30f;       // pixels of scroll per wheel notch

	public bool HandleEvent(Widget root, Widget owner, InputEvent event)
	{
		if (event.Type != .MouseWheel)
			return false;

		let hit = FindScrollableAt(root, event.X, event.Y);
		if (hit == null)
			return false;

		let stack = hit.GetComponent<StackLayout>();
		bool vertical = stack == null || stack.Axis == .Vertical;

		let app = App.Instance;

		// Viewport = the container's own inner box (its allocated rect minus
		// padding). Content extent = how far the children reach past the inner
		// origin (they are laid out at natural, unclamped positions and overflow).
		// Layout geometry is read from the retained RenderNode so it works for
		// paint-only frames without re-running layout.
		float pad = hit.Padding;
		let hitNode = app.FindNode(hit.StableKey);
		let hitBounds = hitNode?.RenderNode?.Bounds ?? Rect(0, 0, 0, 0);
		float viewportMain = (vertical ? hitBounds.Height : hitBounds.Width) - 2 * pad;
		float innerOrigin = (vertical ? hitBounds.Y : hitBounds.X) + pad;

		float contentEnd = innerOrigin;
		let children = hit.GetComponent<Children>();
		if (children != null)
		{
			for (let child in children.Items)
			{
				let childNode = app.FindNode(child.StableKey);
				let childBounds = childNode?.RenderNode?.Bounds;
				if (childBounds == null)
					continue;
				let edge = vertical ? childBounds.Value.Bottom : childBounds.Value.Right;
				contentEnd = Math.Max(contentEnd, edge);
			}
		}
		float maxOffset = Math.Max(0, (contentEnd - innerOrigin) - viewportMain);

		let node = app.FindNode(hit.StableKey);
		let current = node != null ? StateSlots.Scroll.Get(node) : 0f;

		// SDL wheel y is positive away from the user; scrolling away reveals
		// earlier content, i.e. a smaller offset.
		float next = Math.Clamp(current - event.WheelY * StepPx, 0, maxOffset);
		if (node != null)
			StateSlots.Scroll.Set(node, next);
		node?.MarkNeedsPaint();

		// Fire the scroll handler on the scrollable widget (hit), not owner.
		let sh = hit.GetBehavior<ScrollHandlerBehavior>();
		if (sh != null && sh.Handler != null)
			sh.Handler(next);

		app.RequestRepaint();
		return false;
	}

	public bool HandleMotion(Widget root, Widget owner, float x, float y)
	{
		return false;
	}

	public void CollectSlots(HashSet<int> slots)
	{
		slots.Add(StateSlots.Scroll.Id);
	}

	public override void Describe(String buf)
	{
		buf.Append(" OnScroll");
	}

	// Deepest widget carrying a ScrollView whose rect contains the point.
	static Widget FindScrollableAt(Widget root, float x, float y)
	{
		return Find(root, x, y, null);
	}

	static Widget Find(Widget w, float x, float y, Widget best)
	{
		if (w == null)
			return best;

		Widget current = best;
		let node = App.Instance.FindNode(w.StableKey);
		let bounds = node?.RenderNode?.Bounds;
		if (bounds != null)
		{
			if (x >= bounds.Value.X && x < bounds.Value.Right &&
				y >= bounds.Value.Y && y < bounds.Value.Bottom &&
				w.GetComponent<ScrollView>() != null)
			{
				current = w;
			}
		}

		let children = w.GetComponent<Children>();
		if (children != null)
		{
			for (let child in children.Items)
				current = Find(child, x, y, current);
		}
		return current;
	}
}
