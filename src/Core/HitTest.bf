using System;

namespace PFUI;

// Shared hit-test utility: given a point in window coordinates, walks the
// widget tree and returns the leaf-most widget whose mRect contains the
// point. Returns null if no widget is hit.
static class HitTest
{
	public static Widget At(Widget root, float x, float y)
	{
		return Find(root, x, y, null);
	}

	static Widget Find(Widget w, float x, float y, Widget best)
	{
		if (w == null)
			return best;

		Widget current = best;
		if (x >= w.mRect.X && x < w.mRect.Right &&
			y >= w.mRect.Y && y < w.mRect.Bottom)
		{
			current = w;
		}

		let children = w.Get<Children>();
		if (children != null)
		{
			for (let child in children.Items)
			{
				current = Find(child, x, y, current);
			}
		}
		return current;
	}
}
