using System;

namespace WordUI;

// Event handler attached to a widget: carries a delegate the runtime invokes
// when an event (click, hover, focus, etc.) fires. Behaviors have no Measure,
// Draw*, or other pipeline hooks. They participate only in Describe (tree dump)
// and are iterated by the input system during event dispatch.
public abstract class Behavior
{
	// Contributes this behavior's detail to the tree dump. Append nothing to
	// stay silent (e.g. when all fields hold default values).
	public virtual void Describe(String buf) {}
}
