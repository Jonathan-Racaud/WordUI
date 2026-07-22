using System;

namespace WordUI;

// Hover tracking, keyed by StableKey. On pointer motion it hit-tests the tree
// and, when the hovered widget changes, updates the store and requests a
// repaint (never a rebuild). Because hover is resolved at draw, entering and
// leaving a widget cannot flicker and cannot spike CPU with per-motion rebuilds.
static class HoverTracker
{
	static int sHoveredKey = 0;

	public static void HandleMotion(Widget root, float x, float y)
	{
		let store = App.Instance.Store;
		let hit = HitTest.At(root, x, y);
		let key = hit != null ? hit.StableKey : 0;
		if (key == sHoveredKey)
			return;

		if (sHoveredKey != 0)
			store.SetHover(sHoveredKey, false);
		if (key != 0)
			store.SetHover(key, true);
		sHoveredKey = key;
		App.Instance.RequestRepaint();
	}
}
