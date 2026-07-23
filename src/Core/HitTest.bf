using System;

namespace WordUI;

// Shared hit-test utility: given a point in window coordinates, walks the
// widget tree and returns the leaf-most widget whose retained RenderNode
// bounds contain the point. Returns null if no widget is hit.
// Layout geometry is read from the retained Node.RenderNode so it works
// correctly for both full-rebuild and paint-only frames.
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
		let node = App.Instance.FindNode(w.StableKey);
		let bounds = node?.RenderNode?.Bounds;
		if (bounds != null)
		{
			if (x >= bounds.Value.X && x < bounds.Value.Right &&
				y >= bounds.Value.Y && y < bounds.Value.Bottom)
			{
				current = w;
			}
		}

		let children = w.GetComponent<Children>();
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
