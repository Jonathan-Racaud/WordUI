using System;

namespace WordUI;

// Interaction states are Properties that report, for a given widget identity,
// whether they are currently active. The draw-time resolver queries this to
// decide whether a recorded StatePatch applies. Implementations read from
// the retained Node tree (keyed by StableKey), so state survives rebuilds
// and never touches a freed Widget*.
//
// StateId must be a stable, unique small int per state type: it keys the
// animation clock so a transition keeps its progress across rebuilds. User
// states pick their own id (framework reserves 1..99).
public interface IInteractionState
{
	int StateId { get; }
	bool IsActiveFor(int ownerKey);
}

// Active while the widget at ownerKey is being pressed.
// Queries the retained Node for SlotPress (slot 2) via App.FindNode.
public class PressState : Property, IInteractionState
{
	public int StateId => 1;
	public bool IsActiveFor(int ownerKey)
	{
		let node = App.Instance.FindNode(ownerKey);
		return node != null && node.GetBool(PressTracker.SlotPress);
	}

	public override void Describe(String buf)
	{
		buf.Append(" pressed");
	}
}

extension UI
{
	// Convenience: records the enclosed styling while the widget is pressed.
	public static void IfPressed(delegate void() body) => IfActive<PressState>(body);
}
