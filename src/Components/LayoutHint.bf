using System;

namespace PFUI;

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

// Carries layout preferences a child communicates to its parent's layout pass.
// Attached on demand by alignment modifier words (Center, AlignStart, etc.).
public class LayoutHint : Component
{
	public CrossAlignment CrossAlign = .Stretch;

	public override void Describe(String buf)
	{
		if (CrossAlign != .Stretch)
			buf.Append(scope $" CrossAlign={CrossAlign}");
	}
}
