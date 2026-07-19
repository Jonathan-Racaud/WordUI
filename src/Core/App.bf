using System;
using System.Collections;

namespace PFUI;

// Rebuild-on-invalidate driver: `Build()` re-runs only after `Invalidate()`,
// producing a fresh widget tree in a bump arena; the previous tree (widgets,
// components, string copies) is freed wholesale by deleting the arena.
// Non-core conveniences (DumpTree, SimulateClick) live in Diagnostics/ as
// extensions of this class.
public abstract class App
{
	BumpAllocator mArena ~ delete _;
	List<ClickHandler> mHandlers = new .() ~ { ClearHandlers(); delete _; };
	Widget mRoot;
	bool mDirty = true;

	protected Widget Root => mRoot;

	protected abstract void Build();

	public void Invalidate() { mDirty = true; }

	// Returns true if a rebuild happened.
	public bool RebuildIfNeeded()
	{
		if (!mDirty)
			return false;

		mRoot = null;
		DeleteAndNullify!(mArena);   // frees the entire previous tree
		ClearHandlers();
		mArena = new BumpAllocator();

		UI.BeginBuild(mArena, mHandlers);
		Build();
		mRoot = UI.EndBuild();
		mDirty = false;
		return true;
	}

	void ClearHandlers()
	{
		for (let h in mHandlers)
			delete h;
		mHandlers.Clear();
	}
}
