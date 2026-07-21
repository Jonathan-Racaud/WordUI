using System;

namespace WordUI;

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
		buf.Append(scope $" Axis={Axis} Spacing={Spacing}");
	}
}
