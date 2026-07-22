using System;

namespace WordUI;

// Assigns Widget.StableKey by a deterministic walk of the finished tree, so the
// same logical widget gets the same key across rebuilds (as long as the build
// structure is stable). This is the identity persistent interaction state keys
// off of — it replaces the old dangling Widget* / positional build ordinal.
//
// Each widget's key is a path hash: hash(parentKey, Name, discriminator), where
// the discriminator is the author's Key() hint when set (>= 0, e.g. list item
// index) or the sibling ordinal otherwise. Feeding the explicit hint into the
// hash (rather than using it raw) keeps user keys and auto keys in one space
// with no collisions between a small user int and a computed path.
static class KeyAssign
{
	public static void Run(Widget root)
	{
		if (root != null)
			Assign(root, 1, 0);
	}

	static void Assign(Widget w, int parentKey, int siblingIndex)
	{
		int disc = w.Key >= 0 ? w.Key : siblingIndex;
		w.StableKey = Mix(Mix(parentKey, HashName(w.Name)), disc);

		let children = w.GetComponent<Children>();
		if (children == null)
			return;
		for (int i = 0; i < children.Items.Count; i++)
			Assign(children.Items[i], w.StableKey, i);
	}

	// FNV-1a over the name bytes; stable and allocation-free.
	static int HashName(StringView name)
	{
		int h = (int)0xcbf29ce484222325UL;
		for (let c in name)
			h = (h ^ (int)c) &* (int)0x100000001b3UL;
		return h;
	}

	static int Mix(int a, int b)
	{
		int h = a &* (int)0x100000001b3UL;
		return h ^ b;
	}
}
