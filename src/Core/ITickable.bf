using System;

namespace WordUI;

// Design artifact — forward-looking hook for Phase 5 (scheduling / frame lifecycle).
//
// Capabilities that need per-frame time updates implement this interface.
// Phase 5 will replace the hardcoded Clock/Tick/Blend on Node with a generic
// tick-dispatch loop: Node.Tick(dt) iterates ITickable capabilities stored as
// Variant in mState (or registered directly), calling Tick(dtMs) on each.
//
// Animation clocks will become an AnimationState : Property, ITickable
// capability that stores its clock data in mState. Easing will become
// user-extensible (interface or delegate instead of a closed enum).
//
// No callers exist yet — this is a design artifact that documents the target
// architecture. Do NOT add ITickable dispatch to Node.Tick() until Phase 5.
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
