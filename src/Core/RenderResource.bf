using System;

namespace WordUI;

// A heap-allocated resource owned by a RenderNode. Dispose releases backend
// resources; RenderNode then deletes the wrapper object.
public abstract class RenderResource
{
	RenderNode mOwner;

	public void Claim(RenderNode owner)
	{
		Runtime.Assert(owner != null, "A render resource requires an owner");
		Runtime.Assert(mOwner == null, "A render resource can only have one owner");
		mOwner = owner;
	}

	public void Release(RenderNode owner)
	{
		Runtime.Assert(mOwner == owner, "Render resource released by a non-owner");
		mOwner = null;
	}

	public abstract void Dispose();
}
