shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// Layer 3A: Anime / Arcade Hit-Strike Slash & Starburst Shader
// Features a blazing white core, saturated pantheon neon edge, radial impact streaks,
// and clean alpha erosion over the lifetime of the strike.

uniform vec4 strike_color : source_color = vec4(0.0, 0.83, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float is_slash_ring : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float r = length(centered);
	float ang = atan(centered.y, centered.x);

	float streak = 0.65 + 0.35 * cos(ang * 10.0 + progress * 12.0);
	float core_mask = smoothstep(0.65, 0.0, r) * (1.0 - progress * 0.85);
	float edge_mask = smoothstep(1.0, 0.15, r) * streak * (1.0 - progress);

	if (is_slash_ring > 0.5) {
		// Crescent slash arc profile
		float ring_band = smoothstep(0.28, 0.0, abs(r - mix(0.45, 0.88, progress)));
		float crescent = smoothstep(-0.35, 0.55, centered.x);
		edge_mask = ring_band * crescent * (1.0 - progress);
		core_mask = smoothstep(0.12, 0.0, abs(r - mix(0.45, 0.88, progress))) * crescent * (1.0 - progress);
	}

	vec3 col = mix(strike_color.rgb * 2.2, core_color.rgb * 3.2, clamp(core_mask * 1.4, 0.0, 1.0));
	float alpha = clamp(edge_mask + core_mask, 0.0, 1.0);

	ALBEDO = col * alpha;
	ALPHA = alpha;
}
