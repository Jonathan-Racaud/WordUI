using System;

namespace WordUI;

// Wheel dispatch. Unlike drag there is no capture: each wheel event is a discrete
// impulse. HandleEvent finds the scrollable under the pointer, adjusts its
// persistent offset in the retained Node (clamped to the content extent), and
// requests a repaint — no rebuild, mirroring the drag/press cheap path. The
// offset is applied at draw time in SDLApp.DrawWidget.
//
// State slot: StateSlots.Scroll (3) — float stored on the retained Node.
class ScrollTracker : ITracker
{
	// Pixels of scroll per wheel notch.
	const float StepPx = 30f;

	public bool HandleEvent(Widget root, InputEvent event)
	{
		if (event.Type != .MouseWheel)
			return false;

		let hit = FindScrollableAt(root, event.X, event.Y);
		if (hit == null)
			return false;

		let stack = hit.GetComponent<StackLayout>();
		bool vertical = stack == null || stack.Axis == .Vertical;

		// Viewport = the container's own inner box (its allocated rect minus
		// padding). Content extent = how far the children reach past the inner
		// origin (they are laid out at natural, unclamped positions and overflow).
		float pad = hit.Padding;
		float viewportMain = (vertical ? hit.mRect.Height : hit.mRect.Width) - 2 * pad;
		float innerOrigin = (vertical ? hit.mRect.Y : hit.mRect.X) + pad;

		float contentEnd = innerOrigin;
		let children = hit.GetComponent<Children>();
		if (children != null)
		{
			for (let child in children.Items)
			{
				let edge = vertical ? child.mRect.Bottom : child.mRect.Right;
				contentEnd = Math.Max(contentEnd, edge);
			}
		}
		float maxOffset = Math.Max(0, (contentEnd - innerOrigin) - viewportMain);

		let app = App.Instance;
		let node = app.FindNode(hit.StableKey);
		let current = node != null ? StateSlots.Scroll.Get(node) : 0f;

		// SDL wheel y is positive away from the user; scrolling away reveals
		// earlier content, i.e. a smaller offset.
		float next = Math.Clamp(current - event.WheelY * StepPx, 0, maxOffset);
		if (node != null)
			StateSlots.Scroll.Set(node, next);

		let b = hit.GetBehavior<OnScrollBehavior>();
		if (b != null && b.Handler != null)
			b.Handler(next);

		app.RequestRepaint();
		return false;
	}

	public bool HandleMotion(Widget root, float x, float y)
	{
		return false;
	}

	// Deepest widget carrying a ScrollView whose rect contains the point. Because
	// a scroll container's rect encloses its viewport (and therefore the pointer),
	// a wheel over a child resolves to the enclosing scrollable — bubbling without
	// a parent pointer.
	static Widget FindScrollableAt(Widget root, float x, float y)
	{
		return Find(root, x, y, null);
	}

	static Widget Find(Widget w, float x, float y, Widget best)
	{
		if (w == null)
			return best;

		Widget current = best;
		if (x >= w.mRect.X && x < w.mRect.Right &&
			y >= w.mRect.Y && y < w.mRect.Bottom &&
			w.GetComponent<ScrollView>() != null)
		{
			current = w;
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
