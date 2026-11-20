using System;

namespace WordUI;

// Marker component: a widget carrying a ClipRegion clips its children's drawing
// to its own bounds. A pure marker with no data — the clip is applied centrally
// in App.DrawWidget (which brackets the children recurse with the painter's
// clip stack), the same place the drag/scroll render offset is folded in.
//
// Clipping is its own composable capability, independent of scroll: Clip() works
// on any container. A Scrollable() that should hide its overflow composes the two
// (`Scrollable(...); Clip();`).
public class ClipRegion : Component
{
	public override void Describe(String buf)
	{
		buf.Append(" Clip");
	}
}

extension UI
{
	// ( widget -- widget ) — clip the stack-top container's children to its box.
	public static void Clip()
	{
		Top("Clip").AttachComponent(new:BuildAlloc ClipRegion());
	}
}
