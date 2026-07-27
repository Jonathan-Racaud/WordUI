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
