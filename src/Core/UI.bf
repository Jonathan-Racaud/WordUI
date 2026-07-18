using System;
using System.Collections;

namespace PFUI;

// The core-op API every word is built from. Framework words live in extension
// UI blocks (one file per concern under Widgets/, Modifiers/, Handlers/); app
// developers add their own words the same way, in their own project.
//
// Word-author conventions (see DESIGN.md):
//  - Modifiers act on the current stack top (widget or closed container).
//  - Construction is stack-based: pop your inputs FIRST, then NewWidget(),
//    then Attach()/modifier words. NewWidget also returns the widget for
//    authors preferring the applicative style.
//  - The stack is a per-thread construction workspace, empty between builds.
public static class UI
{
	[ThreadStatic]
	static List<StackItem> sStack;

	static List<ClickHandler> sHandlers;

	// The build arena: everything a word allocates (widgets, components,
	// strings) goes through `new:BuildAlloc` and dies wholesale on rebuild.
	// Valid only between BeginBuild and EndBuild.
	public static BumpAllocator BuildAlloc;

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

	// ---- Build lifecycle (called by App, not by word code) ----

	public static void BeginBuild(BumpAllocator arena, List<ClickHandler> handlers)
	{
		Runtime.Assert(BuildAlloc == null, "BeginBuild called while another build is active");
		BuildAlloc = arena;
		sHandlers = handlers;
		if (!Stack.IsEmpty)
			Fail("BeginBuild", "stack not empty at start of build — a previous build leaked items");
	}

	public static Widget EndBuild()
	{
		BuildAlloc = null;
		sHandlers = null;
		if (Stack.Count != 1)
			Fail("EndBuild", scope $"expected exactly 1 root widget on the stack, found {Stack.Count} items");
		return PopWidget("EndBuild");
	}

	// ---- Stack core ops ----

	public static void Push(StackItem item)
	{
		Stack.Add(item);
	}

	public static String PopStr(StringView word)
	{
		if (Pop(word) case .Str(let s))
			return s;
		FailPopped(word, "a string");
	}

	public static int PopInt(StringView word)
	{
		if (Pop(word) case .Int(let v))
			return v;
		FailPopped(word, "an int");
	}

	public static float PopFloat(StringView word)
	{
		if (Pop(word) case .Float(let v))
			return v;
		FailPopped(word, "a float");
	}

	public static double PopDouble(StringView word)
	{
		if (Pop(word) case .Double(let v))
			return v;
		FailPopped(word, "a double");
	}

	public static bool PopBool(StringView word)
	{
		if (Pop(word) case .Bool(let v))
			return v;
		FailPopped(word, "a bool");
	}

	public static Widget PopWidget(StringView word)
	{
		if (Pop(word) case .Elem(let w))
			return w;
		FailPopped(word, "a widget");
	}

	// The widget modifiers act on; errors name the word that misfired.
	public static Widget Top(StringView word)
	{
		if (Stack.IsEmpty)
			Fail(word, "stack is empty — modifiers must follow a widget word");
		if (Stack.Back case .Elem(let w))
			return w;
		let s = scope String();
		Stack.Back.ToString(s);
		Fail(word, scope $"stack top is {s}, not a widget — modifiers act on widgets");
	}

	// ---- Widget construction ops ----

	// Pushes a fresh widget and returns it (return value is the applicative
	// escape hatch; canonical word style ignores it).
	public static Widget NewWidget(StringView name)
	{
		let w = new:BuildAlloc Widget(name, new:BuildAlloc List<Component>());
		Stack.Add(.Elem(w));
		return w;
	}

	// Attaches to the stack top; duplicate component types are rejected there.
	public static void Attach(Component c)
	{
		Top("Attach").Attach(c);
	}

	// ---- Containers ----

	public static void OpenContainer(StringView name)
	{
		Stack.Add(.Mark(name));
	}

	// Stack effect: ( mark child1 … childN container -- container )
	// The closing word pushes its container widget via NewWidget, then calls
	// this to collect everything between the name-matched marker and it.
	public static void CloseContainer(StringView name)
	{
		let container = PopWidget(name);

		int markerIdx = -1;
		StringView openName = default;
		for (int i = Stack.Count - 1; i >= 0; i--)
		{
			if (Stack[i] case .Mark(let n))
			{
				markerIdx = i;
				openName = n;
				break;
			}
		}

		if (markerIdx == -1)
			Fail(name, scope $"no matching open marker for {name} — missing _{name}()?");
		if (openName != name)
			Fail(name, scope $"mismatched containers: closing {name} found an open _{openName}() marker");

		let children = new:BuildAlloc List<Widget>();
		for (int i = markerIdx + 1; i < Stack.Count; i++)
		{
			switch (Stack[i])
			{
			case .Elem(let w):
				children.Add(w);
			default:
				let s = scope String();
				Stack[i].ToString(s);
				Fail(name, scope $"unconsumed {s} on the stack — did you forget a word that consumes it?");
			}
		}

		Stack.RemoveRange(markerIdx, Stack.Count - markerIdx);
		container.Attach(new:BuildAlloc Children() { Items = children });
		Stack.Add(.Elem(container));
	}

	// ---- Handlers ----

	// Framework takes ownership; freed on the next rebuild. Handlers only ever
	// run against the current tree, so this lifetime is safe.
	public static void RegisterHandler(ClickHandler h)
	{
		sHandlers.Add(h);
	}

	// ---- Failure ----

	[NoReturn]
	public static void Fail(StringView word, StringView msg)
	{
		Console.WriteLine("PFUI error in word '{}': {}", word, msg);
		PrintStack();
		Runtime.FatalError(scope $"PFUI: error in word '{word}': {msg}");
	}

	// ---- Internals ----

	static StackItem Pop(StringView word)
	{
		if (Stack.IsEmpty)
			Fail(word, "stack underflow");
		return Stack.PopBack();
	}

	[NoReturn]
	static void FailPopped(StringView word, StringView expected)
	{
		Fail(word, scope $"{word} expects {expected} on the stack, found something else");
	}
}
