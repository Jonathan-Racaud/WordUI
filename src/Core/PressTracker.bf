using System;

namespace PFUI;

// Tracks mouse-down to mouse-up sequences and dispatches a Clickable handler
// when the press and release happen on the same widget.
static class PressTracker
{
	static Widget sPressedWidget;

	// Returns true if the event was consumed (handler fired).
	public static bool HandleEvent(Widget root, InputEvent event)
	{
		if (event.Type == .MouseDown)
		{
			let hit = HitTest.At(root, event.X, event.Y);
			if (hit != null && hit.Get<Clickable>()?.Handler != null)
				sPressedWidget = hit;
			else
				sPressedWidget = null;
			return false;
		}

		if (event.Type == .MouseUp)
		{
			if (sPressedWidget == null)
				return false;

			let released = HitTest.At(root, event.X, event.Y);
			if (released == sPressedWidget)
			{
				let clickable = sPressedWidget.Get<Clickable>();
				if (clickable != null && clickable.Handler != null)
				{
					sPressedWidget = null;
					clickable.Handler();
					return true;
				}
			}
			sPressedWidget = null;
			return false;
		}

		return false;
	}
}
