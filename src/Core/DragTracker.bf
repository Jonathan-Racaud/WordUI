using System;

namespace WordUI;

// Drag capture and delta dispatch. On press over a draggable widget it begins a
// capture in the InteractionStore keyed by StableKey; while captured, all motion
// routes to that widget's OnDrag handler regardless of what the pointer is over
// (this is the pointer-capture behavior positional interactions need). The
// visual follows via a render-time offset applied in SDLApp.DrawWidget — no
// relayout, no rebuild. Live reflow is a later phase behind the same tracker.
static class DragTracker
{
	// Returns true if a drag started (so press handling can be skipped).
	public static bool HandleDown(Widget root, float x, float y)
	{
		let hit = HitTest.At(root, x, y);
		let b = hit?.GetBehavior<OnDragBehavior>();
		if (b == null || b.Handler == null)
			return false;

		App.Instance.Store.BeginDrag(hit.StableKey, x, y);
		App.Instance.RequestRepaint();
		return true;
	}

	public static void HandleMotion(Widget root, float x, float y)
	{
		let store = App.Instance.Store;
		if (!store.DragActive)
			return;

		let (dx, dy) = store.UpdateDrag(x, y);
		let w = FindByKey(root, store.DragKey);
		let b = w?.GetBehavior<OnDragBehavior>();
		if (b != null && b.Handler != null)
			b.Handler(dx, dy);
		App.Instance.RequestRepaint();
	}

	public static void HandleUp()
	{
		let store = App.Instance.Store;
		if (!store.DragActive)
			return;
		store.EndDrag();
		App.Instance.RequestRepaint();
	}

	static Widget FindByKey(Widget w, int key)
	{
		if (w == null)
			return null;
		if (w.StableKey == key)
			return w;
		let children = w.GetComponent<Children>();
		if (children != null)
		{
			for (let child in children.Items)
			{
				let found = FindByKey(child, key);
				if (found != null)
					return found;
			}
		}
		return null;
	}
}
