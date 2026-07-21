using System;

namespace WordUI;

extension UI
{
	// Factor's `.s`: dump the stack, top last.
	public static void PrintStack()
	{
		Console.WriteLine("--- stack ({} items, top last) ---", Stack.Count);
		for (let item in Stack)
		{
			let s = scope String();
			item.ToString(s);
			Console.WriteLine("  {}", s);
		}
	}
}
