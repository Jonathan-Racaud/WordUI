using System;
using System.Collections;

namespace WordUI;

// The retained runtime element: a long-lived, heap-allocated node that persists
// across rebuilds. While Widgets are transient descriptions rebuilt every frame,
// Nodes provide stable identity, tree structure, lifecycle, generic per-node
// state storage, and a retained RenderNode for layout geometry and paint
// invalidation.
//
// Node knows NOTHING about what any state slot means. Slot constants are defined
// by the capabilities that use them (framework reserves 1..99; user capabilities
// pick >= 100). The storage is a single Dictionary<int, Variant> — any type fits,
// small value types (bool, int, float) are stored inline with zero allocation.
//
// Tick dispatch is generic: capabilities that need per-frame time updates implement
// ITickable and register themselves via RegisterTickable/UnregisterTickable.
// Node.Tick(dtMs) iterates all registered tickables and recurses into children.
// The scheduler (App) computes dtMs once per frame and passes it down — Node itself
// has no concept of wall-clock time or animation.
//
// Lifecycle tracking (mIsNew, mInitializedSlots) lets capabilities react to
// node creation, reuse, state cleanup, and disposal via the StateSlotRegistry.
// Node itself knows nothing about what any lifecycle callback does — it only
// fires them at the right reconciliation points.
//
// Retained render state (layout geometry, paint-dirty) lives on the RenderNode
// attached to each Node, not here. This keeps the Node focused on identity,
// state storage, and lifecycle.
public class Node
{
	public int StableKey;
	public Node Parent;
	public List<Node> Children = new .() ~ DeleteAndNullify!(_);

	// Generic per-node state: capabilities write/read Variant values keyed by
	// their own slot constants. A Variant stores small types inline without
	// allocation; boxing only happens for large/value types that don't fit.
	Dictionary<int, Variant> mState = new .() ~ delete _;

	// ---- Tick dispatch ----
	// Capabilities that need per-frame time updates implement ITickable and
	// register here. Node dispatches Tick(dtMs) to every registered tickable
	// and recurses into children — it has no idea what any tickable does.
	// Tickables own themselves: they are heap-allocated by their capability and
	// delete themselves (or are deleted by the capability's lifecycle hooks).
	// Node only holds references; Dispose() snapshots and deletes them all.
	List<ITickable> mTickables = new .() ~ delete _;

	// Read-only access for capabilities that need to find their tickable by
	// type (e.g. AnimationState.Get scans for an existing AnimationState).
	public List<ITickable> Tickables => mTickables;

	// ---- Lifecycle tracking ----

	// True until the first reconciliation completes for this node.
	// Capabilities use this to distinguish first-mount initialisation from reuse.
	public bool IsNew => mIsNew;
	bool mIsNew = true;

	// Slots that have had their OnCreate lifecycle callback fired on this node.
	// Prevents double-firing OnCreate when a slot is live across multiple
	// reconciliations.
	HashSet<int> mInitializedSlots = new .() ~ delete _;
	bool mDisposing;
	bool mDisposed;

	// ---- Invalidation flags ----
	// Per-node dirty tracking for partial invalidation. When a capability writes
	// state that affects layout, it calls MarkNeedsLayout() on the affected node.
	// The flag propagates up to root so the framework can find dirty subtrees in
	// a single root→leaf walk. Paint-dirty lives on RenderNode (retained render layer).
	bool mNeedsLayout;

	// True if this node or any descendant needs layout.
	public bool HasLayoutDirty => mNeedsLayout;

	// ---- Retained render layer ----

	// The retained RenderNode owns layout geometry (Bounds) and paint-dirty
	// tracking. Created lazily on first access so nodes that never participate
	// in layout/rendering don't allocate one.
	RenderNode mRenderNode;

	// Lazy get-or-create accessor. Triggers heap allocation on first call.
	public RenderNode RenderNode
	{
		get
		{
			Runtime.Assert(!mDisposing && !mDisposed, "Cannot access a disposed Node's RenderNode");
			if (mRenderNode == null)
				mRenderNode = new RenderNode(this);
			return mRenderNode;
		}
	}

	public this(int key)
	{
		StableKey = key;
	}

	public ~this()
	{
		Dispose();
	}

	// ---- State access ----

	// Raw access: capability defines its own slot constant and value type.
	// Ownership of an owned Variant is transferred to the Node.
	public void SetState(int slot, Variant value)
	{
		Runtime.Assert(!mDisposing && !mDisposed, "Cannot set state on a disposed Node");
		Variant existing;
		if (mState.TryGetValue(slot, out existing))
		{
			if (OwnsSameStorage(existing, value))
				return;
			existing.Dispose();
		}
		mState[slot] = value;
	}

	// Reuses an existing Variant's storage when the slot already has this type,
	// avoiding per-update heap allocation for larger value types.
	public void SetState<T>(int slot, T value) where T : struct
	{
		Runtime.Assert(!mDisposing && !mDisposed, "Cannot set state on a disposed Node");
		int* key;
		Variant* existing;
		if (mState.TryGetRef(slot, out key, out existing) &&
			existing.VariantType == typeof(T) &&
			existing.OwnsMemory &&
			!existing.IsObject)
		{
			*(T*)existing.DataPtr = value;
			return;
		}
		SetState(slot, Variant.Create(value));
	}

