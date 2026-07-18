using System;

namespace PFUI;

public enum Axis
{
	Horizontal,
	Vertical
}

public class StackLayout : Component
{
	public Axis Axis;
	public float Spacing;

	public override void Describe(String buf)
	{
		if (Spacing != 0) buf.AppendF("spacing={}", Spacing);
	}
}
