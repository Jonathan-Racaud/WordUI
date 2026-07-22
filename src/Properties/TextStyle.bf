using System;

namespace WordUI;

// Pure styling data for text rendering. Attached by Label/Button as defaults;
// modified by TextColor and FontSize modifier words. Read by TextComponent
// during Measure and DrawContent.
public class TextStyleProperty : Property
{
	public float FontSize = 12;
	public Color TextColor = .Black;

	public override void Describe(String buf)
	{
		buf.Append(scope $" FontSize={FontSize}");
		buf.Append(scope $" Color={TextColor}");
	}
}

extension UI
{
	public static void TextColor(Color c)
	{
		if (RecordTextColor(c)) return;
		Top("TextColor").RequireProperty<TextStyleProperty>("TextColor").TextColor = c;
	}

	public static void FontSize(float px)
	{
		if (RecordFontSize(px)) return;
		Top("FontSize").RequireProperty<TextStyleProperty>("FontSize").FontSize = px;
	}
}
