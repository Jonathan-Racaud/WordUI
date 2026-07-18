using System;

namespace PFUI;

extension UI
{
	public static void TextColor(Color c)
	{
		Top("TextColor").Require<TextStyle>("TextColor").TextColor = c;
	}

	public static void FontSize(float px)
	{
		Top("FontSize").Require<TextStyle>("FontSize").FontSize = px;
	}
}
