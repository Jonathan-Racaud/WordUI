using System;

namespace WordUI;

extension UI
{
	public static void _HStack() { OpenContainer("HStack"); }

	public static void HStack_()
	{
		NewWidget("HStack");
		AttachComponent(new:BuildAlloc StackLayout() { Axis = .Horizontal });
		CloseContainer("HStack");
	}

	public static void HStack(delegate void() body) { _HStack(); body(); HStack_(); }

	public static void _VStack() { OpenContainer("VStack"); }

	public static void VStack_()
	{
		NewWidget("VStack");
		AttachComponent(new:BuildAlloc StackLayout() { Axis = .Vertical });
		CloseContainer("VStack");
	}

	public static void VStack(delegate void() body) { _VStack(); body(); VStack_(); }
}
