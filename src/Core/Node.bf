using System;
using System.Collections;

namespace WordUI;

// The retained runtime element: a long-lived, heap-allocated node that persists
// across rebuilds. While Widgets are transient descriptions rebuilt every frame,
// Nodes provide stable identity, tree structure, lifecycle, and generic per-node
// state storage that capabilities (hover, press, scroll, animation) write into
// and read from.
//
// Node knows NOTHING about what any state slot means. Slot constants are defined
// by the capabilities that use them (framework reserves 1..99; user capabilities
// pick >= 100). The storage is a single Dictionary<int, Variant> — any type fits,
// small value types (bool, int, float) are stored inline with zero allocation.
//
// Animation clocks are stored separately because they have internal structure
// (progress, target, duration, curve) and their own lifecycle (self-pruning).
public class Node
{
	public int StableKey;
	public Node Parent;
	public List<Node> Children = new .() ~ DeleteAndNullify!(_);

	// Generic per-node state: capabilities write/read Variant values keyed by
	// their own slot constants. A Variant stores small types inline without
	// allocation; boxing only happens for large/value types that don't fit.
	Dictionary<int, Variant> mState = new .() ~ delete _;

	// ---- Animation clocks ----

	struct Clock
	{
		public float P;          // current eased-input progress, [0,1]
		public bool Target;      // true = animate toward 1, false = toward 0
		public int DurationMs;
		public Easing Curve;
	}

	// Clocks are keyed by StateId (the stable int from IInteractionState).
	// They self-prune: clocks that settle at P=0 with Target=false are removed.
	Dictionary<int, Clock> mClocks = new .() ~ delete _;

	int mLastTickMs = -1;

	public this(int key)
	{
		StableKey = key;
	}

	// ---- State access ----

	// Raw access: capability defines its own slot constant and value type.
	public void SetState(int slot, Variant value)
	{
		mState[slot] = value;
	}

	public Variant GetState(int slot)
	{
		return mState.GetValueOrDefault(slot);
	}

	// Typed conveniences for the 90% case (zero-allocation Variant path).

	public bool GetBool(int slot, bool defaultValue = false)
	{
		Variant v = GetState(slot);
		bool val = defaultValue;
		v.TryGet<bool>(out val);
		return val;
	}

	public void SetBool(int slot, bool value)
	{
		SetState(slot, Variant.Create(value));
	}

	public float GetFloat(int slot, float defaultValue = 0f)
	{
		Variant v = GetState(slot);
		float val = defaultValue;
		v.TryGet<float>(out val);
		return val;
	}

	public void SetFloat(int slot, float value)
	{
		SetState(slot, Variant.Create(value));
	}

	public int GetInt(int slot, int defaultValue = 0)
	{
		Variant v = GetState(slot);
		int val = defaultValue;
		v.TryGet<int>(out val);
		return val;
	}

	public void SetInt(int slot, int value)
	{
		SetState(slot, Variant.Create(value));
	}

	// ---- Animation clocks ----

	// Ensure a clock exists for `stateId`, update its target/params, and return
	// the current eased blend factor in [0,1] (0 = base, 1 = fully at target).
	// Called by the draw-time style resolver for each animated state.
	public float Blend(int stateId, bool active, int durationMs, Easing curve)
	{
		Clock c;
		if (!mClocks.TryGetValue(stateId, out c))
			c = .() { P = 0f, Target = active, DurationMs = durationMs, Curve = curve };
		c.Target = active;
		c.DurationMs = durationMs;
		c.Curve = curve;
		mClocks[stateId] = c;
		return c.Curve.Apply(c.P);
	}

	// Advance all clocks by the wall-clock delta since the last tick. Prunes
	// clocks that have settled at 0 (fully inactive).
	public void Tick(int nowMs)
	{
		if (mLastTickMs < 0)
			mLastTickMs = nowMs;
		let dtMs = nowMs - mLastTickMs;
		mLastTickMs = nowMs;
		if (dtMs <= 0)
			return;

		List<int> settled = scope .();
		for (var pair in mClocks)
		{
			var c = pair.value;
			let step = c.DurationMs > 0 ? (float)dtMs / c.DurationMs : 1f;
			if (c.Target)
				c.P = Math.Min(1f, c.P + step);
			else
				c.P = Math.Max(0f, c.P - step);
			mClocks[pair.key] = c;
			if (!c.Target && c.P <= 0f)
				settled.Add(pair.key);
		}
		for (let k in settled)
			mClocks.Remove(k);

		// Recurse into children so a single root Tick() call advances the whole tree.
		for (let child in Children)
			child.Tick(nowMs);
	}

	// True while any clock in this subtree is mid-transition.
	public bool NeedsTick
	{
		get
		{
			for (let pair in mClocks)
			{
				let c = pair.value;
				if (c.Target && c.P < 1f)
					return true;
				if (!c.Target && c.P > 0f)
					return true;
			}
			for (let child in Children)
			{
				if (child.NeedsTick)
					return true;
			}
			return false;
		}
	}

	// ---- Lifecycle ----

	public void Dispose()
	{
		for (let child in Children)
		{
			child.Dispose();
			delete child;
		}
		Children.Clear();
	}

	// Add a child, setting its parent link.
	public void AddChild(Node child)
	{
		child.Parent = this;
		Children.Add(child);
	}
}
