using System;
using System.Collections;

namespace WordUI;

// A field-level style delta produced by a state body (IfHover/IfPressed/...).
// Unlike the old layer variants — which cloned a whole Property and replaced it
// wholesale — a patch records only the individual fields the body touched, so
// two concurrently-active states that set different fields (hover→FontSize,
// focus→TextColor) COMPOSE at draw instead of one clobbering the other.
//
// Per-field `*Anim` flags mark fields recorded inside a Transition(); the whole
// patch shares one Duration/Curve (last Transition wins). Non-animated fields
// apply instantly when their state is active.
class StatePatch
{
	// Interior fill
	public bool HasFill; public Color Fill; public bool FillAnim;
	// Text
	public bool HasTextColor; public Color TextColor; public bool TextColorAnim;
	public bool HasFontSize; public float FontSize; public bool FontSizeAnim;
	// Border stroke
	public bool HasStroke; public Color Stroke; public bool StrokeAnim;
	public bool HasStrokeWidth; public float StrokeWidth; public bool StrokeWidthAnim;

	// Shared animation parameters for the animated fields in this patch.
	public int DurationMs = 150;
	public Easing Curve = .EaseInOut;
}

// One recorded patch plus the state that gates it. `State.IsActiveFor(key)`
// (read from the InteractionStore at draw) decides whether/how strongly the
// patch applies.
struct PatchRecord
{
	public IInteractionState State;
	public StatePatch Patch;
}

// The single generic property that carries every interaction variant for a
// widget. Replaces the plan's per-Component/per-Property layer integer: one
// property, no state-specific fields on the base model.
class InteractionStyle : Property
{
	public List<PatchRecord> Records;

	public override void Describe(String buf)
	{
		if (Records != null && !Records.IsEmpty)
			buf.AppendF(" states={}", Records.Count);
	}
}
