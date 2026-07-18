using System;

namespace PFUI;

// Stand-in renderer: indented dump of the current tree. Fully generic — a
// user-defined component appears here through its Describe override without
// the framework knowing it exists.
extension App
{
	public void DumpTree()
	{
		if (mRoot == null)
		{
			Console.WriteLine("(no tree — call RebuildIfNeeded first)");
			return;
		}
		Dump(mRoot, 0);
	}

	static void Dump(Widget w, int depth)
	{
		let line = scope String();
		line.Append(' ', depth * 2);
		line.Append(w.Name);

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
		if (w.Padding != 0)
		{
			if (!props.IsEmpty) props.Append(' ');
			props.AppendF("padding={}", w.Padding);
		}
		if (w.Key != -1)
		{
			if (!props.IsEmpty) props.Append(' ');
			props.AppendF("key={}", w.Key);
		}
		if (!props.IsEmpty)
			line.AppendF(" ({})", props);

		Console.WriteLine(line);

		let kids = w.Get<Children>();
		if (kids != null)
		{
			for (let child in kids.Items)
				Dump(child, depth + 1);
		}
	}
}
