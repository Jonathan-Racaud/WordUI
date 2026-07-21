using System;

namespace WordUI;

// Pure data attached to a widget: carries styling preferences, layout hints,
// interaction states — anything that other code queries but the draw pipeline
// does not iterate. Properties have no Measure, Draw*, or other pipeline hooks.
// They participate only in Describe (tree dump).
public abstract class Property
{
	// Contributes this property's detail to the tree dump. Append nothing to
	// stay silent (e.g. when all fields hold default values).
	public virtual void Describe(String buf) {}
}
