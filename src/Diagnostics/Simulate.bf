using System;

namespace PFUI;

// Stands in for hit-testing until a real renderer exists. Generic over
// capabilities: any widget with a Clickable whose TextStyle text matches.
extension App
{
	public bool SimulateClick(StringView text)
	{
		return ClickIn(mRoot, text);
	}

	static bool ClickIn(Widget w, StringView text)
	{
		if (w == null)
			return false;

		let clickable = w.Get<Clickable>();
		let style = w.Get<TextStyle>();
		if (clickable != null && clickable.Handler != null && style != null && style.Text == text)
		{
			clickable.Handler();
			return true;
		}

		let kids = w.Get<Children>();
		if (kids != null)
		{
			for (let child in kids.Items)
			{
				if (ClickIn(child, text))
					return true;
			}
		}
		return false;
	}
}
