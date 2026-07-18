using System;

namespace PFUI;

extension UI
{
	// Stable identity for list items; becomes the persistent-state key once
	// widget-local state (scroll, focus, animations) exists.
	public static void Key(int id)
	{
		Top("Key").Key = id;
	}
}
