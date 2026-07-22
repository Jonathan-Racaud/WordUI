using System;

namespace WordUI;

// Draw-time style resolution. Drawing components call these with their base
// value; the resolver blends every active (or still-animating) patch over it,
// field by field, so concurrent states compose. Animated fields interpolate via
// the persistent clock in the retained Node tree, which is what lets a transition
// survive a rebuild and keep the frame loop ticking.
enum ColorField { Fill, Stroke, TextColor }
enum FloatField { FontSize, StrokeWidth }

static class StyleResolve
{
	public static Color Color(Widget w, Color baseValue, ColorField field)
	{
		let style = w.GetProperty<InteractionStyle>();
		if (style == null || style.Records == null)
			return baseValue;

		Color result = baseValue;
		for (let rec in style.Records)
		{
			if (!HasColor(rec.Patch, field, let target, let anim))
				continue;
			let factor = Factor(w, rec, anim);
			if (factor <= 0f)
				continue;
			result = WordUI.Color.Lerp(result, target, factor);
		}
		return result;
	}

	public static float Float(Widget w, float baseValue, FloatField field)
	{
		let style = w.GetProperty<InteractionStyle>();
		if (style == null || style.Records == null)
			return baseValue;

		float result = baseValue;
		for (let rec in style.Records)
		{
			if (!HasFloat(rec.Patch, field, let target, let anim))
				continue;
			let factor = Factor(w, rec, anim);
			if (factor <= 0f)
				continue;
			result = Lerp.F(result, target, factor);
		}
		return result;
	}

	// Blend strength for one record: 1/0 instantly for non-animated fields,
	// or the eased clock value for animated ones (which also advances/keeps the
	// loop alive while settling).
	static float Factor(Widget w, PatchRecord rec, bool anim)
	{
		let active = rec.State.IsActiveFor(w.StableKey);
		if (!anim)
			return active ? 1f : 0f;
		let node = App.Instance.FindNode(w.StableKey);
		return node != null
			? node.Blend(rec.State.StateId, active, rec.Patch.DurationMs, rec.Patch.Curve)
			: 0f;
	}

	static bool HasColor(StatePatch p, ColorField field, out Color value, out bool anim)
	{
		switch (field)
		{
		case .Fill:      value = p.Fill;      anim = p.FillAnim;      return p.HasFill;
		case .Stroke:    value = p.Stroke;    anim = p.StrokeAnim;    return p.HasStroke;
		case .TextColor: value = p.TextColor; anim = p.TextColorAnim; return p.HasTextColor;
		}
	}

	static bool HasFloat(StatePatch p, FloatField field, out float value, out bool anim)
	{
		switch (field)
		{
		case .FontSize:    value = p.FontSize;    anim = p.FontSizeAnim;    return p.HasFontSize;
		case .StrokeWidth: value = p.StrokeWidth; anim = p.StrokeWidthAnim; return p.HasStrokeWidth;
		}
	}
}
