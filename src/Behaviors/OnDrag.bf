using System;

namespace WordUI;

// Fired with the incremental pointer delta each time the pointer moves while
// this widget holds the drag capture.
public delegate void DragHandler(float dx, float dy);

extension UI
{
	// Makes the stack-top widget draggable. Attaches DragHandlerBehavior (which
	// owns the DragHandler delegate directly — one behavior, no separate holder)
	// and RenderDragOffset (the component that applies the accumulated offset
	// at draw via GetRenderOffset). On press it captures the pointer; motion
	// delivers deltas; release ends the capture. No relayout — visual follows
	// the pointer through GetRenderOffset.
	public static void OnDrag(DragHandler h)
	{
		let w = Top("OnDrag");
		var dh = w.GetBehavior<DragHandlerBehavior>();
		if (dh == null)
		{
			dh = new:BuildAlloc DragHandlerBehavior();
			w.AttachBehavior(dh);
		}
		RegisterHandler(h);
		dh.Handler = h;

		// Attach the render-offset component if not already present.
		if (w.GetComponent<RenderDragOffset>() == null)
			w.AttachComponent(new:BuildAlloc RenderDragOffset());
	}
}
