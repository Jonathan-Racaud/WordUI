using System;

namespace PFUI;

extension UI
{
	// ( str -- widget )
	public static void Label()
	{
		let text = PopStr("Label");   // inputs first, then the widget
		NewWidget("Label");
		Attach(new:BuildAlloc TextStyle() { Text = text });
	}

	public static void Label(StringView s) { Str(s); Label(); }
}
