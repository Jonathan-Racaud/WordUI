using System;

namespace PFUI;

public class TextStyle : Component
{
	public String Text;
	public float FontSize = 12;
	public Color TextColor = .Black;

	public override void Describe(String buf)
	{
		buf.AppendF("\"{}\"", Text);
		if (FontSize != 12) buf.AppendF(" fontSize={}", FontSize);
		if (TextColor != .Black) buf.AppendF(" color={}", TextColor);
	}
}
