using System;
using System.Collections;

namespace WordUI;

// Persistent, non-arena interaction state. Owned by App, it outlives every
// rebuild so a hover fade at t=0.1s keeps running when app data changes and the
// widget tree is torn down and rebuilt. All state is keyed by Widget.StableKey
// (assigned by KeyAssign), never by a Widget* — which is what fixes the
// dangling-pointer missed/delayed clicks.
class InteractionStore
{
	// One animation clock per (widget, stateId). p in [0,1] eases toward 1 while
	// the state is active and toward 0 while inactive, so interrupting/reversing
	// a transition mid-flight is smooth. Duration/curve come from Transition().
	struct ClockKey : IHashable
	{
		public int Widget;
		public int State;
		public int GetHashCode() => (Widget &* 0x100000001b3) ^ State;
		public static bool operator==(ClockKey a, ClockKey b) =>
			a.Widget == b.Widget && a.State == b.State;
	}

	struct Clock
	{
		public float P;          // current eased-input progress, [0,1]
		public bool Target;      // true = animate toward 1, false = toward 0
		public int DurationMs;
		public Easing Curve;
	}

	Dictionary<int, bool> mHover = new .() ~ delete _;
	Dictionary<int, bool> mPress = new .() ~ delete _;
	Dictionary<ClockKey, Clock> mClocks = new .() ~ delete _;

	// Pointer capture / drag. mDragKey == 0 means no active drag.
	int mDragKey = 0;
	float mDragDX, mDragDY;
	float mDragLastX, mDragLastY;

	int mLastTickMs = -1;

	// ---- Hover / press booleans (queried by state Properties at draw) ----

	public void SetHover(int key, bool v) => mHover[key] = v;
	public bool IsHovered(int key) => mHover.GetValueOrDefault(key);

	public void SetPress(int key, bool v) => mPress[key] = v;
	public bool IsPressed(int key) => mPress.GetValueOrDefault(key);

	// ---- Drag / capture ----

	public bool DragActive => mDragKey != 0;
	public int DragKey => mDragKey;

	public void BeginDrag(int key, float x, float y)
	{
		mDragKey = key;
		mDragDX = 0; mDragDY = 0;
		mDragLastX = x; mDragLastY = y;
	}

	// Returns the incremental delta since the last motion, for the OnDrag handler.
	public (float dx, float dy) UpdateDrag(float x, float y)
	{
		let dx = x - mDragLastX;
		let dy = y - mDragLastY;
		mDragDX += dx; mDragDY += dy;
		mDragLastX = x; mDragLastY = y;
		return (dx, dy);
	}

	public void EndDrag()
	{
		mDragKey = 0;
		mDragDX = 0; mDragDY = 0;
	}

	// Accumulated offset for the widget currently being dragged (else zero).
	public (float x, float y) DragOffset(int key) =>
		(key == mDragKey) ? (mDragDX, mDragDY) : (0f, 0f);

	// ---- Animation clocks ----

	// Ensure a clock exists for (key,state), update its target/params, and return
	// the current eased blend factor in [0,1] (0 = base, 1 = fully at target).
	// Called by the resolver for each animated, active-or-settling state.
	public float Blend(int key, int state, bool active, int durationMs, Easing curve)
	{
		ClockKey ck = .() { Widget = key, State = state };
		Clock c;
		if (!mClocks.TryGetValue(ck, out c))
			// New clock always starts at the base (P=0) and animates toward the
			// target, so a state turning active fades in rather than snapping.
			c = .() { P = 0f, Target = active, DurationMs = durationMs, Curve = curve };
		c.Target = active;
		c.DurationMs = durationMs;
		c.Curve = curve;
		mClocks[ck] = c;
		return c.Curve.Apply(c.P);
	}

	// Advance all clocks by the wall-clock delta since the last tick. Prunes
	// clocks that have settled at 0 (fully inactive) to bound the map.
	public void Tick(int nowMs)
	{
		if (mLastTickMs < 0)
			mLastTickMs = nowMs;
		let dtMs = nowMs - mLastTickMs;
		mLastTickMs = nowMs;
		if (dtMs <= 0)
			return;

		List<ClockKey> settled = scope .();
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
	}

	// True while any clock is still moving toward its target or a drag is active:
	// drives the loop to use a ~16ms frame clock instead of blocking.
	public bool NeedsTick
	{
		get
		{
			if (mDragKey != 0)
				return true;
			for (let pair in mClocks)
			{
				let c = pair.value;
				if (c.Target && c.P < 1f)
					return true;
				if (!c.Target && c.P > 0f)
					return true;
			}
			return false;
		}
	}
}
