using System;

namespace WordUI;

// Drag capture and delta dispatch. On press over a draggable widget it begins a
// capture on App (keyed by StableKey); while captured, all motion routes to that
// widget's OnDrag handler regardless of what the pointer is over (this is the
// pointer-capture behavior positional interactions need). The visual follows via
// a render-time offset applied in SDLApp.DrawWidget — no relayout, no rebuild.
// Live reflow is a later phase behind the same tracker.
//
// Drag state (key, accumulated offset, last position) lives directly on App
// since it's per-pointer-session, not per-widget.
static class DragTracker
{
	// Returns true if a drag started (so press handling can be skipped).
	public static bool HandleDown(Widget root, float x, float y)
	{
		let hit = HitTest.At(root, x, y);
		let b = hit?.GetBehavior<OnDragBehavior>();
		if (b == null || b.Handler == null)
			return false;

		App.Instance.BeginDrag(hit.StableKey, x, y);
		App.Instance.RequestRepaint();
		return true;
	}

	public static void HandleMotion(Widget root, float x, float y)
	{
		let app = App.Instance;
		if (!app.DragActive)
			return;

		let (dx, dy) = app.UpdateDrag(x, y);
		let w = FindByKey(root, app.DragKey);
		let b = w?.GetBehavior<OnDragBehavior>();
		if (b != null && b.Handler != null)
			b.Handler(dx, dy);
		app.RequestRepaint();
	}

	public static void HandleUp()
	{
		let app = App.Instance;
		if (!app.DragActive)
			return;
		app.EndDrag();
		app.RequestRepaint();
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
