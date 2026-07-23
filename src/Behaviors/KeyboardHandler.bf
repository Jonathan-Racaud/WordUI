using System;

namespace WordUI;

// Fired when a key is pressed while this widget holds focus.
// keycode: SDL keycode (platform-independent virtual key)
// modifiers: bitmask of SDL keymods (Shift, Ctrl, Alt, etc.)
public delegate void KeyHandler(int keycode, int modifiers);

// Keyboard input handler. Carries its own KeyHandler delegate — no separate
// delegate-holder behavior. When a KeyDown event arrives and this widget holds
// focus (checked via App.FocusedKey == owner.StableKey), fires the handler.
// Does NOT declare state slots — focus state is managed by FocusHandler.
public class KeyboardHandler : Behavior, IInputHandler
{
	public KeyHandler Handler;   // null = no key callback

	public bool HandleEvent(Widget root, Widget owner, InputEvent event)
	{
		if (event.Type != .KeyDown)
			return false;

		if (App.Instance.FocusedKey != owner.StableKey)
			return false;

		if (Handler != null)
			Handler(event.KeyCode, event.KeyModifiers);
		return false;
	}

	public bool HandleMotion(Widget root, Widget owner, float x, float y)
	{
		return false;
	}

	public override void Describe(String buf)
	{
		buf.Append(" OnKey");
	}
}

extension UI
{
	// Makes the stack-top widget receive keyboard events when focused.
	// Attaches KeyboardHandler (which owns the KeyHandler delegate directly —
	// one behavior, no separate holder). Pair with Focusable() to make the
	// widget focusable.
	public static void OnKey(KeyHandler h)
	{
		let w = Top("OnKey");
		var kh = w.GetBehavior<KeyboardHandler>();
		if (kh == null)
		{
			kh = new:BuildAlloc KeyboardHandler();
			w.AttachBehavior(kh);
		}
		RegisterHandler(h);
		kh.Handler = h;
	}

	// Makes the stack-top widget focusable: clicking it gives it keyboard focus.
	// Attaches FocusHandler. Pair with OnKey() to also receive key events.
	public static void Focusable()
	{
		let w = Top("Focusable");
		var fh = w.GetBehavior<FocusHandler>();
		if (fh == null)
		{
			fh = new:BuildAlloc FocusHandler();
			w.AttachBehavior(fh);
		}
	}
}
