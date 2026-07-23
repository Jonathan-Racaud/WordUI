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
// since it's per-pointer-session, not per-widget. DragTracker itself is
// stateless — it just routes events to App.
class DragTracker : ITracker
{
	// HandleEvent: on MouseDown, checks for an OnDragBehavior under the pointer
	// and begins a capture if one exists. Returns true when a drag starts so
	// PressTracker (next in dispatch order) is skipped. On MouseUp, ends the
	// drag and returns false so PressTracker can resolve a click.
	public bool HandleEvent(Widget root, InputEvent event)
	{
		if (event.Type == .MouseDown)
		{
			let hit = HitTest.At(root, event.X, event.Y);
			let b = hit?.GetBehavior<OnDragBehavior>();
			if (b == null || b.Handler == null)
				return false;

			App.Instance.BeginDrag(hit.StableKey, event.X, event.Y);
			App.Instance.RequestRepaint();
			return true;
		}

		if (event.Type == .MouseUp)
		{
			let app = App.Instance;
			if (!app.DragActive)
				return false;
			app.EndDrag();
			app.RequestRepaint();
			return false;
		}

		return false;
	}

	// HandleMotion: while a drag is active, dispatches the incremental delta to
	// the captured widget's OnDrag handler. Returns true to consume the motion
	// and prevent HoverTracker from updating hover state during a drag.
	public bool HandleMotion(Widget root, float x, float y)
	{
		let app = App.Instance;
		if (!app.DragActive)
			return false;

		let (dx, dy) = app.UpdateDrag(x, y);
		let w = FindByKey(root, app.DragKey);
		let b = w?.GetBehavior<OnDragBehavior>();
		if (b != null && b.Handler != null)
			b.Handler(dx, dy);
		app.RequestRepaint();
		return true;
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
