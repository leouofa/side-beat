shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// Layer 3B: Energy Shockwave Ring & Jagged Plasma Pillar Shader
// Mode 0 (is_pillar = 0.0): Concentric ground shockwave ripples with sharp leading edge
// Mode 1 (is_pillar = 1.0): Scrolling jagged high-voltage plasma arcs for lightning & morph pillars

uniform vec4 energy_color : source_color = vec4(0.0, 0.83, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float is_pillar : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_pos;

void vertex() {
	v_pos = VERTEX;
}

void fragment() {
	float fade = 1.0 - progress;
	vec3 col = energy_color.rgb * 2.0;
	float alpha = fade;

	if (is_pillar > 0.5) {
		// Vertical plasma column with scrolling jagged lightning bands
		float zig = sin(UV.y * 28.0 - TIME * 36.0 + sin(UV.x * 18.0 + TIME * 22.0) * 2.4);
		float arc = smoothstep(0.15, 0.92, 0.5 + 0.5 * zig);
		float center_beam = 0.55 + 0.45 * cos(UV.x * 6.28318);
		col = mix(energy_color.rgb * 2.2, core_color.rgb * 3.0, arc * 0.75);
		alpha = clamp((0.45 + arc * 0.75) * center_beam * fade, 0.0, 1.0);
	} else {
		// Radial concentric shockwave ring
		float radial = length(v_pos.xz);
		float ripples = 0.55 + 0.45 * sin(radial * 18.0 - TIME * 28.0 - progress * 10.0);
		float rim = smoothstep(0.25, 0.98, clamp(radial, 0.0, 1.0));
		col = mix(energy_color.rgb * 2.0, core_color.rgb * 2.8, rim * 0.65);
		alpha = clamp((0.4 + 0.6 * ripples) * (0.45 + 0.55 * rim) * fade, 0.0, 1.0);
	}

	ALBEDO = col * alpha;
	ALPHA = alpha;
}
