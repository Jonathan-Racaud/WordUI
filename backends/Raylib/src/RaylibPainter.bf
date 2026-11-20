using System;
using System.Collections;
using RaylibBeef;
using static RaylibBeef.Raylib;

namespace WordUI;

public class RaylibPainter : IPainter
{
	Font mFont;
	float mFontSize = 16;
	List<Rectangle> mClipStack = new .() ~ delete _;

	public this(Font font, float fontSize = 16)
	{
		mFont = font;
		mFontSize = fontSize;
	}

	public void PushClip(Rect rect)
	{
		Rectangle clip = ToRaylibRect(rect);
		if (mClipStack.Count > 0)
			clip = Intersect(clip, mClipStack[mClipStack.Count - 1]);
		mClipStack.Add(clip);
		BeginScissor(clip);
	}

	public void PopClip()
	{
		if (mClipStack.Count == 0)
			return;
		mClipStack.RemoveAt(mClipStack.Count - 1);
		EndScissorMode();
		if (mClipStack.Count > 0)
		{
			let clip = mClipStack[mClipStack.Count - 1];
			BeginScissor(clip);
		}
	}

	public void FillRect(Rect rect, WordUI.Color color)
	{
		DrawRectangleRec(ToRaylibRect(rect), ToRaylibColor(color));
	}

	public void FillRoundRect(Rect rect, float radius, WordUI.Color color)
	{
		float diameter = Math.Min(rect.Width, rect.Height);
		float roundness = diameter > 0 ? Math.Clamp(radius * 2 / diameter, 0, 1) : 0;
		DrawRectangleRounded(ToRaylibRect(rect), roundness, 8, ToRaylibColor(color));
	}

	public void DrawRect(Rect rect, WordUI.Color color)
	{
		DrawRectangleLinesEx(ToRaylibRect(rect), 1, ToRaylibColor(color));
	}

	public void DrawRoundRect(Rect rect, float radius, float width, WordUI.Color color)
	{
		float diameter = Math.Min(rect.Width, rect.Height);
		float roundness = diameter > 0 ? Math.Clamp(radius * 2 / diameter, 0, 1) : 0;
		DrawRectangleRoundedLinesEx(ToRaylibRect(rect), roundness, 8, width, ToRaylibColor(color));
	}

	public void DrawText(StringView text, float x, float y, WordUI.Color color)
	{
		let cStr = text.ToScopeCStr!();
		DrawTextEx(mFont, cStr, Vector2(x, y), mFontSize, 0, ToRaylibColor(color));
	}

	public Size MeasureText(StringView text)
	{
		let cStr = text.ToScopeCStr!();
		let size = MeasureTextEx(mFont, cStr, mFontSize, 0);
		return .(size.x, size.y);
	}

	static Rectangle ToRaylibRect(Rect rect)
	{
		return .(rect.X, rect.Y, rect.Width, rect.Height);
	}

	static Rectangle Intersect(Rectangle a, Rectangle b)
	{
		float x0 = Math.Max(a.x, b.x);
		float y0 = Math.Max(a.y, b.y);
		float x1 = Math.Min(a.x + a.width, b.x + b.width);
		float y1 = Math.Min(a.y + a.height, b.y + b.height);
		return .(x0, y0, Math.Max(0, x1 - x0), Math.Max(0, y1 - y0));
	}

	static void BeginScissor(Rectangle clip)
	{
		int32 x0 = (int32)Math.Floor(clip.x);
		int32 y0 = (int32)Math.Floor(clip.y);
		int32 x1 = (int32)Math.Ceiling(clip.x + clip.width);
		int32 y1 = (int32)Math.Ceiling(clip.y + clip.height);
		BeginScissorMode(x0, y0, x1 - x0, y1 - y0);
	}

	static RaylibBeef.Color ToRaylibColor(WordUI.Color color)
	{
		return .(color.R, color.G, color.B, color.A);
	}
}
