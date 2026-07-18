using System;
using System.Collections;

namespace PFUI;

// Rebuild-on-invalidate driver: `Build()` re-runs only after `Invalidate()`,
// producing a fresh widget tree in a bump arena; the previous tree (widgets,
// string copies, children lists) is freed wholesale by deleting the arena.
// Handlers passed to OnClick are owned by the framework and freed on rebuild;
// they are only ever invoked against the current tree, so this is safe.
public abstract class App
{
	BumpAllocator mArena ~ delete _;
	List<ClickHandler> mHandlers = new .() ~ { ClearHandlers(); delete _; };
	Widget mRoot;
	bool mDirty = true;

	protected abstract void Build();

	public void Invalidate() { mDirty = true; }

	// Returns true if a rebuild happened.
	public bool RebuildIfNeeded()
	{
		if (!mDirty)
			return false;

		mRoot = null;
		DeleteAndNullify!(mArena);   // frees the entire previous tree
		ClearHandlers();
		mArena = new BumpAllocator();

		UI.BeginBuild(mArena, mHandlers);
		Build();
		mRoot = UI.EndBuild();
		mDirty = false;
		return true;
	}

	// Stand-in renderer: indented dump of the current tree.
	public void DumpTree()
	{
		if (mRoot == null)
		{
			Console.WriteLine("(no tree — call RebuildIfNeeded first)");
			return;
		}
		DumpWidget(mRoot, 0);
	}

	// Simulates a click on the first Button whose text matches; returns whether
	// a handler ran. Stands in for hit-testing until a real renderer exists.
	public bool SimulateClick(StringView buttonText)
	{
		return ClickIn(mRoot, buttonText);
	}

	void ClearHandlers()
	{
		for (let h in mHandlers)
			delete h;
		mHandlers.Clear();
	}

	static bool ClickIn(Widget w, StringView buttonText)
	{
		if (w == null)
			return false;
		if (w.Kind == .Button && w.Text == buttonText && w.OnClick != null)
		{
			w.OnClick();
			return true;
		}
		if (w.Children != null)
		{
			for (let child in w.Children)
			{
				if (ClickIn(child, buttonText))
					return true;
			}
		}
		return false;
	}

	static void DumpWidget(Widget w, int depth)
	{
		let line = scope String();
		line.Append(' ', depth * 2);
		line.Append(UI.KindName(w.Kind));

		if (w.Text != null)
			line.AppendF(" \"{}\"", w.Text);

		let props = scope String();
		if (w.FontSize != 12) props.AppendF("fontSize={} ", w.FontSize);
		if (w.TextColor != .Black) props.AppendF("color={} ", w.TextColor);
		if (w.Padding != 0) props.AppendF("padding={} ", w.Padding);
		if (w.Spacing != 0) props.AppendF("spacing={} ", w.Spacing);
		if (w.OnClick != null) props.Append("clickable ");
		if (w.Key != -1) props.AppendF("key={} ", w.Key);
		if (!props.IsEmpty)
		{
			props.TrimEnd();
			line.AppendF(" ({})", props);
		}

		Console.WriteLine(line);

		if (w.Children != null)
		{
			for (let child in w.Children)
				DumpWidget(child, depth + 1);
		}
	}
}
