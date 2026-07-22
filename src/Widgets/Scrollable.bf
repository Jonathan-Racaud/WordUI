using System;

namespace WordUI;

extension UI
{
	// A Scrollable is a stack (default vertical) that carries a ScrollView marker,
	// so the wheel scrolls its children and its scroll offset survives rebuilds.
	// It does NOT clip on its own — compose `Scrollable(...); Clip();` to hide
	// overflow, and set the axis with `Horizontal()`/`Vertical()`. Give it a
	// bounded main-axis size (e.g. `Height(.Fixed(240))`) so its content overflows
	// the viewport rather than the container growing to fit.
	//
	// Built from the same paired-primitive container idiom as HStack/VStack (see
	// Widgets/Stack.bf): _Scrollable() opens the marker, Scrollable_() closes it.
	public static void _Scrollable() { OpenContainer("Scrollable"); }

	public static void Scrollable_()
	{
		NewWidget("Scrollable");
		AttachComponent(new:BuildAlloc StackLayout() { Axis = .Vertical });
		AttachComponent(new:BuildAlloc ScrollView());
		CloseContainer("Scrollable");
	}

	public static void Scrollable(delegate void() body) { _Scrollable(); body(); Scrollable_(); }
}
