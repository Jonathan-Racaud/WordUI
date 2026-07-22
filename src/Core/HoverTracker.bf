using System;

namespace WordUI;

// Hover tracking, keyed by StableKey. On pointer motion it hit-tests the tree
// and, when the hovered widget changes, updates the retained Node state and
// requests a repaint (never a rebuild). Because hover is resolved at draw,
// entering and leaving a widget cannot flicker and cannot spike CPU with
// per-motion rebuilds.
//
// Slot 1: hover bool — set on the retained Node for the hovered widget.
static class HoverTracker
{
	public const int SlotHover = 1;

	static int sHoveredKey = 0;

	public static void HandleMotion(Widget root, float x, float y)
	{
		let app = App.Instance;
		let hit = HitTest.At(root, x, y);
		let key = hit != null ? hit.StableKey : 0;
		if (key == sHoveredKey)
			return;

		// Clear previous hover.
		if (sHoveredKey != 0)
		{
			let prev = app.FindNode(sHoveredKey);
			prev?.SetBool(SlotHover, false);
		}

		// Set new hover.
		if (key != 0)
		{
			let node = app.FindNode(key);
			node?.SetBool(SlotHover, true);
		}

		sHoveredKey = key;
		app.RequestRepaint();
	}
}
