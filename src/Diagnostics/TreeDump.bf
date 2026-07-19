using System;

namespace PFUI;

// Stand-in renderer: indented dump of the current tree. Fully generic — a
// user-defined component appears here through its Describe override without
// the framework knowing it exists.
extension App
{
	public void DumpTree()
	{
		Console.WriteLine("# ---- [UI Tree Dump] ---- #");
		if (mRoot == null)
		{
			Console.WriteLine("(no tree — call RebuildIfNeeded first)");
			return;
		}
		Dump(mRoot, 0);
		Console.WriteLine("# ---- [/UI Tree Dump] ---- #");
	}

	static void Dump(Widget w, int depth)
	{
		let line = scope String();
		line.Append(' ', depth * 2);
		line.Append(scope $"<{w.Name}");

		let props = scope String();
		for (let c in w.Components)
		{
			let d = scope String();
			c.Describe(d);

			if (!d.IsEmpty)
			{
				if (!props.IsEmpty) props.Append(' ');
				props.Append(d);
			}
		}

		if (!props.IsEmpty) props.Append(' ');
		props.AppendF(" Padding={}", w.Padding);

		if (!props.IsEmpty) props.Append(' ');
		props.AppendF(scope $" Key={w.Key}");

		if (!props.IsEmpty) props.Append(' ');
		props.Append(scope $" Rect=({w.mRect.X},{w.mRect.Y}, {w.mRect.Width}x{w.mRect.Height})");

		if (!props.IsEmpty)
			line.Append(scope $"{props}");

		let kids = w.Get<Children>();
		if (kids != null)
		{
			Console.WriteLine(scope $"{line}>");

			for (let child in kids.Items)
				Dump(child, depth + 1);

			Console.Write(scope String(' ', depth * 2));
			Console.WriteLine(scope $"</{w.Name}>");
		} else {
			Console.WriteLine(scope $"{line}/>");
		}
	}
}
