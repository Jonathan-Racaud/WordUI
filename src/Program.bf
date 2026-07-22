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

// M4 demo: a functional todo app — add an item, remove an item, and scroll the
// list. The list lives in a Scrollable container with a bounded height and Clip,
// so it overflows into a scroll viewport whose offset survives the rebuild each
// add/remove triggers. No text input yet (M5), so item text is auto-generated.
class TodoSDLApp : SDLApp
{
	// App-owned state: id keeps a stable identity per item as the list churns.
	List<(int id, String text)> mTodos = new .() ~ {
		for (let t in _) delete t.text;
		delete _;
	};
	int mNextId = 1;

	public this()
	{
		ClearColor = .(20, 40, 60, 255);
		for (int i = 0; i < 8; i++)
			AddTodo();
	}

	void AddTodo()
	{
		let n = mNextId++;
		mTodos.Add((n, new String(scope $"Task {n}")));
		Invalidate();
	}

	void RemoveTodo(int id)
	{
		for (int i = 0; i < mTodos.Count; i++)
		{
			if (mTodos[i].id == id)
			{
				delete mTodos[i].text;
				mTodos.RemoveAt(i);
				break;
			}
		}
		Invalidate();
	}

	protected override void Build()
	{
		VStack(scope () => {
			TitleLabel("Todos"); Center();

			HStack(scope () => {
				Button("Add"); {
					TextColor(.White);
					IfPressed(scope () => { Fill(.(120, 120, 120, 255)); });
					OnClick(new () => { AddTodo(); });
				}
				Spacer();
				Label(scope $"{mTodos.Count} items"); AlignEnd(); TextColor(.(180, 180, 180, 255));
			}); Spacing(8);

			// The scroll viewport: a vertical Scrollable, clipped to a fixed
			// height. Its children overflow and the wheel scrolls them.
			Scrollable(scope () => {
				for (let t in mTodos)
				{
					let id = t.id;   // per-iteration copy for the delete closure
					TodoRow(id, t.text, new () => { RemoveTodo(id); });
				}
			}); Height(.Fixed(240)); Spacing(6); Clip();
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

		let app = scope TodoSDLApp();
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
