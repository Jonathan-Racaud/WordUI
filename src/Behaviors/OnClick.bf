using System;

namespace WordUI;

public delegate void ClickHandler();

extension UI
{
	// Makes the stack-top widget clickable. Attaches a PressHandler which owns
	// the ClickHandler delegate directly — one behavior, no separate holder class.
	public static void OnClick(ClickHandler h)
	{
		let w = Top("OnClick");
		var ph = w.GetBehavior<PressHandler>();
		if (ph == null)
		{
			ph = new:BuildAlloc PressHandler();
			w.AttachBehavior(ph);
		}
		RegisterHandler(h);
		ph.Handler = h;
	}
}
