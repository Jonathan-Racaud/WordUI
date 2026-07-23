using System;
using System.Collections;

namespace WordUI;

// A typed, named, discoverable key into the generic per-Node state dictionary.
// Capabilities define their own static readonly StateSlot<T> fields (framework
// slots 1–99 live in StateSlots; user slots should start at 100). The slot is
// just a typed key + accessor pair — it owns no storage itself. The underlying
// Dictionary<int, Variant> on Node stores the actual values.
//
// Usage from a tracker or property:
//   StateSlots.Hover.Set(node, true);
//   bool hovered = StateSlots.Hover.Get(node);
//
// T : struct limits typed accessors to value types (bool, int, float, etc.).
// The underlying Variant storage also supports heap objects, but heap-type
// StateSlot support is deferred until a use case demands it.
public struct StateSlot<T> where T : struct
{
	public int Id;
	public StringView Name;

	public this(int id, StringView name)
	{
		Id = id;
		Name = name;
	}

	// Reads the slot value from a retained Node. Returns default(T) when no
	// value has been set for this slot on this node, or when node is null.
	public T Get(Node node)
	{
		if (node == null)
			return default;
		Variant v = node.GetState(Id);
		T val = default;
		v.TryGet<T>(out val);
		return val;
	}

	// Writes the slot value into a retained Node. The value is stored inline
	// in the Variant with zero allocation (T : struct).
	public void Set(Node node, T value)
	{
		node.SetState(Id, Variant.Create(value));
	}
}

// Framework-reserved state slots (1–99). Each tracker/property reads and writes
// one of these; user capabilities define their own StateSlot<T> fields starting
// at 100.
//
// Slot  |  Name   | Type  | Used by
// ------+---------+-------+----------
//   1   |  Hover  | bool  | HoverTracker / HoverState
//   2   |  Press  | bool  | PressTracker / PressState
//   3   |  Scroll | float | ScrollTracker
public static class StateSlots
{
	public static readonly StateSlot<bool> Hover = .(1, "Hover");
	public static readonly StateSlot<bool> Press = .(2, "Press");
	public static readonly StateSlot<float> Scroll = .(3, "Scroll");

	// Framework-reserved slot ids that are always preserved during state
	// pruning. Trackers like HoverTracker/PressTracker/ScrollTracker write
	// to these slots regardless of whether an IInteractionState property is
	// on the widget, so they must survive the live-slot sweep. User slots
	// (>= 100) are preserved only when an IInteractionState on the widget
	// declares the corresponding StateId.
	public static readonly HashSet<int> FrameworkIds = new HashSet<int>() ~ delete _;

	static this()
	{
		FrameworkIds.Add(1); // Hover
		FrameworkIds.Add(2); // Press
		FrameworkIds.Add(3); // Scroll

		// Register framework slot lifecycles. All three are simple value types
		// (bool / float) with no external resources, so all four callbacks are
		// null — the registration exists to prove the lifecycle mechanism and
		// serve as documentation for user capabilities (which slot IDs ≥ 100
		// and register their own lifecycles here).
		StateSlotRegistry.Register(1, .() { }); // Hover  — no-op lifecycle
		StateSlotRegistry.Register(2, .() { }); // Press  — no-op lifecycle
		StateSlotRegistry.Register(3, .() { }); // Scroll — no-op lifecycle
	}
}
