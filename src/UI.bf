using System;
using System.Collections;

namespace PFUI;

// The word vocabulary. Users write `using static PFUI.UI;` once per file and
// then call words as bare statements, Factor-style:
//
//     VStack(scope () => {
//         Label("Title"); FontSize(24);
//         HStack(scope () => {
//             Button("+"); OnClick(handler);
//         }); Spacing(4);      // modifies the HStack
//     }); Padding(8);          // modifies the VStack
//
// Conventions (see DESIGN.md):
//  - Modifiers always act on the current stack top (widget or closed container).
//  - Content may be pushed (`Str("x"); Label();`) or passed as an argument
//    (`Label("x")`); both forms are equivalent.
//  - The stack is a per-thread construction workspace, empty between builds.
public static class UI
{
	[ThreadStatic]
	static List<StackItem> sStack;

	static BumpAllocator sArena;
	static List<ClickHandler> sHandlers;

	static ~this()
	{
		delete sStack;   // main thread only; the prototype is single-threaded
	}

	static List<StackItem> Stack
	{
		get
		{
			if (sStack == null)
				sStack = new .();
			return sStack;
		}
	}

	// ---- Build lifecycle (called by App, not by user code) ----

	public static void BeginBuild(BumpAllocator arena, List<ClickHandler> handlers)
	{
		Runtime.Assert(sArena == null, "BeginBuild called while another build is active");
		sArena = arena;
		sHandlers = handlers;
		if (!Stack.IsEmpty)
			Fail("BeginBuild", "stack not empty at start of build — a previous build leaked items");
	}

	public static Widget EndBuild()
	{
		sArena = null;
		sHandlers = null;
		if (Stack.Count != 1)
			Fail("EndBuild", scope $"expected exactly 1 root widget on the stack, found {Stack.Count} items");
		let root = PopWidget("EndBuild");
		return root;
	}

	// ---- Primitive data words ----

	public static void Str(StringView s)
	{
		Stack.Add(.Text(new:sArena String(s)));
	}

	// ---- Widget words: ( args… -- widget ) ----

	public static void Label()
	{
		let w = NewWidget(.Label);
		w.Text = PopText("Label");
		Stack.Add(.Elem(w));
	}

	public static void Label(StringView s) { Str(s); Label(); }

	public static void Image()
	{
		let w = NewWidget(.Image);
		w.Text = PopText("Image");
		Stack.Add(.Elem(w));
	}

	public static void Image(StringView name) { Str(name); Image(); }

	public static void Button()
	{
		let w = NewWidget(.Button);
		w.Text = PopText("Button");
		Stack.Add(.Elem(w));
	}

	public static void Button(StringView text) { Str(text); Button(); }

	public static void Spacer()
	{
		Stack.Add(.Elem(NewWidget(.Spacer)));
	}

	// ---- Modifier words: act on the stack top ----

	public static void TextColor(Color c) { Top("TextColor").TextColor = c; }
	public static void FontSize(float px) { Top("FontSize").FontSize = px; }
	public static void Padding(float all) { Top("Padding").Padding = all; }
	public static void Spacing(float px) { Top("Spacing").Spacing = px; }
	public static void Key(int id) { Top("Key").Key = id; }

	public static void OnClick(ClickHandler h)
	{
		sHandlers.Add(h);   // framework takes ownership; freed on next rebuild
		Top("OnClick").OnClick = h;
	}

	// ---- Containers: primitive open/close pair + delegate-block form ----

	public static void _VStack() { Stack.Add(.Mark(.VStack)); }
	public static void _HStack() { Stack.Add(.Mark(.HStack)); }
	public static void VStack_() { CloseContainer(.VStack, "VStack_"); }
	public static void HStack_() { CloseContainer(.HStack, "HStack_"); }

	public static void VStack(delegate void() body) { _VStack(); body(); VStack_(); }
	public static void HStack(delegate void() body) { _HStack(); body(); HStack_(); }

	// ---- Diagnostics ----

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

	public static StringView KindName(WidgetKind kind)
	{
		switch (kind)
		{
		case .Label: return "Label";
		case .Image: return "Image";
		case .Button: return "Button";
		case .HStack: return "HStack";
		case .VStack: return "VStack";
		case .Spacer: return "Spacer";
		}
	}

	// ---- Internals ----

	static Widget NewWidget(WidgetKind kind)
	{
		return new:sArena Widget(kind);
	}

	static void CloseContainer(WidgetKind kind, StringView word)
	{
		int markerIdx = -1;
		WidgetKind openKind = default;
		for (int i = Stack.Count - 1; i >= 0; i--)
		{
			if (Stack[i] case .Mark(let k))
			{
				markerIdx = i;
				openKind = k;
				break;
			}
		}

		if (markerIdx == -1)
			Fail(word, scope $"no matching open marker for {KindName(kind)} — missing _{KindName(kind)}()?");
		if (openKind != kind)
			Fail(word, scope $"mismatched containers: {word} found an open _{KindName(openKind)}() marker");

		let children = new:sArena List<Widget>();
		for (int i = markerIdx + 1; i < Stack.Count; i++)
		{
			switch (Stack[i])
			{
			case .Elem(let w):
				children.Add(w);
			case .Text(let s):
				Fail(word, scope $"unconsumed string \"{s}\" on the stack — did you forget a widget word after Str()?");
			case .Mark:
				Runtime.FatalError("unreachable: inner marker above the nearest marker");
			}
		}

		Stack.RemoveRange(markerIdx, Stack.Count - markerIdx);
		let w = NewWidget(kind);
		w.Children = children;
		Stack.Add(.Elem(w));
	}

	static Widget Top(StringView word)
	{
		if (Stack.IsEmpty)
			Fail(word, "stack is empty — modifiers must follow a widget word");
		if (Stack.Back case .Elem(let w))
			return w;
		let s = scope String();
		Stack.Back.ToString(s);
		Fail(word, scope $"stack top is {s}, not a widget — modifiers act on widgets");
	}

	static Widget PopWidget(StringView word)
	{
		if (Stack.IsEmpty)
			Fail(word, "stack underflow — expected a widget");
		if (Stack.PopBack() case .Elem(let w))
			return w;
		Fail(word, "expected a widget on the stack");
	}

	static String PopText(StringView word)
	{
		if (Stack.IsEmpty)
			Fail(word, scope $"stack underflow — {word} expects a string (push one with Str() or use {word}(\"…\"))");
		if (Stack.PopBack() case .Text(let s))
			return s;
		Fail(word, scope $"{word} expects a string on the stack, found something else");
	}

	[NoReturn]
	static void Fail(StringView word, StringView msg)
	{
		Console.WriteLine("PFUI error in word '{}': {}", word, msg);
		PrintStack();
		Runtime.FatalError(scope $"PFUI: error in word '{word}': {msg}");
	}
}
