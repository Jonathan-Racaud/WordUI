using System;

namespace WordUI;

// Hover tracking, keyed by StableKey. On pointer motion it hit-tests the tree
// and, when the hovered widget changes, updates the retained Node state and
// requests a repaint (never a rebuild). Because hover is resolved at draw,
// entering and leaving a widget cannot flicker and cannot spike CPU with
// per-motion rebuilds.
//
// State slot: StateSlots.Hover (1) — bool written to the retained Node.
class HoverTracker : ITracker
{
	int mHoveredKey = 0;

	public bool HandleMotion(Widget root, float x, float y)
	{
		let app = App.Instance;
		let hit = HitTest.At(root, x, y);
		let key = hit != null ? hit.StableKey : 0;
		if (key == mHoveredKey)
			return false;

		// Clear previous hover.
		if (mHoveredKey != 0)
		{
			let prev = app.FindNode(mHoveredKey);
			StateSlots.Hover.Set(prev, false);
			prev?.MarkNeedsPaint();
		}

		// Set new hover.
		if (key != 0)
		{
			let node = app.FindNode(key);
			StateSlots.Hover.Set(node, true);
			node?.MarkNeedsPaint();
		}

		mHoveredKey = key;
		app.RequestRepaint();
		return false;
	}

	public bool HandleEvent(Widget root, InputEvent event)
	{
		return false;
	}
}
