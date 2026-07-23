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

// Framework-reserved state slots (1–99). Each capability reads and writes
// one of these; user capabilities define their own StateSlot<T> fields starting
// at 100. Slots are preserved during pruning only when a capability on the
// widget declares them via IHasStateSlots (behaviors) or IInteractionState
// (properties) — no slot is "always live."
//
// Slot  |  Name       | Type          | Used by
// ------+-------------+---------------+----------
//   1   |  Hover      | bool          | HoverHandler / HoverState
//   2   |  Press      | bool          | PressHandler / PressState
//   3   |  Scroll     | float         | ScrollHandlerBehavior / ScrollView
//   4   |  DragOffset | DragOffset    | DragHandlerBehavior / RenderDragOffset
//   5   |  Focus      | bool          | FocusHandler
public static class StateSlots
{
	public static readonly StateSlot<bool> Hover = .(1, "Hover");
	public static readonly StateSlot<bool> Press = .(2, "Press");
	public static readonly StateSlot<float> Scroll = .(3, "Scroll");
	public static readonly StateSlot<DragOffset> DragOffset = .(4, "DragOffset");
	public static readonly StateSlot<bool> Focus = .(5, "Focus");

	static this()
	{
		// Register framework slot lifecycles. All five are simple value types
		// with no external resources, so all four callbacks are null — the
		// registration exists to prove the lifecycle mechanism and serve as
		// documentation for user capabilities.
		StateSlotRegistry.Register(1, .() { }); // Hover
		StateSlotRegistry.Register(2, .() { }); // Press
		StateSlotRegistry.Register(3, .() { }); // Scroll
		StateSlotRegistry.Register(4, .() { }); // DragOffset
		StateSlotRegistry.Register(5, .() { }); // Focus
	}
}
