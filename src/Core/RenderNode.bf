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

	// Each entry owns one resource wrapper and disposes it when replaced,
	// removed, or when this RenderNode is disposed.
	Dictionary<Type, RenderResource> mResources = new .() ~ delete _;
	bool mDisposed;

	public this(Node owner)
	{
		mOwner = owner;
	}

	public ~this()
	{
		Dispose();
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

	// Retrieve the retained resource owned on behalf of component T.
	public TResource GetResource<TComponent, TResource>()
		where TComponent : Component
		where TResource : RenderResource
	{
		RenderResource resource;
		if (!mDisposed && mResources.TryGetValue(typeof(TComponent), out resource))
			return resource as TResource;
		return null;
	}

	// Transfers ownership of a heap-allocated resource to this RenderNode.
	// Each resource may be stored in only one cache slot.
	public void SetResource<TComponent>(RenderResource resource) where TComponent : Component
	{
		Runtime.Assert(!mDisposed, "Cannot set a resource on a disposed RenderNode");
		Runtime.Assert(resource != null, "Cannot set a null RenderNode resource");

		let key = typeof(TComponent);
		RenderResource existing;
		if (mResources.TryGetValue(key, out existing) && existing == resource)
			return;

		for (let pair in mResources)
			Runtime.Assert(pair.value != resource, "A RenderNode resource can only be owned by one cache slot");

		resource.Claim(this);
		if (mResources.TryGetValue(key, out existing))
		{
			mResources.Remove(key);
			ReleaseResource(existing);
		}
		mResources[key] = resource;
	}

	// Removes and disposes the retained resource for component T, if present.
	public void RemoveResource<TComponent>() where TComponent : Component
	{
		RenderResource resource;
		if (mResources.TryGetValue(typeof(TComponent), out resource))
		{
			mResources.Remove(typeof(TComponent));
			ReleaseResource(resource);
		}
	}

	void ReleaseResource(RenderResource resource)
	{
		resource.Release(this);
		resource.Dispose();
		delete resource;
	}

	// ---- Lifecycle ----

	// Release retained resources. Called by Node.Dispose() when the owning
	// Node is destroyed (orphaned by reconciliation).
	public void Dispose()
	{
		if (mDisposed)
			return;
		mDisposed = true;

		List<RenderResource> resources = scope .();
		for (let pair in mResources)
			resources.Add(pair.value);
		mResources.Clear();
		for (let resource in resources)
			ReleaseResource(resource);
		mOwner = null;
	}
}
