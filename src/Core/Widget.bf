using System;
using System.Collections;

namespace WordUI;

// The only widget class. Widgets are transient descriptions rebuilt on each
// invalidate: identity + universal layout live here, every other property is a
// component/property/behavior in the respective bag. New widgets are created by
// factoring words, never by subclassing this type.
public sealed class Widget
{
	public StringView Name;   // word-provided literal, e.g. "Label"; used by errors and dump
	public int Key = -1;      // optional user identity hint (list items); feeds StableKey
	public float Padding;
	public int StableKey;     // persistent identity across rebuilds; assigned by KeyAssign post-build
	// Layout geometry (Rect) now lives on the retained Node.RenderNode.Bounds
	// and survives rebuilds — no transient mRect on Widget.

	List<Component> mComponents;
	List<Property> mProperties;
	List<Behavior> mBehaviors;

	public this(StringView name, List<Component> compBag, List<Property> propBag, List<Behavior> behaviorBag)
	{
		Name = name;
		mComponents = compBag;
		mProperties = propBag;
		mBehaviors = behaviorBag;
	}

	// Read-only accessors for the pipeline (draw, layout, tree dump).
	public List<Component> Components => mComponents;
	public List<Property> Properties => mProperties;
	public List<Behavior> Behaviors => mBehaviors;

	// ---- Component bag (pipeline participants: Measure, Draw*, HitTest) ----

	public T GetComponent<T>() where T : Component
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
	public T RequireComponent<T>(StringView word) where T : Component
	{
		let t = GetComponent<T>();
		if (t == null)
			UI.Fail(word, scope $"{Name} has no {typeof(T).GetName(.. scope .())} — {word} does not apply to it");
		return t;
	}

	// Removes any existing component assignable from the same abstract family
	// (e.g. a new Interior replaces an old Interior regardless of subtype),
	// then attaches the new one. Used by focusing words like Background().
	public void ReplaceComponent(Component c)
	{
		Type newType = c.GetType();
		for (int i = mComponents.Count - 1; i >= 0; i--)
		{
			let existing = mComponents[i];
			if (existing.GetType().IsSubtypeOf(newType) || newType.IsSubtypeOf(existing.GetType()))
				mComponents.RemoveAt(i);
		}
		mComponents.Add(c);
	}

	// Duplicate component types are rejected: attaching a second TextStyle is
	// almost always a construction word firing at the wrong stack top.
	public void AttachComponent(Component c)
	{
		for (let existing in mComponents)
		{
			if (existing.GetType() == c.GetType())
				UI.Fail("AttachComponent", scope $"{Name} already has a {c.GetType().GetName(.. scope .())} component");
		}
		mComponents.Add(c);
	}

	// ---- Property bag (pure data: TextStyle, LayoutHint, interaction state) ----

	public T GetProperty<T>() where T : Property
	{
		for (let p in mProperties)
		{
			let t = p as T;
			if (t != null)
				return t;
		}
		return null;
	}

	public T RequireProperty<T>(StringView word) where T : Property
	{
		let t = GetProperty<T>();
		if (t == null)
			UI.Fail(word, scope $"{Name} has no {typeof(T).GetName(.. scope .())} property — {word} does not apply to it");
		return t;
	}

	public void AttachProperty(Property p)
	{
		for (let existing in mProperties)
		{
			if (existing.GetType() == p.GetType())
				UI.Fail("AttachProperty", scope $"{Name} already has a {p.GetType().GetName(.. scope .())} property");
		}
		mProperties.Add(p);
	}

	// ---- Behavior bag (event handlers: OnClick, etc.) ----

	public T GetBehavior<T>() where T : Behavior
	{
		for (let b in mBehaviors)
		{
			let t = b as T;
			if (t != null)
				return t;
		}
		return null;
	}

	public T RequireBehavior<T>(StringView word) where T : Behavior
	{
		let t = GetBehavior<T>();
		if (t == null)
			UI.Fail(word, scope $"{Name} has no {typeof(T).GetName(.. scope .())} behavior — {word} does not apply to it");
		return t;
	}

	public void AttachBehavior(Behavior b)
	{
		for (let existing in mBehaviors)
		{
			if (existing.GetType() == b.GetType())
				UI.Fail("AttachBehavior", scope $"{Name} already has a {b.GetType().GetName(.. scope .())} behavior");
		}
		mBehaviors.Add(b);
	}
}
