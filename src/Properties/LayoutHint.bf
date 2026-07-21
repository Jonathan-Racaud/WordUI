using System;

namespace WordUI;

// Cross-axis alignment of a widget within the space its parent allocates.
// Default is Stretch (fill the full cross axis); Start/Center/End position
// the widget at its intrinsic cross-axis size.
public enum CrossAlignment
{
	Stretch,
	Start,
	Center,
	End
}

// Sizing constraint a widget places on its own width or height. Communicated
// to the layout pass via LayoutHint. The Apply method returns the final size
// given an intrinsic measurement and the parent constraint.
public enum SizingConstraints
{
	case Unconstrained;
	case Fixed(float);
	case Min(float);
	case Max(float);
	case Percent(float);
	case Range(float, float);

	public float Apply(float intrinsic, float parentConstraint)
	{
		switch (this)
		{
		case .Unconstrained:
			return intrinsic;
		case .Fixed(let v):
			return v;
		case .Min(let v):
			return Math.Max(intrinsic, v);
		case .Max(let v):
			return Math.Min(intrinsic, v);
		case .Percent(let v):
			return parentConstraint * v / 100;
		case .Range(let min, let max):
			return Math.Clamp(intrinsic, min, max);
		}
	}

	public void DescribeTo(String buf, StringView label)
	{
		switch (this)
		{
		case .Unconstrained:
		case .Fixed(let v):   buf.Append(scope $" {label}=Fixed({v})");
		case .Min(let v):     buf.Append(scope $" {label}=Min({v})");
		case .Max(let v):     buf.Append(scope $" {label}=Max({v})");
		case .Percent(let v): buf.Append(scope $" {label}={v}%");
		case .Range(let min, let max): buf.Append(scope $" {label}=[{min}..{max}]");
		}
	}
}

// Pure layout preferences a child communicates to its parent's layout pass.
// Attached on demand by alignment and sizing modifier words. A Property, not a
// Component — it has no Measure, Draw, or other pipeline hooks; queried by the
// layout pass via GetProperty<LayoutHint>.
public class LayoutHint : Property
{
	public CrossAlignment CrossAlign = .Stretch;
	public SizingConstraints Width = .Unconstrained;
	public SizingConstraints Height = .Unconstrained;

	public override void Describe(String buf)
	{
		if (CrossAlign != .Stretch)
			buf.Append(scope $" CrossAlign={CrossAlign}");
		Width.DescribeTo(buf, "Width");
		Height.DescribeTo(buf, "Height");
	}
}

extension UI
{
	// Shared helper: returns the LayoutHint on the stack-top widget,
	// creating and attaching one on demand. The word name is used for
	// clear error messages when the stack top is not a widget.
	static LayoutHint GetOrCreateLayoutHint(StringView word)
	{
		let w = Top(word);
		var hint = w.GetProperty<LayoutHint>();
		if (hint == null)
		{
			hint = new:BuildAlloc LayoutHint();
			w.AttachProperty(hint);
		}
		return hint;
	}

	// ---- Cross-axis alignment ----

	public static void Center()
	{
		GetOrCreateLayoutHint("Center").CrossAlign = .Center;
	}

	public static void AlignStart()
	{
		GetOrCreateLayoutHint("AlignStart").CrossAlign = .Start;
	}

	public static void AlignEnd()
	{
		GetOrCreateLayoutHint("AlignEnd").CrossAlign = .End;
	}

	public static void AlignStretch()
	{
		GetOrCreateLayoutHint("AlignStretch").CrossAlign = .Stretch;
	}

	// ---- Sizing constraints ----

	public static void Width(SizingConstraints c)
	{
		GetOrCreateLayoutHint("Width").Width = c;
	}

	public static void Height(SizingConstraints c)
	{
		GetOrCreateLayoutHint("Height").Height = c;
	}

	// Convenience: set both axes to Fixed. FixedSize(200) is the square
	// shorthand; FixedSize(200, 100) sets width and height independently.
	public static void FixedSize(float wh)
	{
		Width(.Fixed(wh));
		Height(.Fixed(wh));
	}

	public static void FixedSize(float w, float h)
	{
		Width(.Fixed(w));
		Height(.Fixed(h));
	}
}
