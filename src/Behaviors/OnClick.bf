using System;

namespace WordUI;

public delegate void ClickHandler();

public class OnClickBehavior : Behavior
{
	public ClickHandler Handler;

	public override void Describe(String buf)
	{
		buf.Append(" OnClick");
	}
}

extension UI
{
	// Behavior words attach on demand: OnClick makes any widget clickable,
	// so no Clickable-variant widgets ever need to exist.
	public static void OnClick(ClickHandler h)
	{
		let w = Top("OnClick");
		var b = w.GetBehavior<OnClickBehavior>();
		if (b == null)
		{
			b = new:BuildAlloc OnClickBehavior();
			w.AttachBehavior(b);
		}
		RegisterHandler(h);
		b.Handler = h;
	}
}
