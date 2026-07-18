using System;
using System.Collections;

namespace PFUI;

// The one component the core knows about: CloseContainer fills it. Any widget
// holding a Children component is a container as far as walks are concerned.
public class Children : Component
{
	public List<Widget> Items;
}
