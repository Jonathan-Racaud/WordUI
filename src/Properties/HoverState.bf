using System;

namespace WordUI;

// Active while the pointer is over the widget at ownerKey. Hover is resolved at
// draw (no rebuild), so entering/leaving repaints without the flicker or CPU
// spike a per-motion rebuild would cause.
// Queries the retained Node for StateSlots.Hover (slot 1) via App.FindNode.
public class HoverState : Property, IInteractionState
{
	public int StateId => 2;
	public bool IsActiveFor(int ownerKey)
	{
		let node = App.Instance.FindNode(ownerKey);
		return node != null && StateSlots.Hover.Get(node);
	}

	public override void Describe(String buf)
	{
		buf.Append(" hover");
	}
}

extension UI
{
	// Convenience: records the enclosed styling while the widget is hovered.
	public static void IfHover(delegate void() body) => IfActive<HoverState>(body);
}
