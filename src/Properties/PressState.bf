using System;

namespace WordUI;

// Tag interface for interaction states that can be queried by IfActive<T>.
// Implementations read from a tracker (PressTracker, HoverTracker, etc.)
// and return the current boolean state for the widget at CurrentBuildPosition().
public interface IInteractionState
{
	bool IsActive { get; }
}

// A Property that queries PressTracker.IsPressed for the current widget.
// Attached on demand by IfPressed; rebuild-safe (re-attachment is idempotent).
public class PressState : Property, IInteractionState
{
	public bool IsActive => PressTracker.IsPressed(UI.CurrentBuildPosition());

	public override void Describe(String buf)
	{
		buf.Append(" pressed");
	}
}

extension UI
{
	// Generic conditional: attaches T to the stack-top widget (if absent),
	// then runs body only when T.IsActive is true. Rebuild-safe: the first
	// build creates T, subsequent rebuilds find it via GetProperty.
	public static void IfActive<T>(delegate void() body)
		where T : Property, IInteractionState
	{
		let w = Top("IfActive");
		var s = w.GetProperty<T>();
		if (s == null)
		{
			s = new:BuildAlloc T();
			w.AttachProperty(s);
		}
		if (s.IsActive)
			body();
	}

	// Convenience: runs body while the stack-top widget is being pressed.
	public static void IfPressed(delegate void() body) => IfActive<PressState>(body);
}
