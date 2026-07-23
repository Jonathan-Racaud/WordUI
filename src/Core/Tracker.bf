using System;

namespace WordUI;

// An event-tracker plugged into the framework's input dispatch loop.
// When SDLApp (or any backend) receives a pointer event or motion, it
// iterates registered trackers in registration order, calling HandleEvent
// and HandleMotion. A tracker returns true to consume the event and stop
// iteration — this is how DragTracker prevents PressTracker from seeing a
// MouseDown that starts a drag, and prevents HoverTracker from flickering
// during a drag.
//
// Framework trackers (HoverTracker, PressTracker, ScrollTracker, DragTracker)
// implement this interface. User-authored trackers implement it as well and
// register via App.RegisterTracker — no SDLApp modification needed.
public interface ITracker
{
	// Called for button/wheel events. Return true if consumed.
	bool HandleEvent(Widget root, InputEvent event);

	// Called for pointer motion. Return true if consumed.
	bool HandleMotion(Widget root, float x, float y);
}
