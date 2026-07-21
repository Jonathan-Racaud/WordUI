using System;

namespace WordUI;

extension UI
{
	// Padding is universal — every widget participates in flow layout.
	public static void Padding(float all)
	{
		Top("Padding").Padding = all;
	}

	public static void Spacing(float px)
	{
		Top("Spacing").Require<StackLayout>("Spacing").Spacing = px;
	}
}
