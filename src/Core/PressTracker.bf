using System;

namespace WordUI;

// Press/click dispatch, keyed by StableKey in the retained Node tree.
// Storing a key (not a Widget*) is what fixes the missed/delayed clicks: the
// key stays valid across the arena teardown a rebuild performs, so a down in
// one frame and an up several frames (and rebuilds) later still match.
//
// Press no longer triggers a rebuild — it sets Node state and requests a
// repaint, so IfPressed feedback resolves at draw with no tree teardown.
//
// Slot 2: press bool — set on the retained Node for the pressed widget.
static class PressTracker
{
	public const int SlotPress = 2;

	static int sPressedKey = 0;   // 0 = nothing pressed
	static bool sPressedClickable;

	public static bool HandleEvent(Widget root, InputEvent event)
	{
		let app = App.Instance;

		if (event.Type == .MouseDown)
		{
			let hit = HitTest.At(root, event.X, event.Y);
			if (hit == null)
			{
				sPressedKey = 0;
				return false;
			}
			sPressedKey = hit.StableKey;
			sPressedClickable = hit.GetBehavior<OnClickBehavior>()?.Handler != null;
			let node = app.FindNode(sPressedKey);
			node?.SetBool(SlotPress, true);
			app.RequestRepaint();
			return false;
		}

		if (event.Type == .MouseUp)
		{
			if (sPressedKey == 0)
				return false;

			let pressedNode = app.FindNode(sPressedKey);
			pressedNode?.SetBool(SlotPress, false);
			app.RequestRepaint();

			let released = HitTest.At(root, event.X, event.Y);
			bool fired = false;
			if (sPressedClickable && released != null && released.StableKey == sPressedKey)
			{
				let clickable = released.GetBehavior<OnClickBehavior>();
				if (clickable != null && clickable.Handler != null)
				{
					clickable.Handler();   // may Invalidate() for app-data changes
					fired = true;
				}
			}
			sPressedKey = 0;
			return fired;
		}

		return false;
	}
}
