using System;
using System.Collections;

namespace WordUI;

// Focus management. On MouseDown over a widget carrying this handler, sets that
// widget as the focused target: writes StateSlots.Focus to the gaining node,
// clears it on the previously-focused node, marks both paint-dirty, and requests
// a repaint. Does NOT claim capture — focus is orthogonal to drag/press.
//
// The focused key is tracked on App so the InputDispatcher can route keyboard
// events to the focused widget's behaviors.
//
// Implements IHasStateSlots so the reconciliation pass preserves the Focus state
// slot on this widget's Node.
//
// State slot: StateSlots.Focus (5) — bool written to the retained Node.
public class FocusHandler : Behavior, IInputHandler, IHasStateSlots
{
	public bool HandleEvent(Widget root, Widget owner, InputEvent event)
	{
		if (event.Type != .MouseDown)
			return false;

		let app = App.Instance;
		let newKey = owner.StableKey;
		let oldKey = app.FocusedKey;
		if (newKey == oldKey)
			return false;

		// Clear previous focus.
		if (oldKey != 0)
		{
			let prev = app.FindNode(oldKey);
			StateSlots.Focus.Set(prev, false);
			prev?.MarkNeedsPaint();
		}

		// Set new focus.
		let node = app.FindNode(newKey);
		StateSlots.Focus.Set(node, true);
		node?.MarkNeedsPaint();

		app.FocusedKey = newKey;
		app.RequestRepaint();
		return false;
	}

	public bool HandleMotion(Widget root, Widget owner, float x, float y)
	{
		return false;
	}

	public void CollectSlots(HashSet<int> slots)
	{
		slots.Add(StateSlots.Focus.Id);
	}

	public override void Describe(String buf)
	{
		buf.Append(" FocusHandler");
	}
}
