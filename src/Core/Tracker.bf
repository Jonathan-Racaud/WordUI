using System;

namespace WordUI;

// An event-tracker plugged into the framework's input dispatch loop.
// When a backend receives a pointer event or motion, App iterates registered
// trackers in registration order, calling HandleEvent
// and HandleMotion. A tracker returning true consumes the event and stops
// iteration.
//
// The built-in InputDispatcher is the primary tracker: it hit-tests, walks
// the widget chain leaf→root, and routes events to IInputHandler behaviors.
// User-authored trackers implement this interface as well and register via
// App.RegisterTracker — no backend modification needed.
public interface ITracker
{
	// Called for button/wheel events. Return true if consumed.
	bool HandleEvent(Widget root, InputEvent event);

	// Called for pointer motion. Return true if consumed.
	bool HandleMotion(Widget root, float x, float y);
}
