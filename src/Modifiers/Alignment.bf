using System;

namespace PFUI;

extension UI
{
	// Cross-axis child alignment words. Each GetOrCreates a LayoutHint on
	// the stack-top widget and sets the alignment. The parent layout pass
	// reads LayoutHint to position the child on the cross axis.

	public static void Center()
	{
		let w = Top("Center");
		var hint = w.Get<LayoutHint>();
		if (hint == null)
		{
			hint = new:BuildAlloc LayoutHint();
			w.Attach(hint);
		}
		hint.CrossAlign = .Center;
	}

	public static void AlignStart()
	{
		let w = Top("AlignStart");
		var hint = w.Get<LayoutHint>();
		if (hint == null)
		{
			hint = new:BuildAlloc LayoutHint();
			w.Attach(hint);
		}
		hint.CrossAlign = .Start;
	}

	public static void AlignEnd()
	{
		let w = Top("AlignEnd");
		var hint = w.Get<LayoutHint>();
		if (hint == null)
		{
			hint = new:BuildAlloc LayoutHint();
			w.Attach(hint);
		}
		hint.CrossAlign = .End;
	}

	public static void AlignStretch()
	{
		let w = Top("AlignStretch");
		var hint = w.Get<LayoutHint>();
		if (hint == null)
		{
			hint = new:BuildAlloc LayoutHint();
			w.Attach(hint);
		}
		hint.CrossAlign = .Stretch;
	}
}
