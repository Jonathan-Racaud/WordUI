using System;
using System.Collections;

namespace WordUI;

// Rebuild-on-invalidate driver: `Build()` re-runs only after `Invalidate()`,
// producing a fresh widget tree in a bump arena; the previous tree (widgets,
// components, string copies) is freed wholesale by deleting the arena.
//
// The retained Node tree lives on the heap and survives rebuilds. After each
// build, ReconcileTree() matches Widget descriptions (by StableKey) against
// existing Nodes: matched Nodes are reused and their state (hover, press,
// scroll, animations) persists; new Nodes are created; orphaned Nodes are
// disposed.
//
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
	bool mNeedsLayout = false;

	// ---- Retained runtime: the Node tree ----

	// Root of the retained node tree. Nodes are heap-allocated and survive
	// rebuilds; they carry identity, parent/child relationships, generic state
	// storage, and per-node animation clocks.
	Node mRootNode;

	// O(1) StableKey → Node lookup so trackers and draw code can access
	// persistent state without a tree walk.
	Dictionary<int, Node> mNodeIndex = new .() ~ delete _;

	// ---- Drag / pointer capture (per-pointer-session) ----

	// The active capture state. InputDispatcher reads this via CaptureActive/CaptureKey;
	// writes via CaptureBegin/CaptureUpdate/CaptureEnd so the struct field (not a copy)
	// is mutated.
	PointerCapture mCapture;

	// ---- Focus ----

	// StableKey of the currently focused widget, or 0 if none.
	// Set by FocusHandler on MouseDown; read by InputDispatcher for key routing
	// and by KeyboardHandler to check if its widget has focus.
	public int FocusedKey;

	// Returns true while any IInputHandler holds a pointer capture.
	public bool CaptureActive => mCapture.Active;

	// Returns the StableKey of the capturing widget, or 0.
	public int CaptureKey => mCapture.Key;

	// Forwarding mutators that directly mutate mCapture fields (not struct copies).
	public void CaptureBegin(int key, float x, float y)
	{
		mCapture.Key = key;
		mCapture.LastX = x;
		mCapture.LastY = y;
	}
	public (float dx, float dy) CaptureUpdate(float x, float y)
	{
		let dx = x - mCapture.LastX;
		let dy = y - mCapture.LastY;
		mCapture.LastX = x;
		mCapture.LastY = y;
		return (dx, dy);
	}
	public void CaptureEnd()
	{
		mCapture.Key = 0;
	}

	// ---- Event trackers (registered by the backend) ----

	// Trackers are called in registration order for each input event.
	// A tracker returning true stops iteration (consumes the event).
	List<ITracker> mTrackers = new .() ~ DeleteContainerAndItems!(_);

	public void RegisterTracker(ITracker t)
	{
		mTrackers.Add(t);
	}

	// Iterated by the backend's event loop. Registration order = dispatch order.
	public List<ITracker> Trackers => mTrackers;

	// ---- Public accessors ----

	protected Widget Root => mRoot;

	protected abstract void Build();

	// App-data changed: rebuild + layout + render on the next frame.
	public void Invalidate() { mDirty = true; }

	// Visual-only change (interaction state, animation tick): render without a
	// rebuild. Cheap path — no arena teardown, no layout. Also marks the root
	// node paint-dirty so per-node dirty tracking stays in sync.
	public void RequestRepaint()
	{
		mNeedsRepaint = true;
		if (mRootNode != null)
			mRootNode.MarkNeedsPaint();
	}

	// Geometry-only change (resize, content reflow): re-run layout without
	// tearing down the arena or rebuilding the widget tree. Cheaper than a
	// full rebuild when structure hasn't changed.
	public void RequestLayout()
	{
		mNeedsLayout = true;
		if (mRootNode != null)
			mRootNode.MarkNeedsLayout();
	}

	public bool NeedsRepaint => mNeedsRepaint;
	public void ClearRepaint() { mNeedsRepaint = false; }

	// Runs Layout on the existing widget tree if mNeedsLayout is set.
	// Returns true when layout was performed (so the caller knows to re-render).
	public bool LayoutIfNeeded(Rect available)
	{
		if (!mNeedsLayout || mRoot == null)
			return false;
		Layout.Run(available, mRoot);
		if (mRootNode != null)
			mRootNode.ClearDirty();
		mNeedsLayout = false;
		return true;
	}

	// ---- Node lookup ----

	// Returns the retained Node for a given StableKey, or null if none exists.
	// O(1) via the index. Used by trackers and draw code to read/write
	// persistent per-widget state.
	public Node FindNode(int stableKey)
	{
		Node node;
		mNodeIndex.TryGetValue(stableKey, out node);
		return node;
	}

	// ---- Animation ticks ----

	// Wall-clock base for computing per-frame deltas. Initialised to -1 so the
	// first TickAll computes dtMs=0 (no jump). dtMs is computed once per frame
	// and passed uniformly to the whole retained tree.
	int mLastTickMs = -1;

	// Advances every ITickable in the retained Node tree by the wall-clock
	// delta since the last tick. Called once per frame from the event loop.
	public void TickAll(int nowMs)
	{
		if (mLastTickMs < 0)
			mLastTickMs = nowMs;
		int dtMs = nowMs - mLastTickMs;
		mLastTickMs = nowMs;
		if (dtMs <= 0 || mRootNode == null)
			return;
		mRootNode.Tick(dtMs);
	}

	// True while any ITickable in the retained tree needs frame updates, or a
	// pointer capture is active — drives the event loop to use a frame-clock
	// timeout instead of blocking in SDL_WaitEvent.
	public bool NeedsTick
	{
		get
		{
			if (mCapture.Active)
				return true;
			return mRootNode != null && mRootNode.HasActiveTicks;
		}
	}

	// ---- Build lifecycle ----

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

		// Assign stable identity, collecting the live key set.
		HashSet<int> live = scope .();
		KeyAssign.Run(mRoot, live);

		// Reconcile the retained Node tree against the new Widget tree:
		// reuse matched Nodes, create new ones, dispose orphans.
		ReconcileTree(mRoot, live);

		mDirty = false;
		mNeedsLayout = false;  // rebuild implies relayout; clear stale flag
		return true;
	}

	// ---- Reconciliation ----

	// Matches the freshly-built Widget tree against the existing retained Node
	// tree by StableKey. Matched Nodes are reused (their persistent state
	// survives); new Nodes are created and indexed; orphaned Nodes (in the index
	// but not in the live set) are disposed and removed.
	void ReconcileTree(Widget root, HashSet<int> live)
	{
		// Walk the Widget tree depth-first, building or reusing Nodes.
		Node newRoot = ReconcileWidget(root, null, live);

		// Dispose orphans: any Node in the index that wasn't seen this build.
		List<int> orphanKeys = scope .();
		for (let pair in mNodeIndex)
		{
			if (!live.Contains(pair.key))
				orphanKeys.Add(pair.key);
		}
		for (let key in orphanKeys)
		{
			let node = mNodeIndex[key];
			mNodeIndex.Remove(key);
			node.Dispose();
			delete node;
		}

		mRootNode = newRoot;
	}

	// Recursively reconciles one Widget to a retained Node. Returns the
	// (possibly new, possibly reused) Node for this subtree.
	Node ReconcileWidget(Widget w, Node parent, HashSet<int> live)
	{
		if (w == null)
			return null;

		bool isNew = false;
		Node node;
		if (!mNodeIndex.TryGetValue(w.StableKey, out node))
		{
			// First time seeing this key: create a fresh Node.
			node = new Node(w.StableKey);
			mNodeIndex[w.StableKey] = node;
			isNew = true;
		}

		// Update parent/child links (the Widget tree structure may have changed).
		node.Parent = parent;
		node.Children.Clear();

		// Collect live slot ids from IInteractionState properties (for animation
		// clock keys) and IHasStateSlots behaviors (for state slot keys on the
		// retained Node). These drive pruning and lifecycle dispatch — only slots
		// declared by actual capabilities on this widget survive pruning.
		HashSet<int> liveSlots = scope .();

		// The hover slot is managed globally by InputDispatcher (not a per-widget
		// behavior), so it's always preserved regardless of widget capabilities.
		liveSlots.Add(StateSlots.Hover.Id);

		for (let p in w.Properties)
		{
			let s = p as IInteractionState;
			if (s != null)
				liveSlots.Add(s.StateId);
		}
		for (let b in w.Behaviors)
		{
			let hs = b as IHasStateSlots;
			if (hs != null)
				hs.CollectSlots(liveSlots);
		}

		// Prune stale state before lifecycle dispatch: OnCleanup fires inside
		// PruneState for every slot being removed, so the capability can read
		// its data one last time.
		node.PruneState(liveSlots);

		// Fire lifecycle callbacks (OnCreate / OnReuse) top-down, before children
		// are reconciled, so a parent capability can initialise before its subtree.
		node.OnReconciled(isNew, liveSlots);

		// Recurse into children.
		let children = w.GetComponent<Children>();
		if (children != null)
		{
			for (let child in children.Items)
			{
				let childNode = ReconcileWidget(child, node, live);
				if (childNode != null)
					node.Children.Add(childNode);
			}
		}

		return node;
	}

	void ClearHandlers()
	{
		for (let h in mHandlers)
			delete h;
		mHandlers.Clear();
	}
}
