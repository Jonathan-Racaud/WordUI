using System;
using System.Collections;

namespace WordUI;

// A capability receives a lifecycle event for one of its state slots on a
// specific Node. The slotId is passed explicitly so one handler can serve
// multiple slots (rare, but avoids forcing per-slot lambdas).
public delegate void SlotLifecycleHandler(Node node, int slotId);

// Creation, reuse, cleanup, and disposal callbacks that a capability can
// register for its state slot. All fields are optional — a slot that only
// needs a disposal hook (e.g. to free a native resource) registers just
// OnDispose. The framework fires these at the right points during
// reconciliation and node disposal.
public struct SlotLifecycle
{
	public SlotLifecycleHandler OnCreate;   // first time slot data appears on a node (node is brand-new or slot is new to a reused node)
	public SlotLifecycleHandler OnReuse;     // slot survives reconciliation on a reused node (it already had data)
	public SlotLifecycleHandler OnCleanup;   // slot being pruned — the capability can read its data one last time before it's removed
	public SlotLifecycleHandler OnDispose;   // node being destroyed — last chance to release resources
}

// Global registry mapping state slot IDs to their lifecycle callbacks.
// Capabilities register their slots once (typically in a static constructor);
// the reconciliation and disposal paths query this registry to fire the
// right callbacks at the right times. There is no per-node allocation for
// the registry itself — it's a static table written once at startup.
public static class StateSlotRegistry
{
	static Dictionary<int, SlotLifecycle> sRegistry = new .() ~ delete _;

	// Register lifecycle callbacks for a slot. Call once per slot, typically
	// from a static constructor. Overwrites any previous registration for the
	// same slot (latest wins).
	public static void Register(int slotId, SlotLifecycle lifecycle)
	{
		sRegistry[slotId] = lifecycle;
	}

	// Returns the lifecycle for a slot, or default (all-null) if unregistered.
	// Inlined so the reconciliation hot path pays zero virtual dispatch.
	public static SlotLifecycle Get(int slotId)
	{
		return sRegistry.GetValueOrDefault(slotId);
	}
}
