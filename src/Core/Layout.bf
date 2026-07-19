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
		float[] mainSizes = scope float[itemCount];
		float[] crossSizes = scope float[itemCount];

		float totalMain = 0;
		float maxCross = 0;

		for (int i = 0; i < itemCount; i++)
		{
			let child = children.Items[i];
			if (child.Name == "Spacer")
			{
				spacerCount++;
				mainSizes[i] = -1; // marker
				continue;
			}

			Size constraint = isVertical
				? .(inner.Width, float.MaxValue)
				: .(float.MaxValue, inner.Height);

			let size = MeasureWidget(child, constraint);
			float main = isVertical ? size.Height : size.Width;
			float cross = isVertical ? size.Width : size.Height;
			mainSizes[i] = main;
			crossSizes[i] = cross;
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

			float childMain = mainSizes[i];
			float childCrossAvailable = isVertical ? inner.Width : inner.Height;
			float childCrossSize = crossSizes[i];

			// Apply cross-axis alignment from LayoutHint (default: Stretch).
			// A sizing constraint on the cross axis overrides Stretch so that
			// e.g. Height(.Fixed(20)) inside an HStack produces a 20px-tall
			// child instead of forcing it to fill the row height.
			float childCrossPos;
			float childCrossUsed;
			var hint = child.Get<LayoutHint>();
			bool hasCrossConstraint = hint != null &&
				(isVertical ? !(hint.Width case .Unconstrained) : !(hint.Height case .Unconstrained));

			if (hint != null && hint.CrossAlign != .Stretch)
			{
				childCrossUsed = childCrossSize;
				if (hint.CrossAlign == .Center)
					childCrossPos = (isVertical ? inner.X : inner.Y) + (childCrossAvailable - childCrossSize) / 2;
				else if (hint.CrossAlign == .End)
					childCrossPos = (isVertical ? inner.X : inner.Y) + childCrossAvailable - childCrossSize;
				else // .Start
					childCrossPos = isVertical ? inner.X : inner.Y;
			}
			else if (hasCrossConstraint)
			{
				// Sizing constraint overrides Stretch; position at start
				childCrossUsed = childCrossSize;
				childCrossPos = isVertical ? inner.X : inner.Y;
			}
			else
			{
				childCrossPos = isVertical ? inner.X : inner.Y;
				childCrossUsed = childCrossAvailable;
			}

			Rect childRect = isVertical
				? Rect(childCrossPos, mainPos, childCrossUsed, childMain)
				: Rect(mainPos, childCrossPos, childMain, childCrossUsed);

			LayoutWidget(childRect, child); // recurse

			mainPos += childMain + stack.Spacing;
		}
	}

	// Measure a widget's intrinsic size. For containers with StackLayout,
	// measures children and computes the total; for leaves, asks components.
	static Size MeasureWidget(Widget widget, Size constraint)
	{
		let children = widget.Get<Children>();
		let stack = widget.Get<StackLayout>();

		// Container: measure children and compute flex total
		if (children != null && stack != null)
		{
			float pad = widget.Padding;
			bool isVertical = stack.Axis == .Vertical;

			float totalMain = 0;
			float maxCross = 0;
			int spacerCount = 0;

			for (let child in children.Items)
			{
				if (child.Name == "Spacer")
				{
					spacerCount++;
					continue;
				}

				Size childConstraint = isVertical
					? .(constraint.Width - 2 * pad, float.MaxValue)
					: .(float.MaxValue, constraint.Height - 2 * pad);

				let size = MeasureWidget(child, childConstraint);
				totalMain += isVertical ? size.Height : size.Width;
				maxCross = Math.Max(maxCross, isVertical ? size.Width : size.Height);
			}

			// Spacing between non-spacer items
			int nonSpacerCount = children.Items.Count - spacerCount;
			if (nonSpacerCount > 1)
				totalMain += stack.Spacing * (nonSpacerCount - 1);

			float w = isVertical ? maxCross : totalMain;
			float h = isVertical ? totalMain : maxCross;
			w += pad * 2;
			h += pad * 2;
			var hint = widget.Get<LayoutHint>();
			if (hint != null)
			{
				w = hint.Width.Apply(w, constraint.Width);
				h = hint.Height.Apply(h, constraint.Height);
			}
			return .(w, h);
		}

		// Leaf: ask components
		float cw = 0, ch = 0;
		for (let c in widget.Components)
		{
			let size = c.Measure(constraint);
			cw = Math.Max(cw, size.Width);
			ch = Math.Max(ch, size.Height);
		}
		cw += widget.Padding * 2;
		ch += widget.Padding * 2;
		var hint = widget.Get<LayoutHint>();
		if (hint != null)
		{
			cw = hint.Width.Apply(cw, constraint.Width);
			ch = hint.Height.Apply(ch, constraint.Height);
		}
		return .(cw, ch);
	}
}
