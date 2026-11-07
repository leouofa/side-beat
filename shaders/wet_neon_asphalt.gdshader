shader_type spatial;

// Layer 4A: Wet Neon Street Asphalt Shader
// Procedural world-space puddles, rain-ripple rings, specular neon city reflections,
// and glowing Z-corridor boundary guide lines along the 2.5D belt-scroller street.

uniform vec4 asphalt_color : source_color = vec4(0.11, 0.13, 0.16, 1.0);
uniform vec4 neon_a : source_color = vec4(0.0, 0.83, 1.0, 1.0);
uniform vec4 neon_b : source_color = vec4(1.0, 0.12, 0.54, 1.0);
uniform float puddle_coverage : hint_range(0.0, 1.0) = 0.48;

varying vec3 v_world_pos;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 wp = v_world_pos.xz;

	// Multi-octave procedural puddle mask & asphalt grain
	float n1 = value_noise(wp * 0.42);
	float n2 = value_noise(wp * 1.35);
	float grain = value_noise(wp * 14.0);
	float puddle_mask = smoothstep(1.0 - puddle_coverage, 1.0 - puddle_coverage + 0.22, n1 * 0.65 + n2 * 0.35);

	// Subtle concentric rain-ripple rings inside puddles
	vec2 ripple_cell = floor(wp * 1.6);
	vec2 ripple_uv = fract(wp * 1.6) - 0.5;
	float cell_rnd = hash21(ripple_cell);
	float ripple_t = fract(TIME * 0.85 + cell_rnd);
	float ripple_dist = length(ripple_uv);
	float ripple_ring = smoothstep(0.05, 0.0, abs(ripple_dist - ripple_t * 0.42)) * (1.0 - ripple_t) * puddle_mask;

	// Neon street reflection shimmer inside wet puddles
	float neon_blend = 0.5 + 0.5 * sin(wp.x * 0.22 + wp.y * 0.6 + TIME * 1.2);
	vec3 neon_refl = mix(neon_a.rgb, neon_b.rgb, neon_blend);

	// Glowing synthwave curb edge lines near playable corridor Z = +-3.15m
	float corridor_edge = smoothstep(0.11, 0.01, abs(abs(v_world_pos.z) - 3.15));
	vec3 edge_glow = mix(neon_a.rgb, neon_b.rgb, step(0.0, v_world_pos.z)) * corridor_edge * 0.85;

	vec3 base_albedo = asphalt_color.rgb * (0.88 + 0.24 * grain);
	base_albedo = mix(base_albedo, base_albedo * 0.55 + neon_refl * 0.22, puddle_mask);

	ALBEDO = base_albedo;
	ROUGHNESS = mix(0.84, 0.07, puddle_mask);
	METALLIC = mix(0.05, 0.45, puddle_mask);
	EMISSION = neon_refl * (puddle_mask * 0.16 + ripple_ring * 0.45) + edge_glow;
}
