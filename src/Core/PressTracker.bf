using System;
using System.Collections;

namespace WordUI;

// Tracks mouse-down to mouse-up sequences and dispatches a Clickable handler
// when the press and release happen on the same widget. Also exposes IsPressed
// for build-time conditional words (IfPressed).
static class PressTracker
{
	static Dictionary<int32, bool> sPressed = new .() ~ delete _;
	static Widget sPressedWidget;   // widget ref for handler dispatch on mouse-up

	// Returns true if the event was consumed (handler fired).
	public static bool HandleEvent(Widget root, InputEvent event)
	{
		if (event.Type == .MouseDown)
		{
			let hit = HitTest.At(root, event.X, event.Y);
			if (hit != null && hit.GetBehavior<OnClickBehavior>()?.Handler != null)
				sPressedWidget = hit;
			else
				sPressedWidget = null;

			if (hit != null)
			{
				sPressed[hit.BuildIndex] = true;
				App.Instance?.Invalidate();
			}
			return false;
		}

		if (event.Type == .MouseUp)
		{
			// Clear press state for the previously pressed widget
			if (sPressedWidget != null)
			{
				sPressed[sPressedWidget.BuildIndex] = false;
				App.Instance?.Invalidate();
			}

			if (sPressedWidget == null)
				return false;

			let released = HitTest.At(root, event.X, event.Y);
			if (released == sPressedWidget)
			{
				let clickable = sPressedWidget.GetBehavior<OnClickBehavior>();
				if (clickable != null && clickable.Handler != null)
				{
					sPressedWidget = null;
					App.Instance?.Invalidate();
					clickable.Handler();
					return true;
				}
			}
			sPressedWidget = null;
			return false;
		}

		return false;
	}

	public static bool IsPressed(int32 buildIndex)
	{
		return sPressed.GetValueOrDefault(buildIndex);
	}
}
