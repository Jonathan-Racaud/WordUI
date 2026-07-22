using System;

namespace WordUI;

// Fired with the incremental pointer delta each time the pointer moves while
// this widget holds the drag capture.
public delegate void DragHandler(float dx, float dy);

public class OnDragBehavior : Behavior
{
	public DragHandler Handler;

	public override void Describe(String buf)
	{
		buf.Append(" OnDrag");
	}
}

extension UI
{
	// Makes the stack-top widget draggable. On press it captures the pointer;
	// motion delivers deltas here and offsets the widget at draw (no relayout);
	// release ends the capture. Capture means events keep routing here even when
	// the pointer leaves the widget's rect.
	public static void OnDrag(DragHandler h)
	{
		let w = Top("OnDrag");
		var b = w.GetBehavior<OnDragBehavior>();
		if (b == null)
		{
			b = new:BuildAlloc OnDragBehavior();
			w.AttachBehavior(b);
		}
		RegisterHandler(h);
		b.Handler = h;
	}
}
