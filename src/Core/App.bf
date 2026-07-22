using System;
using System.Collections;

namespace WordUI;

// Rebuild-on-invalidate driver: `Build()` re-runs only after `Invalidate()`,
// producing a fresh widget tree in a bump arena; the previous tree (widgets,
// components, string copies) is freed wholesale by deleting the arena.
// Non-core conveniences (e.g. DumpTree) live in Diagnostics/ as extensions
// of this class.
public abstract class App
{
	// The active App instance; set by SDLApp constructor, used by trackers
	// and other infrastructure that need to trigger rebuilds.
	public static App Instance;

	BumpAllocator mArena ~ delete _;
	// Owns event handlers (click, drag, …) the user allocates with `new`; freed
	// wholesale on the next rebuild. Delegate is the common base of every handler
	// signature (ClickHandler, DragHandler).
	List<Delegate> mHandlers = new .() ~ { ClearHandlers(); delete _; };
	Widget mRoot;
	bool mDirty = true;
	bool mNeedsRepaint = false;

	// Interaction/animation/drag state that must outlive the build arena, so a
	// hover fade at t=0.1s keeps running across a rebuild. Keyed by StableKey.
	public InteractionStore Store = new .() ~ delete _;

	protected Widget Root => mRoot;

	protected abstract void Build();

	// App-data changed: rebuild + layout + render on the next frame.
	public void Invalidate() { mDirty = true; }

	// Visual-only change (interaction state, animation tick): render without a
	// rebuild. Cheap path — no arena teardown, no layout.
	public void RequestRepaint() { mNeedsRepaint = true; }

	public bool NeedsRepaint => mNeedsRepaint;
	public void ClearRepaint() { mNeedsRepaint = false; }

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
		KeyAssign.Run(mRoot);   // stable identity for the persistent store
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
