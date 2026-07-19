using System;
using System.Collections;

namespace PFUI;

using static PFUI.UI;

// Factored words: indistinguishable from framework words at the call site.
static class Words
{
	public static void TitleLabel(StringView text)
	{
		Label(text); FontSize(24); TextColor(.White);
	}
}

using static PFUI.Words;

// M0 demo: opens a colored SDL3 window; closes on X.
class M0App : PFUI.SDLApp
{
	public this()
	{
		ClearColor = .(20, 40, 60, 255);
	}

	protected override void Build()
	{
		VStack(scope () => {});
	}
}

class CounterApp : App
{
	int mCount;
	List<String> mItems = new .() ~ DeleteContainerAndItems!(_);

	public this()
	{
		mItems.Add(new String("alpha"));
		mItems.Add(new String("beta"));
		mItems.Add(new String("gamma"));
	}

	protected override void Build()
	{
		VStack(scope () => {
			TitleLabel("Counter");

			// Primitive stack form: a word leaves content for the next word.
			Str(scope $"Count: {mCount}"); Label(); TextColor(.Red); FontSize(14);

			HStack(scope () => {
				Button("+"); OnClick(new () => { mCount++; Invalidate(); });
				Spacer();
				Button("-"); OnClick(new () => { mCount--; Invalidate(); });
			}); Spacing(4);

			// Native control flow replaces Factor's each/map combinators.
			for (let item in mItems)
			{
				Label(item); Key(@item.Index);
			}
		}); Padding(8);
	}
}

class Program
{
	public static int Main(String[] args)
	{
		if (args.Count > 0 && args[0] == "--test-mismatch")
			return RunApp(scope MismatchApp());
		if (args.Count > 0 && args[0] == "--test-unbalanced")
			return RunApp(scope UnbalancedApp());
		if (args.Count > 0 && args[0] == "--test-leftover")
			return RunApp(scope LeftoverApp());
		if (args.Count > 0 && args[0] == "--test-counter")
			return RunCounterConsole();

		let app = scope M0App();
		app.Run();
		return 0;
	}

	static int RunApp(App app)
	{
		app.RebuildIfNeeded();
		return 0;
	}

	static int RunCounterConsole()
	{
		let app = scope CounterApp();

		Console.WriteLine("=== initial build ===");
		app.RebuildIfNeeded();
		app.DumpTree();

		Console.WriteLine("\n=== click \"+\" twice, click \"-\" once ===");
		app.SimulateClick("+");
		app.RebuildIfNeeded();   // handler called Invalidate -> tree rebuilt
		app.SimulateClick("+");
		app.RebuildIfNeeded();
		app.SimulateClick("-");
		app.RebuildIfNeeded();
		app.DumpTree();

		Console.WriteLine("\n=== no state change -> no rebuild ===");
		Console.WriteLine("rebuilt: {}", app.RebuildIfNeeded());

		return 0;
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