	// Returns a borrowed view; callers must not retain it past a state mutation
	// or dispose it. Typed accessors copy values out immediately.
	public Variant GetState(int slot)
	{
		var value = mState.GetValueOrDefault(slot);
		if (!value.OwnsMemory)
			return value;
		if (value.IsObject)
			return Variant.Create(value.Get<Object>());
		return Variant.CreateReference(value.VariantType, value.DataPtr);
	}

	static bool OwnsSameStorage(Variant existing, Variant incoming)
	{
		if (!existing.OwnsMemory || existing.VariantType != incoming.VariantType)
			return false;
		if (existing.IsObject)
			return incoming.IsObject && existing.Get<Object>() == incoming.Get<Object>();
		var existingValue = existing;
		var incomingValue = incoming;
		return !incoming.IsObject && existingValue.DataPtr == incomingValue.DataPtr;
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
		SetState(slot, value);
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
		SetState(slot, value);
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
		SetState(slot, value);
	}

	// ---- Layout invalidation ----

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

	// Convenience: mark this node's retained RenderNode as paint-dirty.
	// Delegates to RenderNode.MarkNeedsPaint() which handles parent-chain
	// propagation. The RenderNode is lazily created if it doesn't exist yet.
	public void MarkNeedsPaint()
	{
		RenderNode.MarkNeedsPaint();
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

	// Recursively clear all dirty flags in this subtree. Called after the
	// framework has processed the invalidation (layout pass).
	public void ClearDirty()
	{
		mNeedsLayout = false;
		RenderNode?.ClearPaintDirty();
		for (let child in Children)
			child.ClearDirty();
	}

	// Clear only paint-dirty flags, leaving layout-dirty untouched. Used after
	// a paint-only pass so pending layout work isn't lost.
	public void ClearPaintDirty()
	{
		RenderNode?.ClearPaintDirty();
	}

	// ---- Tick dispatch ----

	// Register a capability that needs per-frame Tick() calls. Called by the
	// capability when it is created for this node (typically during OnCreate
	// lifecycle or lazy first-use initialisation).
	public void RegisterTickable(ITickable t)
	{
		mTickables.Add(t);
	}

	// Remove a previously registered tickable. Called by the capability's
	// destructor or during cleanup/pruning.
	public void UnregisterTickable(ITickable t)
	{
		mTickables.Remove(t);
	}

	// Advance every registered tickable by dtMs, then recurse into children.
	// Collects a snapshot first so tickables can safely unregister themselves
	// during Tick() without mutating the list under iteration.
	public void Tick(int dtMs)
	{
		if (dtMs <= 0)
			return;

		List<ITickable> snapshot = scope .();
		for (let t in mTickables)
			snapshot.Add(t);
		for (let t in snapshot)
			t.Tick(dtMs);

		for (let child in Children)
			child.Tick(dtMs);
	}

	// True while any registered tickable in this subtree still needs updates.
	// Drives the host to request another frame while time-based state is active.
	public bool HasActiveTicks
	{
		get
		{
			for (let t in mTickables)
				if (t.NeedsTick)
					return true;
			for (let child in Children)
				if (child.HasActiveTicks)
					return true;
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
		HashSet<int> dead = scope .();
		for (let pair in mState)
		{
			if (!liveSlots.Contains(pair.key))
				dead.Add(pair.key);
		}
		for (let slot in mInitializedSlots)
		{
			if (!liveSlots.Contains(slot))
				dead.Add(slot);
		}
		for (let k in dead)
		{
			// Fire OnCleanup even when a capability did not store a value in its slot.
			let lc = StateSlotRegistry.Get(k);
			if (lc.OnCleanup != null)
				lc.OnCleanup(this, k);
			RemoveStateValue(k);
			mInitializedSlots.Remove(k);
		}
	}

	void RemoveStateValue(int slot)
	{
		Variant value;
		if (mState.TryGetValue(slot, out value))
		{
			value.Dispose();
			mState.Remove(slot);
		}
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

	// Dispose this node's own resources. Child nodes are disposed separately by
	// the owning App; clearing child references here prevents recursive deletion.
	public void Dispose()
	{
		if (mDisposed || mDisposing)
			return;
		mDisposing = true;

		// Delete tickables first (each destructor unregisters from mTickables).
		// Snapshot so the list isn't mutated under iteration.
		List<ITickable> snapshot = scope .();
		for (let t in mTickables)
			snapshot.Add(t);
		for (let t in snapshot)
			delete t;
		mTickables.Clear();

		// Fire OnDispose for initialized slots, including capabilities whose
		// OnCreate did not need to store a value in mState.
		HashSet<int> slots = scope .();
		for (let slot in mInitializedSlots)
			slots.Add(slot);
		for (let pair in mState)
			slots.Add(pair.key);
		for (let slot in slots)
		{
			let lc = StateSlotRegistry.Get(slot);
			if (lc.OnDispose != null)
				lc.OnDispose(this, slot);
		}

		for (let pair in mState)
		{
			var value = pair.value;
			value.Dispose();
		}
		mState.Clear();
		mInitializedSlots.Clear();

		// Dispose the retained RenderNode (layout geometry, resource cache).
		if (mRenderNode != null)
		{
			mRenderNode.Dispose();
			delete mRenderNode;
			mRenderNode = null;
		}

		Children.Clear();
		Parent = null;
		mDisposed = true;
		mDisposing = false;
	}

	// Add a child, setting its parent link.
	public void AddChild(Node child)
	{
		child.Parent = this;
		Children.Add(child);
	}
}
