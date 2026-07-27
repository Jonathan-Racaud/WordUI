using System;
using System.Collections;
using WordUI;
using static WordUI.Words;

namespace TodoApp;

extension UI
{

}

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
		let app = scope TodoSDLApp();
		app.Run();
		return 0;
	}
}