using System;

namespace WordUI;

// Capabilities that need per-frame time updates implement this interface.
// Register on a Node via node.RegisterTickable(this); unregister via
// node.UnregisterTickable(this) (typically in a destructor).
//
// Node.Tick(dtMs) iterates all registered tickables in snapshot order and
// recurses into children. The scheduler (App) computes dtMs once per frame
// from wall-clock time and passes it uniformly to the whole tree.
//
// Built-in example: AnimationState manages per-StateId eased-progress clocks.
// User example: a blinking cursor, physics simulation, or inertial scroll
// capability implements ITickable, stores its state via Node state slots, and
// receives Tick(dtMs) each frame without any framework modification.
//
// NeedsTick drives the event loop: when no ITickable in the tree returns true
// and no drag is active, the loop blocks (zero idle CPU).
public interface ITickable
{
	// True while this capability still needs frame updates. Drives the event
	// loop: when no ITickable in the tree returns true and no drag is active,
	// the loop blocks (zero idle CPU).
	bool NeedsTick { get; }

	// Advance internal state by the wall-clock delta since the last frame (ms).
	// Called once per frame from the scheduler.
	void Tick(int dtMs);
}
