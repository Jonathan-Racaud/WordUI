using System;

namespace WordUI;

extension UI
{
	// Shared helper: returns the LayoutHint on the stack-top widget,
	// creating and attaching one on demand. The word name is used for
	// clear error messages when the stack top is not a widget.
	static LayoutHint GetOrCreateLayoutHint(StringView word)
	{
		let w = Top(word);
		var hint = w.Get<LayoutHint>();
		if (hint == null)
		{
			hint = new:BuildAlloc LayoutHint();
			w.Attach(hint);
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
