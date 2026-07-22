using System;

namespace WordUI;

// Marker component: a widget carrying a ScrollView offsets its children along its
// StackLayout axis by a persistent scroll offset stored in the InteractionStore
// (keyed by StableKey, so it survives rebuilds — the M4 exit criterion). The
// offset is folded into the render-time (ox,oy) in SDLApp.DrawWidget, reusing the
// exact translation mechanism drag already uses; no relayout happens.
//
// A pure marker: it stores nothing itself. The scroll offset lives in the store;
// the content extent used to clamp it is derived from the child rects at wheel
// time by ScrollTracker.
public class ScrollView : Component
{
	public override void Describe(String buf)
	{
		buf.Append(" Scroll");
	}
}
