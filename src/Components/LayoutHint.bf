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

// Carries layout preferences a child communicates to its parent's layout pass.
// Attached on demand by alignment and sizing modifier words.
public class LayoutHint : Component
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
