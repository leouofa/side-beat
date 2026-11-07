shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// Layer 3C: Animated Arcade Danger Telegraph Shader
// Displays scrolling 45-degree hazard chevrons, a pulsing neon perimeter frame,
// and an expanding countdown fill sweep from 0.0 -> 1.0 before the boss/hazard strike erupts.

uniform vec4 warning_color : source_color = vec4(1.0, 0.12, 0.26, 1.0);
uniform vec4 hot_edge_color : source_color = vec4(1.0, 0.88, 0.4, 1.0);
uniform float fill_progress : hint_range(0.0, 1.0) = 0.0;
uniform float opacity_scale : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec2 uv = UV;
	vec2 border_dist = min(uv, 1.0 - uv);
	float min_b = min(border_dist.x, border_dist.y);

	// Crisp glowing perimeter frame
	float border_mask = smoothstep(0.09, 0.02, min_b);

	// Scrolling 45-degree hazard chevron stripes
	float stripe_coord = (uv.x + uv.y) * 10.0 - TIME * 5.5;
	float chevrons = step(0.5, fract(stripe_coord));

	// Expanding countdown sweep along X from center outward
	float center_dist = abs(uv.x - 0.5) * 2.0;
	float sweep_fill = smoothstep(fill_progress + 0.05, fill_progress - 0.05, center_dist);
	float sweep_leading_line = smoothstep(0.06, 0.0, abs(center_dist - fill_progress));

	float pulse = 0.75 + 0.25 * sin(TIME * 16.0);
	vec3 col = warning_color.rgb * (0.65 + 0.35 * chevrons + 0.5 * sweep_fill);
	col = mix(col, hot_edge_color.rgb * 1.8, clamp(border_mask * 0.75 + sweep_leading_line, 0.0, 1.0));

	float base_alpha = (0.22 + 0.18 * chevrons + 0.32 * sweep_fill + 0.55 * border_mask + 0.45 * sweep_leading_line) * pulse * opacity_scale;
	ALBEDO = col;
	ALPHA = clamp(base_alpha, 0.0, 0.92);
}
