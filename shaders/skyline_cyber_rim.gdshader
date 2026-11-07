shader_type spatial;
render_mode unshaded;

// Layer 4B: Distant Skyline Cyber-Grid Rim Shader
// Renders atmospheric skyscraper silhouettes with glowing vertical cyber-grid edge lines,
// pulsing rooftop neon rim highlights, and beacon glow.

uniform vec4 tower_base_color : source_color = vec4(0.06, 0.08, 0.16, 1.0);
uniform vec4 horizon_fog_color : source_color = vec4(0.14, 0.10, 0.28, 1.0);
uniform vec4 neon_rim_color : source_color = vec4(0.0, 0.83, 1.0, 1.0);
uniform vec4 neon_accent_color : source_color = vec4(1.0, 0.12, 0.54, 1.0);

varying vec3 v_local_pos;
varying vec3 v_world_pos;

void vertex() {
	v_local_pos = VERTEX;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float pulse = 0.82 + 0.18 * sin(TIME * 2.2 + v_world_pos.x * 0.15);

	// Vertical height gradient from horizon fog at base to dark cyber silhouette at roof
	float h_factor = clamp((v_world_pos.y + 2.0) / 24.0, 0.0, 1.0);
	vec3 col = mix(horizon_fog_color.rgb * 0.65, tower_base_color.rgb, h_factor);

	// Vertical neon cyber-grid lines along facade UV
	float v_grid = smoothstep(0.06, 0.01, abs(fract(UV.x * 6.0) - 0.5));
	float h_grid = smoothstep(0.05, 0.01, abs(fract(v_world_pos.y * 0.55) - 0.5));
	vec3 grid_glow = mix(neon_rim_color.rgb, neon_accent_color.rgb, h_factor) * (v_grid * 0.28 + h_grid * 0.14) * h_factor;

	// Bright neon roofline highlight & Fresnel silhouette edge
	float roof_band = smoothstep(0.12, 0.01, UV.y);
	float ndotv = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float edge_rim = pow(1.0 - ndotv, 2.6);

	col += grid_glow * pulse;
	col += neon_rim_color.rgb * roof_band * 0.95 * pulse;
	col += neon_accent_color.rgb * edge_rim * 0.48 * pulse;

	ALBEDO = col;
}
