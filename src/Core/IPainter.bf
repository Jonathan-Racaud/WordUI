using System;

namespace WordUI;

public interface IPainter
{
	void PushClip(Rect rect);
	void PopClip();
	void FillRect(Rect rect, Color color);
	void FillRoundRect(Rect rect, float radius, Color color);
	void DrawRect(Rect rect, Color color);
	void DrawRoundRect(Rect rect, float radius, float width, Color color);
	void DrawText(StringView text, float x, float y, Color color);
	Size MeasureText(StringView text);
}
