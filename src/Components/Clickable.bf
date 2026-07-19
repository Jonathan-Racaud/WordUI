using System;

namespace PFUI;

public delegate void ClickHandler();

public class Clickable : Component
{
	public ClickHandler Handler;

	public override void Describe(String buf)
	{
		buf.Append(" Clickable");
	}
}
