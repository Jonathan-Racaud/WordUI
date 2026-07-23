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
// State slot: StateSlots.Press (2) — bool written to the retained Node.
class PressTracker : ITracker
{
	int mPressedKey = 0;   // 0 = nothing pressed
	bool mPressedClickable;

	public bool HandleEvent(Widget root, InputEvent event)
	{
		let app = App.Instance;

		if (event.Type == .MouseDown)
		{
			let hit = HitTest.At(root, event.X, event.Y);
			if (hit == null)
			{
				mPressedKey = 0;
				return false;
			}
			mPressedKey = hit.StableKey;
			mPressedClickable = hit.GetBehavior<OnClickBehavior>()?.Handler != null;
			let node = app.FindNode(mPressedKey);
			StateSlots.Press.Set(node, true);
			app.RequestRepaint();
			return false;
		}

		if (event.Type == .MouseUp)
		{
			if (mPressedKey == 0)
				return false;

			let pressedNode = app.FindNode(mPressedKey);
			StateSlots.Press.Set(pressedNode, false);
			app.RequestRepaint();

			let released = HitTest.At(root, event.X, event.Y);
			bool fired = false;
			if (mPressedClickable && released != null && released.StableKey == mPressedKey)
			{
				let clickable = released.GetBehavior<OnClickBehavior>();
				if (clickable != null && clickable.Handler != null)
				{
					clickable.Handler();   // may Invalidate() for app-data changes
					fired = true;
				}
			}
			mPressedKey = 0;
			return fired;
		}

		return false;
	}

	public bool HandleMotion(Widget root, float x, float y)
	{
		return false;
	}
}
