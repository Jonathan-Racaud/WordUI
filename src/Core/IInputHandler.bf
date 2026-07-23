using System;
using System.Collections;

namespace WordUI;

// Behaviors that handle input events implement this interface. The InputDispatcher
// finds IInputHandler behaviors on hit widgets and routes events to them.
// Returning true from HandleEvent claims the pointer capture (for press-drag
// interactions); returning true from HandleMotion consumes the motion so no
// further behaviors on the same widget see it.
//
// This is the single extension point for custom interaction types: a user authors
// a Behavior + IInputHandler pair and attaches it to any widget via a word — no
// global tracker registration, no framework modification.
public interface IInputHandler
{
	// Called for button/wheel/key events. The dispatcher provides:
	//   root  — the full widget tree (for ancestor walks)
	//   owner — the widget carrying this behavior
	//   event — the adapted input event
	// Return true to claim pointer capture (MouseDown) or consume the event.
	bool HandleEvent(Widget root, Widget owner, InputEvent event);

	// Called for pointer motion. Same contract; during capture, only the
	// capturing widget's behaviors receive motion.
	bool HandleMotion(Widget root, Widget owner, float x, float y);
}

// Behaviors that own state in the retained Node tree implement this interface
// so the reconciliation pass knows which state slots to preserve during pruning.
// Each behavior adds its StateSlot IDs to the provided set; the framework merges
// these with IInteractionState.StateId from properties to build the live-slot
// set that drives PruneState.
public interface IHasStateSlots
{
	void CollectSlots(HashSet<int> slots);
}
