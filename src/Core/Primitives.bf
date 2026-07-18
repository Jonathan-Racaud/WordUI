using System;

namespace PFUI;

// The primitive data words, mirroring the PopStr/PopInt/PopFloat/PopBool core
// ops. Bare `Int(…)`/`Float(…)` words are impossible in Beef: Int and Float
// are corlib struct names and type constructors win resolution over
// using-static methods.
//
// PushStr copies into the build arena so callers may pass scope-allocated
// strings; value types are stored in the stack item. Complex objects
// (structs, lists, dictionaries) are deferred to their own planning phase.
extension UI
{
	public static void PushStr(StringView s)
	{
		Push(.Str(new:BuildAlloc String(s)));
	}
	public static void Str(StringView s) => PushStr(s);

	public static void PushInt(int v)
	{
		Push(.Int(v));
	}
	public static void Number(int v) => PushInt(v);

	public static void PushFloat(float v)
	{
		Push(.Float(v));
	}
	public static void Number(float v) => PushFloat(v);

	public static void PushDouble(double v)
	{
		Push(.Double(v));
	}
	public static void Number(double v) => PushDouble(v);


	public static void PushBool(bool v)
	{
		Push(.Bool(v));
	}
	public static void Bool(bool v) => PushBool(v);
}
