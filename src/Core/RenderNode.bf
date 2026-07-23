using System;
using System.Collections;

namespace WordUI;

// The retained render object for a Node. While the Widget is a transient
// description rebuilt every frame, the RenderNode persists across rebuilds
// and owns:
//
//   - Layout geometry (Rect Bounds) — survives rebuilds, so paint-only updates
//     don't need to re-run layout.
//   - Per-node paint-dirty flag with parent-chain propagation — the draw loop
//     skips clean subtrees.
//   - A per-component-type resource cache — components can stash retained
//     render resources (texture handles, computed paths) keyed by their own type.
//
// RenderNode is a peer to Component, not a replacement. Components still own
// the Draw* hooks; the RenderNode provides the retained substrate underneath.
//
// Memory: heap-allocated (new), owned by Node. Created lazily on first access
// via Node.RenderNode property. Disposed by Node.Dispose().
public class RenderNode
{
	// Layout geometry assigned by the layout pass. Replaces Widget.mRect.
	public Rect Bounds;

	// True when this node or any descendant needs repaint. Set by MarkNeedsPaint()
	// and propagated up the parent chain so the draw loop can discover dirty
	// subtrees from the root in a single walk.
	bool mNeedsPaint;

	// Back-reference to the owning Node, used for parent-chain propagation
	// during MarkNeedsPaint().
	Node mOwner;

	// Per-component-type retained render resource cache. Components store
	// render resources here keyed by their own concrete type (e.g. a future
	// TextComponent might store a cached texture id under typeof(TextComponent)).
	// Variant stores small value types inline with zero allocation; heap objects
	// stored via Variant.CreateBoxed are owned here and freed on dispose.
	Dictionary<Type, Variant> mResources = new .() ~ delete _;

	public this(Node owner)
	{
		mOwner = owner;
	}

	// True while this node or any descendant needs paint.
	public bool NeedsPaint => mNeedsPaint;

	// ---- Bounds ----

	// Assign layout geometry. If the rect actually changes, auto-marks this
	// node as paint-dirty so the next draw pass repaints it. Idempotent for
	// the same rect (no unnecessary dirtying on repeated identical layouts).
	public void SetBounds(Rect newBounds)
	{
		if (Bounds != newBounds)
		{
			Bounds = newBounds;
			MarkNeedsPaint();
		}
		else
		{
			Bounds = newBounds;
		}
	}

	// ---- Paint invalidation ----

	// Mark this node's subtree as needing paint. Propagates up the parent
	// chain so the draw loop can find dirty subtrees from the root.
	// Idempotent: calling it twice on the same node is a no-op.
	public void MarkNeedsPaint()
	{
		if (mNeedsPaint)
			return;
		mNeedsPaint = true;

		// Propagate upward through the RenderNode chain.
		var parent = mOwner?.Parent;
		while (parent != null)
		{
			let pr = parent.RenderNode;
			if (pr.mNeedsPaint)
				break; // already dirty — stop propagating
			pr.mNeedsPaint = true;
			parent = parent.Parent;
		}
	}

	// Recursively clear all paint-dirty flags in this subtree. Called after
	// the draw pass completes so the next frame starts clean.
	public void ClearPaintDirty()
	{
		mNeedsPaint = false;
		for (let child in mOwner.Children)
		{
			let cr = child.RenderNode;
			if (cr != null)
				cr.ClearPaintDirty();
		}
	}

	// ---- Resource cache ----

	// Retrieve a retained render resource stored by a component of type T.
	// Returns default(Variant) (empty) if nothing has been stored.
	public Variant GetResource<T>() where T : Component
	{
		return mResources.GetValueOrDefault(typeof(T));
	}

	// Store a retained render resource for a component of type T. Overwrites
	// any previous value. The resource lives as long as this RenderNode exists
	// (i.e. across rebuilds, until the Node is disposed).
	public void SetResource<T>(Variant value) where T : Component
	{
		mResources[typeof(T)] = value;
	}

	// Remove and return the cached resource for T, if any.
	public void RemoveResource<T>() where T : Component
	{
		mResources.Remove(typeof(T));
	}

	// ---- Lifecycle ----

	// Release retained resources. Called by Node.Dispose() when the owning
	// Node is destroyed (orphaned by reconciliation).
	public void Dispose()
	{
		// Variant values that are small value types (int, float, bool) are
		// stored inline and need no cleanup. Boxed heap objects stored via
		// Variant.CreateBoxed would need explicit deletion, but no component
		// currently uses that path. If a future component stores heap resources,
		// it should hook into the owning Node's state lifecycle for cleanup.
		mResources.Clear();
		mOwner = null;
	}
}
