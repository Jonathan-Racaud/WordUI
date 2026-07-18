using System;

namespace PFUI;

extension UI
{
	// ( -- widget ) — flex-grow gap; the layout pass gives it leftover space.
	public static void Spacer()
	{
		NewWidget("Spacer");
	}
}
