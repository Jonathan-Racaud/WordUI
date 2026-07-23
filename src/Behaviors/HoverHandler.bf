using System;
using System.Collections;

namespace WordUI;

// Hover tracking, keyed by StableKey in the retained Node tree. On pointer motion
// (when not captured), manages enter/leave on the hovered widget: clears hover on
// the previous widget's Node, sets it on the new one, marks both paint-dirty, and
// requests a repaint — never a rebuild. Because hover is resolved at draw, entering
// and leaving cannot flicker.
//
// Implements IHasStateSlots so the reconciliation pass preserves the Hover state
// slot on this widget's Node.
//
// State slot: StateSlots.Hover (1) — bool written to the retained Node.
public class HoverHandler : Behavior, IInputHandler, IHasStateSlots
{
	int mHoveredKey = 0;

	public bool HandleEvent(Widget root, Widget owner, InputEvent event)
	{
		return false;
	}

	public bool HandleMotion(Widget root, Widget owner, float x, float y)
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

	// IHasStateSlots: declare the state slot this behavior writes to.
	public void CollectSlots(HashSet<int> slots)
	{
		slots.Add(StateSlots.Hover.Id);
	}

	public override void Describe(String buf)
	{
		buf.Append(" HoverHandler");
	}
}
