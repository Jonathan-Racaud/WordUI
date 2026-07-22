using System;

namespace WordUI;

// Fired with the widget's new (clamped) scroll offset each time a wheel event
// scrolls it. The rounding-out of the event vocabulary next to OnClick/OnDrag:
// a discrete impulse consumer rather than a press/capture gesture.
public delegate void ScrollHandler(float offset);

public class OnScrollBehavior : Behavior
{
	public ScrollHandler Handler;

	public override void Describe(String buf)
	{
		buf.Append(" OnScroll");
	}
}

extension UI
{
	// Makes the stack-top widget react to scroll: ScrollTracker invokes the
	// handler with the new offset after a wheel event adjusts it. Attaches on
	// demand, exactly like OnClick/OnDrag.
	public static void OnScroll(ScrollHandler h)
	{
		let w = Top("OnScroll");
		var b = w.GetBehavior<OnScrollBehavior>();
		if (b == null)
		{
			b = new:BuildAlloc OnScrollBehavior();
			w.AttachBehavior(b);
		}
		RegisterHandler(h);
		b.Handler = h;
	}
}
