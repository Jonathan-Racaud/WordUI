using System;
using System.Collections;
using SDL3;
using SDL3_ttf;

namespace WordUI;

// Concrete drawing module over SDL_Renderer + SDL3_ttf. All SDL drawing
// calls are localized here — no SDL types leak into the framework.
// Plain class, no interface: the abstraction is extracted later once the
// SDL3 model is proven.
public class Painter
{
	SDL_Renderer* mRenderer;
	TTF_Font* mFont;

	// SDL keeps only one clip rect; we maintain the stack and intersection so
	// nested clip regions (a scroll view inside another) compose correctly.
	List<SDL_Rect> mClipStack = new .() ~ delete _;

	public this(SDL_Renderer* renderer, TTF_Font* font)
	{
		mRenderer = renderer;
		mFont = font;
	}

	public TTF_Font* Font => mFont;
	public SDL_Renderer* Renderer => mRenderer;

	// ---- Clipping ----

	// Restrict subsequent drawing to `rect` intersected with any enclosing clip.
	// Pair every PushClip with a PopClip.
	public void PushClip(Rect rect)
	{
		SDL_Rect r = ToSdlRect(rect);
		if (mClipStack.Count > 0)
			r = Intersect(r, mClipStack[mClipStack.Count - 1]);
		mClipStack.Add(r);
		SDL_SetRenderClipRect(mRenderer, &r);
	}

	public void PopClip()
	{
		if (mClipStack.Count == 0)
			return;
		mClipStack.RemoveAt(mClipStack.Count - 1);
		if (mClipStack.Count == 0)
		{
			SDL_SetRenderClipRect(mRenderer, null);
		}
		else
		{
			SDL_Rect top = mClipStack[mClipStack.Count - 1];
			SDL_SetRenderClipRect(mRenderer, &top);
		}
	}

	// Float Rect -> integer SDL_Rect: floor the origin and ceil the far edges so
	// the integer box never clips away a partially covered pixel.
	static SDL_Rect ToSdlRect(Rect rect)
	{
		int32 x0 = (int32)Math.Floor(rect.X);
		int32 y0 = (int32)Math.Floor(rect.Y);
		int32 x1 = (int32)Math.Ceiling(rect.Right);
		int32 y1 = (int32)Math.Ceiling(rect.Bottom);
		return .() { x = x0, y = y0, w = x1 - x0, h = y1 - y0 };
	}

	static SDL_Rect Intersect(SDL_Rect a, SDL_Rect b)
	{
		int32 x0 = Math.Max(a.x, b.x);
		int32 y0 = Math.Max(a.y, b.y);
		int32 x1 = Math.Min(a.x + a.w, b.x + b.w);
		int32 y1 = Math.Min(a.y + a.h, b.y + b.h);
		return .() { x = x0, y = y0, w = Math.Max(0, x1 - x0), h = Math.Max(0, y1 - y0) };
	}

	// Fill a rectangle with a solid color.
	public void FillRect(Rect rect, Color color)
	{
		SDL_SetRenderDrawColor(mRenderer, color.R, color.G, color.B, color.A);
		SDL_FRect r = .() { x = rect.X, y = rect.Y, w = rect.Width, h = rect.Height };
		SDL_RenderFillRect(mRenderer, &r);
	}

	// Fill a rounded rectangle. TODO: use SDL_RenderFillRoundedRect when the
	// Beef SDL3 bindings expose it.
	public void FillRoundRect(Rect rect, float radius, Color color)
	{
		FillRect(rect, color);
	}

	// Stroke a rectangle outline with a solid color.
	public void DrawRect(Rect rect, Color color)
	{
		SDL_SetRenderDrawColor(mRenderer, color.R, color.G, color.B, color.A);
		SDL_FRect r = .() { x = rect.X, y = rect.Y, w = rect.Width, h = rect.Height };
		SDL_RenderRect(mRenderer, &r);
	}

	// Stroke a rounded rectangle outline. TODO: use SDL_RenderRoundedRect when
	// the Beef SDL3 bindings expose it.
	public void DrawRoundRect(Rect rect, float radius, float width, Color color)
	{
		DrawRect(rect, color);
	}

	// Render text at a position with the given color.
	public void DrawText(StringView text, float x, float y, Color color)
	{
		let cStr = text.ToScopeCStr!();
		let sdlColor = SDL_Color() { r = color.R, g = color.G, b = color.B, a = color.A };
		let surface = TTF_RenderText_Blended(mFont, cStr, 0, sdlColor);
		if (surface == null)
			return;
		defer SDL_DestroySurface(surface);

		let texture = SDL_CreateTextureFromSurface(mRenderer, surface);
		if (texture == null)
			return;
		defer SDL_DestroyTexture(texture);

		SDL_FRect dst = .() { x = x, y = y, w = (float)surface.w, h = (float)surface.h };
		SDL_RenderTexture(mRenderer, texture, null, &dst);
	}

	// Measure text dimensions at the current font size.
	public Size MeasureText(StringView text)
	{
		let cStr = text.ToScopeCStr!();
		int32 w = 0, h = 0;
		TTF_GetStringSize(mFont, cStr, 0, &w, &h);
		return .((float)w, (float)h);
	}
}
