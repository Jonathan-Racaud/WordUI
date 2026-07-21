using System;

namespace WordUI;

// The build stack holds tagged items; every pop validates the tag so a misused
// word fails with a named error instead of building a scrambled tree.
public enum StackItem
{
	case Str(String);
	case Int(int);
	case Float(float);
	case Double(double);
	case Bool(bool);
	case Elem(Widget);
	case Pen(Component);
	case Mark(StringView);

	public void ToString(String buf)
	{
		switch (this)
		{
		case .Str(let s): buf.AppendF("Str(\"{}\")", s);
		case .Int(let v): buf.AppendF("Int({})", v);
		case .Float(let v): buf.AppendF("Float({})", v);
		case .Double(let v): buf.AppendF("Double({})", v);
		case .Bool(let v): buf.AppendF("Bool({})", v);
		case .Elem(let w): buf.AppendF("Widget({})", w.Name);
		case .Pen(let c):  buf.AppendF("Pen({})", c.GetType().GetName(.. scope .()));
		case .Mark(let name): buf.AppendF("Marker({})", name);
		}
	}
}
