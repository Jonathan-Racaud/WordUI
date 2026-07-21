using System;

namespace WordUI;

extension UI
{
	// ( str -- widget )
	public static void Label()
	{
		let text = PopStr("Label");   // inputs first, then the widget
		NewWidget("Label");
		AttachComponent(new:BuildAlloc TextComponent() { Content = text });
		AttachProperty(new:BuildAlloc TextStyleProperty() { FontSize = 12, TextColor = .Black });
	}

	public static void Label(StringView s) { Str(s); Label(); }
}
