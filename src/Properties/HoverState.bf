using System;

namespace WordUI;

// Active while the pointer is over the widget at ownerKey. Hover is resolved at
// draw (no rebuild), so entering/leaving repaints without the flicker or CPU
// spike a per-motion rebuild would cause.
public class HoverState : Property, IInteractionState
{
	public int StateId => 2;
	public bool IsActiveFor(int ownerKey) => App.Instance.Store.IsHovered(ownerKey);

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
