using System;

namespace WordUI;

extension UI
{
	// ( str -- widget ) — a button is a styled label with default interior,
	// border, and padding. Clickability arrives when OnClick attaches a Clickable.
	//
	// Factored word: any property can be overridden by re-focusing after the
	// word, e.g.:
	//   Button("Delete"); Background(scope () => { Fill(.Red); Radius(6); });
	public static void Button()
	{
		let text = PopStr("Button");
		NewWidget("Button");
		Attach(new:BuildAlloc TextStyle() { Text = text });
		Background(scope () => { Fill(.(80, 80, 80, 255)); Radius(4); });
		Border(scope () => { Stroke(.(120, 120, 120, 255)); StrokeWidth(1); Radius(4); });
		Padding(8);
	}

	public static void Button(StringView text) { Str(text); Button(); }
}
