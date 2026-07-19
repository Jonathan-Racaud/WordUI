using System;

namespace PFUI;

// Flex layout pass: constraints-down, sizes-up, sum-main/max-cross,
// leftover→Spacer. Runs after Build(), stores a Rect on every widget.
static class Layout
{
	// Entry point: lay out the entire tree within the given rect.
	public static void Run(Rect available, Widget root)
	{
		LayoutWidget(available, root);
	}

	static void LayoutWidget(Rect available, Widget widget)
	{
		widget.mRect = available;

		let children = widget.Get<Children>();
		if (children == null)
			return;

		let stack = widget.Get<StackLayout>();
		if (stack == null)
			return;

		// Compute inner rect (available minus padding)
		float pad = widget.Padding;
		Rect inner = .(
			available.X + pad,
			available.Y + pad,
			available.Width - 2 * pad,
			available.Height - 2 * pad
		);

		bool isVertical = stack.Axis == .Vertical;

		// Count spacers and measure non-spacer children
		int spacerCount = 0;
		int itemCount = children.Items.Count;
		float[] sizes = scope float[itemCount];

		float totalMain = 0;
		float maxCross = 0;

		for (int i = 0; i < itemCount; i++)
		{
			let child = children.Items[i];
			if (child.Name == "Spacer")
			{
				spacerCount++;
				sizes[i] = -1; // marker
				continue;
			}

			Size constraint = isVertical
				? .(inner.Width, float.MaxValue)
				: .(float.MaxValue, inner.Height);

			let size = MeasureWidget(child, constraint);
			float main = isVertical ? size.Height : size.Width;
			float cross = isVertical ? size.Width : size.Height;
			sizes[i] = main;
			totalMain += main;
			maxCross = Math.Max(maxCross, cross);
		}

		// Spacing between non-spacer items
		int nonSpacerCount = itemCount - spacerCount;
		if (nonSpacerCount > 1)
			totalMain += stack.Spacing * (nonSpacerCount - 1);

		// Distribute leftover main-axis space to spacers
		float mainAvailable = isVertical ? inner.Height : inner.Width;
		float leftover = mainAvailable - totalMain;
		float spacerSize = spacerCount > 0
			? Math.Max(0, leftover / spacerCount)
			: 0;

		// Assign rects to children
		float mainPos = isVertical ? inner.Y : inner.X;

		for (int i = 0; i < itemCount; i++)
		{
			let child = children.Items[i];

			if (child.Name == "Spacer")
			{
				child.mRect = isVertical
					? Rect(inner.X, mainPos, inner.Width, spacerSize)
					: Rect(mainPos, inner.Y, spacerSize, inner.Height);
				mainPos += spacerSize;
				continue;
			}

			float childMain = sizes[i];
			float childCross = isVertical ? inner.Width : inner.Height;

			Rect childRect = isVertical
				? Rect(inner.X, mainPos, childCross, childMain)
				: Rect(mainPos, inner.Y, childMain, childCross);

			LayoutWidget(childRect, child); // recurse

			mainPos += childMain + stack.Spacing;
		}
	}

	// Measure a widget's intrinsic size by asking each component.
	static Size MeasureWidget(Widget widget, Size constraint)
	{
		float w = 0, h = 0;
		for (let c in widget.Components)
		{
			let size = c.Measure(constraint);
			w = Math.Max(w, size.Width);
			h = Math.Max(h, size.Height);
		}
		w += widget.Padding * 2;
		h += widget.Padding * 2;
		return .(w, h);
	}
}
