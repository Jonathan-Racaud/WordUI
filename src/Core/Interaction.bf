using System;
using System.Collections;

namespace WordUI;

// Patch-recording core for Option A. A state body (IfActive / IfHover / ...)
// always runs at build, but its styling words don't mutate base components —
// they record a field-level StatePatch onto the widget's InteractionStyle. The
// draw-time resolver later blends active patches over the base values.
extension UI
{
	// Active recording target. Non-null only while a state body runs.
	[ThreadStatic] static StatePatch sPatch;
	[ThreadStatic] static bool sPatchAnim;   // true inside a Transition() block

	public static bool InPatch => sPatch != null;

	// ---- Generic conditional (the user-extensible primitive) ----

	// Always runs body, recording a patch tagged with state T. Whether the patch
	// applies (and how strongly, when animated) is decided at draw by
	// T.IsActiveFor(widget.StableKey) against the InteractionStore.
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

		let prevPatch = sPatch;
		let prevAnim = sPatchAnim;
		sPatch = new:BuildAlloc StatePatch();
		sPatchAnim = false;

		body();

		RecordPatch(w, s, sPatch);
		sPatch = prevPatch;
		sPatchAnim = prevAnim;
	}

	// ---- Animation ----

	// Marks the fields recorded inside body as animated with the given duration
	// (and curve). Outside a state body it is a transparent pass-through.
	public static void Transition(int ms, delegate void() body)
	{
		Transition(ms, .EaseInOut, body);
	}

	public static void Transition(int ms, Easing curve, delegate void() body)
	{
		if (sPatch == null) { body(); return; }
		let prevAnim = sPatchAnim;
		sPatchAnim = true;
		sPatch.DurationMs = ms;
		sPatch.Curve = curve;
		body();
		sPatchAnim = prevAnim;
	}

	// ---- Record helpers (called by styling words when InPatch) ----
	// Each returns true when it consumed the value, so the word early-returns
	// instead of running its normal base-mutation path.

	public static bool RecordFill(Color c)
	{
		if (sPatch == null) return false;
		sPatch.HasFill = true; sPatch.Fill = c; sPatch.FillAnim = sPatchAnim;
		return true;
	}

	public static bool RecordStroke(Color c)
	{
		if (sPatch == null) return false;
		sPatch.HasStroke = true; sPatch.Stroke = c; sPatch.StrokeAnim = sPatchAnim;
		return true;
	}

	public static bool RecordStrokeWidth(float w)
	{
		if (sPatch == null) return false;
		sPatch.HasStrokeWidth = true; sPatch.StrokeWidth = w; sPatch.StrokeWidthAnim = sPatchAnim;
		return true;
	}

	public static bool RecordTextColor(Color c)
	{
		if (sPatch == null) return false;
		sPatch.HasTextColor = true; sPatch.TextColor = c; sPatch.TextColorAnim = sPatchAnim;
		return true;
	}

	public static bool RecordFontSize(float px)
	{
		if (sPatch == null) return false;
		sPatch.HasFontSize = true; sPatch.FontSize = px; sPatch.FontSizeAnim = sPatchAnim;
		return true;
	}

	static void RecordPatch(Widget w, IInteractionState state, StatePatch patch)
	{
		var style = w.GetProperty<InteractionStyle>();
		if (style == null)
		{
			style = new:BuildAlloc InteractionStyle();
			style.Records = new:BuildAlloc List<PatchRecord>();
			w.AttachProperty(style);
		}
		style.Records.Add(.() { State = state, Patch = patch });
	}
}
