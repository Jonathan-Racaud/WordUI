using System;

namespace WordUI;

extension UI
{
	// Behavior words attach their component on demand: OnClick makes any
	// widget clickable, so no Clickable-variant widgets ever need to exist.
	public static void OnClick(ClickHandler h)
	{
		let w = Top("OnClick");
		var c = w.Get<Clickable>();
		if (c == null)
		{
			c = new:BuildAlloc Clickable();
			w.Attach(c);
		}
		RegisterHandler(h);
		c.Handler = h;
	}
}
