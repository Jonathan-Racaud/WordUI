using System;

namespace WordUI;

// Interaction states are Properties that report, for a given widget identity,
// whether they are currently active. The draw-time resolver queries this to
// decide whether a recorded StatePatch applies. Implementations read from a
// tracker in the persistent InteractionStore (keyed by StableKey), so state
// survives rebuilds and never touches a freed Widget*.
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
public class PressState : Property, IInteractionState
{
	public int StateId => 1;
	public bool IsActiveFor(int ownerKey) => App.Instance.Store.IsPressed(ownerKey);

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
