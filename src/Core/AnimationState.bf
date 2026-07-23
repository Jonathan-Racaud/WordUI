using System;
using System.Collections;

namespace WordUI;

// Retained animation-clock manager for a single Node. Created lazily on first
// animated state-blend and registered as an ITickable on the node. Manages a
// pool of per-StateId clocks — each clock tracks eased progress toward a
// boolean target over a duration with an easing curve. Self-prunes clocks that
// settle at P=0 with Target=false (fully inactive, no longer needed).
//
// StyleResolve.Factor() fetches this via node.GetTickable<AnimationState>()
// and calls Blend() for each animated patch record. The draw loop is the only
// consumer; layout never queries clocks.
//
// Memory: heap-allocated (new), owned by the Node's mTickables list via the
// ITickable registration. Deleted by Node.Dispose() during the tickable
// snapshot-delete pass. The destructor unregisters from the node.
public class AnimationState : ITickable
{
	// Per-stateId clock: eased progress P moves toward Target=1 or Target=0
	// at a rate of 1/DurationMs per tick. When Target=false and P reaches 0,
	// the clock is pruned (removed from mClocks).
	struct Clock
	{
		public float P;          // current eased-input progress, [0,1]
		public bool Target;      // true = animate toward 1, false = toward 0
		public int DurationMs;
		public Easing Curve;
	}

	Dictionary<int, Clock> mClocks = new .() ~ delete _;
	Node mNode;

	public this(Node node)
	{
		mNode = node;
	}

	public ~this()
	{
		if (mNode != null)
		{
			mNode.UnregisterTickable(this);
			mNode = null;
		}
	}

	// ---- ITickable ----

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
			return false;
		}
	}

	public void Tick(int dtMs)
	{
		if (dtMs <= 0)
			return;

		// Collect-then-apply: never mutate mClocks while iterating it.
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
	}

	// ---- Blend API ----

	// Ensure a clock exists for `stateId`, update its target/params, and return
	// the current eased blend factor in [0,1] (0 = base, 1 = fully at target).
	// Called by StyleResolve.Factor() at draw time for each animated patch.
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

	// ---- Static helpers ----

	// Returns the AnimationState for a node, creating and registering it
	// lazily on first access. Returns null when node is null.
	public static AnimationState Get(Node node)
	{
		if (node == null)
			return null;
		for (let t in node.Tickables)
		{
			let existing = t as AnimationState;
			if (existing != null)
				return existing;
		}
		let created = new AnimationState(node);
		node.RegisterTickable(created);
		return created;
	}
}
