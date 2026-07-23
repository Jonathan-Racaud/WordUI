using System;

namespace WordUI;

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

		// Components (pipeline participants)
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

		// Properties (pure data)
		for (let p in w.Properties)
		{
			let d = scope String();
			p.Describe(d);

			if (!d.IsEmpty)
			{
				if (!props.IsEmpty) props.Append(' ');
				props.Append(d);
			}
		}

		// Behaviors (event handlers)
		for (let b in w.Behaviors)
		{
			let d = scope String();
			b.Describe(d);

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

		// Read layout geometry from the retained RenderNode (survives rebuilds).
		let node = App.Instance.FindNode(w.StableKey);
		let bounds = node?.RenderNode?.Bounds;
		if (bounds != null)
		{
			if (!props.IsEmpty) props.Append(' ');
			props.Append(scope $" Rect=({bounds.Value.X},{bounds.Value.Y}, {bounds.Value.Width}x{bounds.Value.Height})");
		}

		if (!props.IsEmpty)
			line.Append(scope $"{props}");

		let kids = w.GetComponent<Children>();
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
