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
}

using static WordUI.Words;

// M2 demo: the counter UI is now clickable via real SDL mouse events.
class CounterSDLApp : SDLApp
{
	int mCount;
	List<String> mItems = new .() ~ DeleteContainerAndItems!(_);

	public this()
	{
		ClearColor = .(20, 40, 60, 255);
		mItems.Add(new String("alpha"));
		mItems.Add(new String("beta"));
		mItems.Add(new String("gamma"));
	}

	protected override void Build()
	{
		Console.WriteLine("Building the Counter App");
		VStack(scope () => {
			TitleLabel("Counter"); Center();

			Str(scope $"Count: {mCount}"); Label(); TextColor(.Red); FontSize(14); AlignStart();

			HStack(scope () => {
				Button("+"); {
					TextColor(.White);
					IfPressed(scope () => {
						Background(scope () => { Fill(.(120, 120, 120, 255)); Radius(4); });
					});
					OnClick(new () => { mCount++; Invalidate(); });
				} FixedSize(120, 20); Center();

				Spacer();

				Button("-"); {
					TextColor(.White);
					OnClick(new () => { mCount--; Invalidate(); });
				} FixedSize(120, 40);
			}); Spacing(4);

			for (let item in mItems)
			{
				Label(item); Key(@item.Index); TextColor(.(200, 200, 200, 255)); AlignStart();
			}
		}); Padding(16);
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
		if (args.Count > 0 && args[0] == "--test-unclosed-pen")
			return RunApp(scope UnclosedPenApp());
		if (args.Count > 0 && args[0] == "--test-leftover")
			return RunApp(scope LeftoverApp());

		let app = scope CounterSDLApp();
		app.Run();
		return 0;
	}

	static int RunApp(App app)
	{
		app.RebuildIfNeeded();
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
