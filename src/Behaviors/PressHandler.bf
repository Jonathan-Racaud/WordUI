using System;
using System.Collections;

namespace WordUI;

// Press/click interaction handler. On MouseDown over its widget, writes StateSlots.Press
// to the retained Node and requests a repaint (not a rebuild — IfPressed resolves
// at draw). On MouseUp, clears press state and fires the click handler if the
// release is over the same widget.
//
// Carries its own ClickHandler delegate — no separate delegate-holder behavior needed.
// The OnClick word attaches this single behavior; the Handler field doubles as the
// signal that the widget is clickable.
//
// Implements IHasStateSlots so the reconciliation pass preserves the Press state
// slot on this widget's Node.
//
// State slot: StateSlots.Press (2) — bool written to the retained Node.
public class PressHandler : Behavior, IInputHandler, IHasStateSlots
{
	public ClickHandler Handler;   // null = not clickable
	int mPressedKey = 0;           // 0 = nothing pressed

	public bool HandleEvent(Widget root, Widget owner, InputEvent event)
	{
		let app = App.Instance;

		if (event.Type == .MouseDown)
		{
			mPressedKey = owner.StableKey;
			let node = app.FindNode(mPressedKey);
			StateSlots.Press.Set(node, true);
			node?.MarkNeedsPaint();
			app.RequestRepaint();
			return false; // don't claim capture — DragHandlerBehavior handles that
		}

		if (event.Type == .MouseUp)
		{
			if (mPressedKey == 0)
				return false;

			let pressedNode = app.FindNode(mPressedKey);
			StateSlots.Press.Set(pressedNode, false);
			pressedNode?.MarkNeedsPaint();
			app.RequestRepaint();

			// Hit-test at release position to check if it's on the same widget.
			let released = HitTest.At(root, event.X, event.Y);
			if (Handler != null && released != null && released.StableKey == mPressedKey)
			{
				Handler();   // may Invalidate() for app-data changes
			}
			mPressedKey = 0;
			return false;
		}

		return false;
	}

	public bool HandleMotion(Widget root, Widget owner, float x, float y)
	{
		return false;
	}

	public void CollectSlots(HashSet<int> slots)
	{
		slots.Add(StateSlots.Press.Id);
	}

	public override void Describe(String buf)
	{
		buf.Append(" OnClick");
	}
}
