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
//
// Lifecycle tracking (mIsNew, mInitializedSlots) lets capabilities react to
// node creation, reuse, state cleanup, and disposal via the StateSlotRegistry.
// Node itself knows nothing about what any lifecycle callback does — it only
// fires them at the right reconciliation points.
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
	// [Phase5Extract] Clock, mClocks, Blend(), Tick(), and NeedsTick are
	// temporary. Phase 5 replaces them with generic ITickable dispatch on
	// capabilities stored in mState. See src/Core/ITickable.bf for the
	// target interface.

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

	// ---- Lifecycle tracking ----

	// True until the first reconciliation completes for this node.
	// Capabilities use this to distinguish first-mount initialisation from reuse.
	public bool IsNew => mIsNew;
	bool mIsNew = true;

	// Slots that have had their OnCreate lifecycle callback fired on this node.
	// Prevents double-firing OnCreate when a slot is live across multiple
	// reconciliations.
	HashSet<int> mInitializedSlots = new .() ~ delete _;

	// ---- Invalidation flags ----
	// Per-node dirty tracking for partial invalidation. When a capability writes
	// state that affects layout or paint, it calls MarkNeedsLayout() or
	// MarkNeedsPaint() on the affected node. The flag propagates up to root so
	// the framework can find dirty subtrees in a single root→leaf walk without
	// knowing what capability caused the invalidation.
	bool mNeedsLayout;
	bool mNeedsPaint;

	// True if this node or any descendant needs layout.
	public bool HasLayoutDirty => mNeedsLayout;

	// True if this node or any descendant needs paint.
	public bool HasPaintDirty => mNeedsPaint;

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

	// ---- Invalidation ----

	// Mark this node's subtree as needing layout. Propagates up the parent
	// chain so the framework can discover dirty subtrees from the root.
	// Idempotent: calling it twice on the same node is a no-op.
	public void MarkNeedsLayout()
	{
		if (mNeedsLayout)
			return;
		mNeedsLayout = true;
		if (Parent != null)
			Parent.MarkChildLayoutDirty();
	}

	// Mark this node's subtree as needing paint. Same parent-chain propagation
	// as MarkNeedsLayout, so draw walks can skip clean subtrees.
	public void MarkNeedsPaint()
	{
		if (mNeedsPaint)
			return;
		mNeedsPaint = true;
		if (Parent != null)
			Parent.MarkChildPaintDirty();
	}

	// Called by a child when it becomes layout-dirty. Propagates upward.
	void MarkChildLayoutDirty()
	{
		if (mNeedsLayout)
			return;
		mNeedsLayout = true;
		if (Parent != null)
			Parent.MarkChildLayoutDirty();
	}

	// Called by a child when it becomes paint-dirty. Propagates upward.
	void MarkChildPaintDirty()
	{
		if (mNeedsPaint)
			return;
		mNeedsPaint = true;
		if (Parent != null)
			Parent.MarkChildPaintDirty();
	}

	// Recursively clear all dirty flags in this subtree. Called after the
	// framework has processed the invalidation (layout or paint pass).
	public void ClearDirty()
	{
		mNeedsLayout = false;
		mNeedsPaint = false;
		for (let child in Children)
			child.ClearDirty();
	}

	// Clear only paint-dirty flags, leaving layout-dirty untouched. Used after
	// a paint-only pass so pending layout work isn't lost.
	public void ClearPaintDirty()
	{
		mNeedsPaint = false;
		for (let child in Children)
			child.ClearPaintDirty();
	}

	// ---- Animation clocks ----
	// [Phase5Extract] Blend/Tick/NeedsTick will be replaced by ITickable.

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

		// Collect updated clocks and settled keys outside the enumeration so
		// we never mutate mClocks while iterating it.
		List<(int key, Clock clock)> updates = scope .();
		List<int> settled = scope .();
		for (var pair in mClocks)
		{
			var c = pair.value;
			let step = c.DurationMs > 0 ? (float)dtMs / c.DurationMs : 1f;
			if (c.Target)
				c.P = Math.Min(1f, c.P + step);
			else
				c.P = Math.Max(0f, c.P - step);
			updates.Add((pair.key, c));
			if (!c.Target && c.P <= 0f)
				settled.Add(pair.key);
		}
		for (let (key, clock) in updates)
			mClocks[key] = clock;
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

	// ---- State pruning ----

	// Remove every mState key not in `liveSlots`, firing OnCleanup for each
	// before removal. Called after reconciliation for Nodes that were reused:
	// a widget at the same StableKey may have dropped a capability (e.g.
	// HoverState removed), and its stale slot data should be cleaned so mState
	// doesn't grow unboundedly.
	public void PruneState(HashSet<int> liveSlots)
	{
		List<int> dead = scope .();
		for (let pair in mState)
		{
			if (!liveSlots.Contains(pair.key))
				dead.Add(pair.key);
		}
		for (let k in dead)
		{
			// Fire OnCleanup so the capability can read its data one last time
			// and release any external resources before the slot is removed.
			let lc = StateSlotRegistry.Get(k);
			if (lc.OnCleanup != null)
				lc.OnCleanup(this, k);
			mState.Remove(k);
		}
	}

	// Same for animation clocks: remove clocks whose stateId is no longer
	// referenced by any IInteractionState on the current widget.
	public void PruneClocks(HashSet<int> liveStateIds)
	{
		List<int> dead = scope .();
		for (let pair in mClocks)
		{
			if (!liveStateIds.Contains(pair.key))
				dead.Add(pair.key);
		}
		for (let k in dead)
			mClocks.Remove(k);
	}

	// ---- Lifecycle dispatch ----

	// Fire the appropriate lifecycle callbacks for every live slot after a
	// reconciliation pass. Called once per node per rebuild.
	//
	// - New node (isNew=true): fires OnCreate for every live slot.
	// - Reused node (isNew=false): fires OnCreate for slots that appear for the
	//   first time on this node, and OnReuse for slots that already existed.
	//
	// OnCleanup is handled separately by PruneState (called before this method
	// in the reconciliation flow), and OnDispose by Dispose().
	public void OnReconciled(bool isNew, HashSet<int> liveSlots)
	{
		for (let slot in liveSlots)
		{
			let lc = StateSlotRegistry.Get(slot);
			if (isNew)
			{
				if (lc.OnCreate != null)
					lc.OnCreate(this, slot);
				mInitializedSlots.Add(slot);
			}
			else if (!mInitializedSlots.Contains(slot))
			{
				// Slot is live on this widget for the first time (even though
				// the node existed before — the widget gained a new capability).
				if (lc.OnCreate != null)
					lc.OnCreate(this, slot);
				mInitializedSlots.Add(slot);
			}
			else
			{
				if (lc.OnReuse != null)
					lc.OnReuse(this, slot);
			}
		}

		mIsNew = false;
	}

	// ---- Lifecycle ----

	// Dispose this node's own resources. Fires OnDispose for every state slot
	// still holding data so capabilities can release external resources (timers,
	// native handles, subscriptions). Children are NOT recursively disposed
	// here: the orphan loop in App.ReconcileTree disposes every orphaned Node
	// individually. A reused child is reattached via ReconcileWidget, which
	// calls Children.Clear() first to drop the old reference. Recursing here
	// would double-free orphaned children.
	public void Dispose()
	{
		// Fire OnDispose for every slot that still has data in this node.
		for (let pair in mState)
		{
			let lc = StateSlotRegistry.Get(pair.key);
			if (lc.OnDispose != null)
				lc.OnDispose(this, pair.key);
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
