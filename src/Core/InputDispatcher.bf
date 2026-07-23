using System;
using System.Collections;

namespace WordUI;

// Single ITracker replacing the four monolithic trackers (HoverTracker, PressTracker,
// DragTracker, ScrollTracker). Hit-tests to find the target widget, then offers the
// event to every IInputHandler behavior on that widget (and its ancestors, walking
// leaf→root). The first handler returning true from HandleEvent on MouseDown claims
// the pointer capture; subsequent events route exclusively to that widget's behaviors
// until MouseUp releases it.
//
// Wheel events always route through the hit chain regardless of capture (they're
// discrete impulses, not part of a press-drag gesture). Key events route to the
// focused widget (App.FocusedKey).
//
// User-authored interaction types need only implement IInputHandler on a Behavior
// and attach it to a widget — no tracker registration, no framework modification.
class InputDispatcher : ITracker
{
	int mHoveredKey = 0;   // 0 = nothing hovered (for built-in hover tracking)

	public bool HandleEvent(Widget root, InputEvent event)
	{
		let app = App.Instance;

		// ---- Key events: route to focused widget ----
		if (event.Type == .KeyDown)
		{
			if (app.FocusedKey != 0)
			{
				let w = FindByKey(root, app.FocusedKey);
				if (w != null)
				{
					for (let b in w.Behaviors)
					{
						let h = b as IInputHandler;
						if (h != null && h.HandleEvent(root, w, event))
							return true;
					}
				}
			}
			return false;
		}

		// ---- Wheel events: always hit chain, never captured ----
		if (event.Type == .MouseWheel)
		{
			return DispatchToChain(root, event.X, event.Y, event);
		}

		// ---- MouseDown: hit chain; first true return claims capture ----
		if (event.Type == .MouseDown)
		{
			let consumed = DispatchToChain(root, event.X, event.Y, event);
			// The handler that consumed the event is on the hit widget; the
			// InputDispatcher records the capture key. The handler itself doesn't
			// need to know about capture — it just returns true.
			if (consumed)
			{
				let hit = HitTest.At(root, event.X, event.Y);
				if (hit != null)
					app.CaptureBegin(hit.StableKey, event.X, event.Y);
			}
			return consumed;
		}

		// ---- MouseUp: release capture, then dispatch ----
		if (event.Type == .MouseUp)
		{
			if (app.CaptureActive)
			{
				let capKey = app.CaptureKey;
				app.CaptureEnd();
				let w = FindByKey(root, capKey);
				if (w != null)
				{
					for (let b in w.Behaviors)
					{
						let h = b as IInputHandler;
						if (h != null)
							h.HandleEvent(root, w, event);
					}
				}
				return false;
			}
			return DispatchToChain(root, event.X, event.Y, event);
		}

		return false;
	}

	public bool HandleMotion(Widget root, float x, float y)
	{
		let app = App.Instance;

		// ---- Captured: route motion exclusively to capture target ----
		if (app.CaptureActive)
		{
			let w = FindByKey(root, app.CaptureKey);
			if (w != null)
			{
				for (let b in w.Behaviors)
				{
					let h = b as IInputHandler;
					if (h != null && h.HandleMotion(root, w, x, y))
						return true;
				}
			}
			return true; // capture always consumes motion (suppresses hover walk)
		}

		// ---- No capture: built-in hover tracking + chain dispatch ----
		// Hover enter/leave is fundamental enough that the dispatcher handles it
		// directly, writing StateSlots.Hover on the retained Node tree. Per-widget
		// HoverHandler behaviors (if attached) receive motion for additional work.
		let hit = HitTest.At(root, x, y);
		let key = hit != null ? hit.StableKey : 0;
		if (key != mHoveredKey)
		{
			// Clear previous hover.
			if (mHoveredKey != 0)
			{
				let prev = app.FindNode(mHoveredKey);
				StateSlots.Hover.Set(prev, false);
				prev?.MarkNeedsPaint();
			}
			// Set new hover.
			if (key != 0)
			{
				let node = app.FindNode(key);
				StateSlots.Hover.Set(node, true);
				node?.MarkNeedsPaint();
			}
			mHoveredKey = key;
			app.RequestRepaint();
		}

		return DispatchMotionToChain(root, x, y);
	}

	// ---- Chain dispatch helpers ----

	// Hit-test at (x,y), then walk leaf→root offering the event to IInputHandler
	// behaviors on each widget. Returns true if any handler consumed the event.
	static bool DispatchToChain(Widget root, float x, float y, InputEvent event)
	{
		List<Widget> chain = scope .();
		BuildChain(root, x, y, chain);
		for (var w in chain)
		{
			for (let b in w.Behaviors)
			{
				let h = b as IInputHandler;
				if (h != null && h.HandleEvent(root, w, event))
					return true;
			}
		}
		return false;
	}

	// Same chain walk for motion events.
	static bool DispatchMotionToChain(Widget root, float x, float y)
	{
		List<Widget> chain = scope .();
		BuildChain(root, x, y, chain);
		for (var w in chain)
		{
			for (let b in w.Behaviors)
			{
				let h = b as IInputHandler;
				if (h != null && h.HandleMotion(root, w, x, y))
					return true;
			}
		}
		return false;
	}

	// Builds the ancestor chain from the leaf widget at (x,y) up to (but not
	// including) root: [leaf, parent, grandparent, ...]. The leaf is deepest;
	// iterating forward dispatches leaf-first.
	static void BuildChain(Widget root, float x, float y, List<Widget> chain)
	{
		FindChain(root, x, y, chain);
	}

	// Recursively walks the tree. When a widget containing (x,y) is found, it
	// recurses into children first (so leaves come first in the chain), then
	// adds itself. Returns true when the target leaf was found anywhere in the
	// subtree, so ancestors above can add themselves.
	static bool FindChain(Widget w, float x, float y, List<Widget> chain)
	{
		if (w == null)
			return false;

		bool hit = x >= w.mRect.X && x < w.mRect.Right &&
				   y >= w.mRect.Y && y < w.mRect.Bottom;

		let children = w.GetComponent<Children>();
		bool childHit = false;
		if (children != null)
		{
			for (let child in children.Items)
			{
				if (FindChain(child, x, y, chain))
					childHit = true;
			}
		}

		if (hit)
		{
			// Add leaf first (post-order), then ancestors bubble up.
			chain.Add(w);
			return true;
		}

		return childHit;
	}

	// Find a widget by StableKey anywhere in the tree.
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
