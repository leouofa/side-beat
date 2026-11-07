shader_type spatial;
render_mode unshaded, cull_disabled;

// Layer 2B: Neon Voxel / Cyber-Ember KO Dissolve Shader
// Disintegrates defeated enemies and bosses upward into glowing synthwave embers.

uniform vec4 base_color : source_color = vec4(0.18, 0.22, 0.32, 1.0);
uniform vec4 burn_color : source_color = vec4(1.0, 0.12, 0.42, 1.0);
uniform vec4 ember_core_color : source_color = vec4(1.0, 0.92, 0.45, 1.0);
uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;
uniform float voxel_scale : hint_range(4.0, 40.0) = 18.0;

varying vec3 v_local_pos;

float hash31(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	// Slight upward cyber-drift as the character dissolves
	float lift = dissolve_progress * dissolve_progress * 0.38;
	VERTEX.y += lift;
	v_local_pos = VERTEX;
}

void fragment() {
	vec3 cell = floor(v_local_pos * voxel_scale);
	float n = hash31(cell);

	// Bias dissolve from bottom/extremities upward with voxel noise
	float height_bias = clamp(v_local_pos.y * 0.35, 0.0, 0.45);
	float threshold = dissolve_progress * 1.35;
	float val = n * 0.72 + height_bias * 0.28;

	if (val < threshold - 0.14) {
		discard;
	}

	float edge_band = smoothstep(threshold, threshold - 0.14, val);
	float hot_core = smoothstep(threshold - 0.05, threshold - 0.13, val);

	float ndotv = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 2.2);

	vec3 col = base_color.rgb * (0.55 + 0.45 * ndotv) + burn_color.rgb * fresnel * 0.65;
	col = mix(col, burn_color.rgb * 2.4, edge_band);
	col = mix(col, ember_core_color.rgb * 3.0, hot_core);

	ALBEDO = col;
}
