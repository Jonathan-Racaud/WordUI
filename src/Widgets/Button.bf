using System;

namespace PFUI;

extension UI
{
	// ( str -- widget ) — a button is styled text plus expectations; clickability
	// arrives when OnClick attaches a Clickable.
	public static void Button()
	{
		let text = PopStr("Button");
		NewWidget("Button");
		Attach(new:BuildAlloc TextStyle() { Text = text });
	}

	public static void Button(StringView text) { Str(text); Button(); }
}
