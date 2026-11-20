using System;
using System.Collections;
using System.Diagnostics;

namespace WordUI;

using static WordUI.UI;

// Factored words: indistinguishable from framework words at the call site.
static class Words
{
	public static void TitleLabel(StringView text)
	{
		Label(text); FontSize(24); TextColor(.White);
	}

	// A todo list row, built concatenatively from smaller words — an HStack of a
	// label, a spacer, and a delete button. This is the "ListView item" of the
	// milestone: a complex widget composed from basic words, no Widget subclass.
	// `id` gives the row a stable identity so removing a row above it doesn't
	// shift its retained interaction state.
	public static void TodoRow(int id, StringView text, ClickHandler onDelete)
	{
		HStack(scope () => {
			Label(text); AlignStart(); TextColor(.White);
			Spacer();
			Button("x"); {
				TextColor(.White);
				IfPressed(scope () => { Fill(.(120, 120, 120, 255)); });
				OnClick(onDelete);
			}
		}); Key(id); Spacing(8);
	}
}

using static WordUI.Words;

class Program
{
	public static int Main(String[] args)
	{
		if (args.Count > 0 && args[0] == "--test-mismatch")
			return RunApp(scope MismatchApp());
		if (args.Count > 0 && args[0] == "--test-unbalanced")
			return RunApp(scope UnbalancedApp());
		if (args.Count > 0 && args[0] == "--test-unclosed-pen")
			return RunApp(scope UnclosedPenApp());
		if (args.Count > 0 && args[0] == "--test-leftover")
			return RunApp(scope LeftoverApp());
		if (args.Count > 0 && args[0] == "--test-resource-lifecycle")
			return TestResourceLifecycle();

		return 0;
	}

	static int TestResourceLifecycle()
	{
		LifecycleResourceProbe.DisposeCount = 0;
		LifecycleResourceProbe.DeleteCount = 0;
		LifecycleStateProbe.DeleteCount = 0;

		let app = scope ResourceLifecycleApp();
		app.RebuildIfNeeded();
		let node = app.TestRoot;

		node.RenderNode.SetResource<TextComponent>(new LifecycleResourceProbe());
		node.RenderNode.SetResource<TextComponent>(new LifecycleResourceProbe());
		if (LifecycleResourceProbe.DisposeCount != 1 || LifecycleResourceProbe.DeleteCount != 1)
			return ResourceTestFailure("resource replacement did not release the previous resource");

		node.RenderNode.RemoveResource<TextComponent>();
		if (LifecycleResourceProbe.DisposeCount != 2 || LifecycleResourceProbe.DeleteCount != 2)
			return ResourceTestFailure("resource removal did not release the resource");

		node.RenderNode.SetResource<TextComponent>(new LifecycleResourceProbe());
		node.SetState(100, Variant.Create(new LifecycleStateProbe(), true));
		node.SetState(100, Variant.Create(new LifecycleStateProbe(), true));
		if (LifecycleStateProbe.DeleteCount != 1)
			return ResourceTestFailure("state replacement did not dispose the previous value");

		var borrowed = node.GetState(100);
		borrowed.Dispose();
		if (LifecycleStateProbe.DeleteCount != 1)
			return ResourceTestFailure("disposing a borrowed state value released its owner");

		node.PruneState(scope .());
		if (LifecycleStateProbe.DeleteCount != 2)
			return ResourceTestFailure("state pruning did not dispose the removed value");

		node.SetState(101, Variant.Create(new LifecycleStateProbe(), true));
		for (int i = 0; i < 1000; i++)
			StateSlots.DragOffset.Set(node, .() { X = (float)i, Y = (float)-i });
		let dragOffset = StateSlots.DragOffset.Get(node);
		if (dragOffset.X != 999 || dragOffset.Y != -999)
			return ResourceTestFailure("large typed state did not retain the latest value");

		app.Dispose();
		app.Dispose();
		if (LifecycleResourceProbe.DisposeCount != 3 || LifecycleResourceProbe.DeleteCount != 3)
			return ResourceTestFailure("app disposal did not release its retained render resource exactly once");
		if (LifecycleStateProbe.DeleteCount != 3)
			return ResourceTestFailure("app disposal did not release its remaining state value");
		if (app.TestRoot != null)
			return ResourceTestFailure("app disposal retained its root node");

		Console.WriteLine("Resource lifecycle test passed.");
		return 0;
	}

	static int ResourceTestFailure(StringView message)
	{
		Console.WriteLine(scope $"Resource lifecycle test failed: {message}");
		return 1;
	}

	static int RunApp(App app)
	{
		app.RebuildIfNeeded();
		return 0;
	}
}

class ResourceLifecycleApp : App
{
	public Node TestRoot => mRootNode;

	protected override void Build()
	{
		VStack(scope () => {
			Label("resource lifecycle");
			Button("test");
		});
	}
}

class LifecycleResourceProbe : RenderResource
{
	public static int DisposeCount;
	public static int DeleteCount;

	public override void Dispose()
	{
		DisposeCount++;
	}

	public ~this()
	{
		DeleteCount++;
	}
}

class LifecycleStateProbe
{
	public static int DeleteCount;

	public ~this()
	{
		DeleteCount++;
	}
}

// Negative test: closing a container of the wrong kind must fail with a
// named-marker error, not build a scrambled tree.
class MismatchApp : App
{
	protected override void Build()
	{
		_VStack();
		Label("oops");
		HStack_();   // wrong close: the open marker is a VStack
	}
}

// Negative test: a missing close word must trip the stack-hygiene check.
class UnbalancedApp : App
{
	protected override void Build()
	{
		_VStack();
		Label("no close word follows");
	}
}

// Negative test: a pen block opened but not closed must leave a marker and
// pen on the stack, which triggers a hygiene error when the outer container
// closes.
class UnclosedPenApp : App
{
	protected override void Build()
	{
		VStack(scope () => {
			_Interior(); Fill(.Red);
			// missing Interior_()
			Label("x");
		});
	}
}

// Negative test: primitive values nothing consumed must be reported by name
// when the enclosing container closes.
class LeftoverApp : App
{
	protected override void Build()
	{
		VStack(scope () => {
			PushInt(42); PushFloat(3.14f); PushBool(true);
			Label("x");
		});
	}
}
