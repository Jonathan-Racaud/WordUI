using System;

namespace WordUI;

// Time-warp curves for animation. An easing maps normalized progress p in
// [0,1] (linear time) to eased progress, also in [0,1]. The resolver feeds the
// eased value to Lerp. Curves live here so both Transition words and the
// resolver share one definition; user code can add cases via the enum + Apply.
public enum Easing
{
	case Linear;
	case EaseInOut;
	case Spring;

	// Maps linear progress p (already clamped to [0,1]) to eased progress.
	public float Apply(float p)
	{
		switch (this)
		{
		case .Linear:
			return p;
		case .EaseInOut:
			// smoothstep: 3p^2 - 2p^3
			return p * p * (3f - 2f * p);
		case .Spring:
			// Lightly overshooting settle; still lands on 1 at p==1.
			let s = 1.70158f;
			let x = p - 1f;
			return 1f + (s + 1f) * x * x * x + s * x * x;
		}
	}
}

// Scalar linear interpolation shared by the resolver for float channels
// (FontSize, StrokeWidth, Radius, drag offsets).
static class Lerp
{
	public static float F(float a, float b, float t) => a + (b - a) * t;
}
