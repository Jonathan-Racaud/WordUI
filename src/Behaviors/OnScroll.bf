using System;

namespace WordUI;

// Fired with the widget's new (clamped) scroll offset each time a wheel event
// scrolls it.
public delegate void ScrollHandler(float offset);

extension UI
{
	// Makes the stack-top widget react to scroll. Attaches ScrollHandlerBehavior
	// (which owns the ScrollHandler delegate directly — one behavior, no separate
	// holder class). The handler fires with the new clamped offset after each
	// wheel event.
	public static void OnScroll(ScrollHandler h)
	{
		let w = Top("OnScroll");
		var sh = w.GetBehavior<ScrollHandlerBehavior>();
		if (sh == null)
		{
			sh = new:BuildAlloc ScrollHandlerBehavior();
			w.AttachBehavior(sh);
		}
		RegisterHandler(h);
		sh.Handler = h;
	}
}
