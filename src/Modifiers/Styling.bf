using System;

namespace WordUI;

extension UI
{
	// ---- Interior pen: Background() ----

	// ( -- marker pen ) pushes a marker and a fresh Interior pen. Property
	// words that follow (Fill, Radius) mutate the pen on the stack top.
	public static void _Interior()
	{
		OpenContainer("Interior");
		PushPen(new:BuildAlloc Interior());
	}

	// Pops the pen, pops the matching marker, attaches the Interior to the
	// widget below the marker (the stack-top widget when the block opened).
	public static void Interior_()
	{
		let pen = ClosePen("Interior");
		let interior = pen as Interior;
		if (interior == null)
			Fail("Interior_", "expected an Interior pen on the stack");
		ReplaceComponent(interior);
	}

	public static void Background(delegate void() body)
	{
		// Inside a state body there is no pen to open; the enclosed Fill/Radius
		// record onto the patch instead. (Radius is not yet an animatable field
		// and is ignored in patch mode.)
		if (InPatch) { body(); return; }
		_Interior();
		body();
		Interior_();
	}

	// ---- Border pen: Border() ----

	public static void _Border()
	{
		OpenContainer("Border");
		PushPen(new:BuildAlloc Boundary());
	}

	public static void Border_()
	{
		let pen = ClosePen("Border");
		let boundary = pen as Boundary;
		if (boundary == null)
			Fail("Border_", "expected a Boundary pen on the stack");
		ReplaceComponent(boundary);
	}

	public static void Border(delegate void() body)
	{
		if (InPatch) { body(); return; }
		_Border();
		body();
		Border_();
	}

	// ---- Pen property words ----

	public static void Fill(Color c)
	{
		if (RecordFill(c)) return;
		let pen = TopPen("Fill");
		let i = pen as Interior;
		if (i == null)
			Fail("Fill", "no active Interior — are you inside a Background block?");
		i.FillColor = c;
	}

	public static void Stroke(Color c)
	{
		if (RecordStroke(c)) return;
		let pen = TopPen("Stroke");
		let b = pen as Boundary;
		if (b == null)
			Fail("Stroke", "no active Border — are you inside a Border block?");
		b.StrokeColor = c;
	}

	public static void Radius(float r)
	{
		if (InPatch) return;   // radius is not an animatable patch field yet
		let pen = TopPen("Radius");
		let i = pen as Interior;
		if (i != null)
			i.Radius = r;
		else
		{
			let b = pen as Boundary;
			if (b != null)
				b.Radius = r;
			else
				Fail("Radius", "no active pen — are you inside a Background or Border block?");
		}
	}

	public static void StrokeWidth(float w)
	{
		if (RecordStrokeWidth(w)) return;
		let pen = TopPen("StrokeWidth");
		let b = pen as Boundary;
		if (b == null)
			Fail("StrokeWidth", "no active Border — are you inside a Border block?");
		b.StrokeWidth = w;
	}
}
