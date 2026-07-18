using System;

namespace PFUI;

// The single inheritance point of the framework. A component carries one
// capability's data and overrides framework hooks for its behavior. Framework
// components and user components are peers: every pass dispatches through the
// same virtual hooks, so a user's component participates in diagnostics (and
// later layout/rendering) without any registration step.
public abstract class Component
{
	// Contributes this component's detail to the tree dump. Append nothing to
	// stay silent (e.g. when all fields hold default values).
	public virtual void Describe(String buf) {}

	// Future hooks, added alongside their phases:
	//   Measure — intrinsic sizing for the layout pass
	//   Draw    — custom drawing for the render pass
}
