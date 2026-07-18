using System;
using System.Collections;

namespace PFUI;

// The only widget class. Widgets are transient descriptions rebuilt on each
// invalidate: identity + universal layout live here, every other property is a
// component in the bag. New widgets are created by factoring words, never by
// subclassing this type.
public sealed class Widget
{
	public StringView Name;   // word-provided literal, e.g. "Label"; used by errors and dump
	public int Key = -1;
	public float Padding;

	List<Component> mComponents;

	public this(StringView name, List<Component> bag)
	{
		Name = name;
		mComponents = bag;
	}

	public List<Component> Components => mComponents;

	public T Get<T>() where T : Component
	{
		for (let c in mComponents)
		{
			let t = c as T;
			if (t != null)
				return t;
		}
		return null;
	}

	// Capability query with a named error — the modifier workhorse.
	public T Require<T>(StringView word) where T : Component
	{
		let t = Get<T>();
		if (t == null)
			UI.Fail(word, scope $"{Name} has no {typeof(T).GetName(.. scope .())} — {word} does not apply to it");
		return t;
	}

	// Duplicate component types are rejected: attaching a second TextStyle is
	// almost always a construction word firing at the wrong stack top.
	public void Attach(Component c)
	{
		for (let existing in mComponents)
		{
			if (existing.GetType() == c.GetType())
				UI.Fail("Attach", scope $"{Name} already has a {c.GetType().GetName(.. scope .())} component");
		}
		mComponents.Add(c);
	}
}
