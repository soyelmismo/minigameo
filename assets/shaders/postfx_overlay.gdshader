shader_type canvas_item;
// Premium post overlay — vignette + scanlines + chromatic + desaturate
// (graphics brief: "bloom tuned so neon bleeds but text stays legible, a
// vignette that focuses the eye, per-style-pack variation").
//
// Rendered on the topmost CanvasLayer by ScreenEffects, driven by
// PostFXDirector.overlay_state(). Values arrive as uniforms from the
// director — the defaults below are the neutral base look.
//
// Vignette and scanlines are implemented as an additive-dark veil so they
// cost one pass and never touch HUD legibility; chromatic aberration and
// desaturation sample the backbuffer once (hint_screen_texture).
//
// Uniform defaults ARE the tuning data (§1.3 equivalent for shaders: no
// magic numbers inside gameplay logic).

uniform float vignette : hint_range(0.0, 1.0) = 0.18;
uniform float vignette_size : hint_range(0.1, 1.0) = 0.72;
uniform float scanline : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_density : hint_range(200.0, 2000.0) = 900.0;
uniform float chromatic : hint_range(0.0, 1.0) = 0.0;
uniform float chromatic_spread : hint_range(0.0, 0.02) = 0.006;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	vec2 uv = UV;
	// Veil: darkening toward the corners (focuses the eye on the action)
	// plus optional CRT lines. Pure math — no backbuffer read.
	vec2 centered = (uv - 0.5) * vec2(1.06, 1.0);
	float d = length(centered) / max(vignette_size, 0.05);
	float vig = vignette * smoothstep(0.35, 1.0, d);
	float lines = scanline * 0.30 * (0.5 + 0.5 * sin(uv.y * scanline_density));
	float veil = clamp(vig + lines, 0.0, 0.9);

	if (chromatic > 0.004 || desaturate > 0.004) {
		// Backbuffer path: RGB split at the screen edges + hitstop wash.
		vec2 dir = centered * chromatic * chromatic_spread * 4.0;
		vec3 base = vec3(
			texture(screen_texture, uv + dir).r,
			texture(screen_texture, uv).g,
			texture(screen_texture, uv - dir).b
		);
		float lum = dot(base, vec3(0.299, 0.587, 0.114));
		base = mix(base, vec3(lum), desaturate);
		COLOR = vec4(base, veil);
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, veil);
	}
}
