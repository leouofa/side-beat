shader_type canvas_item;

// Synthwave Cyberpunk Cityline Procedural Background
// Features: Perspective scrolling 3D neon grid, procedural skyline with flickering windows & antenna beacons,
// starry cosmic twilight sky, and breathing neon atmospheric glow.

uniform vec4 sky_top_color : source_color = vec4(0.02, 0.01, 0.07, 1.0);
uniform vec4 sky_bottom_color : source_color = vec4(0.16, 0.04, 0.25, 1.0);
uniform vec4 horizon_glow_color : source_color = vec4(1.0, 0.12, 0.55, 1.0);
uniform vec4 grid_color : source_color = vec4(0.0, 0.90, 1.0, 1.0);
uniform vec4 grid_base_color : source_color = vec4(0.04, 0.02, 0.09, 1.0);

uniform float horizon_y : hint_range(0.3, 0.8) = 0.52;
uniform float grid_speed : hint_range(0.1, 3.0) = 0.55;
uniform float grid_scale : hint_range(5.0, 40.0) = 14.0;
uniform float pulse_speed : hint_range(0.2, 5.0) = 1.6;
uniform float star_density : hint_range(0.0, 1.0) = 0.65;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Procedural stars in the upper sky
float get_star(vec2 uv, float t) {
	if (uv.y > horizon_y - 0.05) return 0.0;
	vec2 star_uv = uv * vec2(90.0, 50.0);
	vec2 id = floor(star_uv);
	vec2 gv = fract(star_uv) - 0.5;
	float rnd = hash21(id);
	if (rnd > (1.0 - star_density * 0.12)) {
		float dist = length(gv);
		float twinkle = 0.5 + 0.5 * sin(t * 3.0 + rnd * 6.2831);
		return smoothstep(0.18, 0.01, dist) * twinkle;
	}
	return 0.0;
}

// 2-layer procedural skyline silhouette with glowing windows & rooftop antennas
vec4 render_skyline(vec2 uv, float t, vec4 current_col) {
	vec4 col = current_col;

	// Layer 1: Distant background skyline (smaller, darker purple silhouette)
	float num_cols_far = 38.0;
	float col_far = floor(uv.x * num_cols_far);
	float h_far = mix(0.08, 0.22, hash11(col_far * 7.19));
	float far_roof = horizon_y - h_far;

	if (uv.y >= far_roof && uv.y <= horizon_y) {
		col = mix(col, vec4(0.09, 0.03, 0.16, 1.0), 0.85);
		// Rim highlight on distant roof
		if (uv.y < far_roof + 0.003) {
			col += vec4(0.5, 0.1, 0.4, 0.5);
		}
	}

	// Layer 2: Near foreground skyline (sharper, detailed with glowing windows & beacons)
	float num_cols_near = 22.0;
	float col_idx = floor(uv.x * num_cols_near);
	float h_near = mix(0.12, 0.32, hash11(col_idx * 13.37));
	// Gaps between some buildings for depth
	float exists = step(0.15, hash11(col_idx * 29.41));
	h_near *= exists;
	float near_roof = horizon_y - h_near;

	// Antenna tower & blinking beacon
	float has_antenna = step(0.65, hash11(col_idx * 43.17)) * exists;
	if (has_antenna > 0.5) {
		float center_x = (col_idx + 0.5) / num_cols_near;
		float dist_x = abs(uv.x - center_x) * num_cols_near;
		float antenna_top = near_roof - 0.055;
		// Mast
		if (dist_x < 0.06 && uv.y >= antenna_top && uv.y <= near_roof) {
			col = vec4(0.08, 0.05, 0.14, 1.0);
		}
		// Blinking beacon light
		if (uv.y >= antenna_top - 0.015 && uv.y <= antenna_top + 0.005) {
			float beacon_dist = length(vec2(dist_x * 0.15, uv.y - antenna_top));
			float blink = step(0.4, sin(t * 4.0 + col_idx * 2.1));
			vec4 beacon_color = mix(vec4(1.0, 0.1, 0.2, 1.0), vec4(0.0, 0.9, 1.0, 1.0), step(0.5, hash11(col_idx)));
			col += beacon_color * smoothstep(0.014, 0.001, beacon_dist) * blink * 1.5;
		}
	}

	if (exists > 0.5 && uv.y >= near_roof && uv.y <= horizon_y) {
		// Base building dark silhouette
		col = vec4(0.05, 0.03, 0.10, 1.0);

		// Roof neon edge highlight
		if (uv.y < near_roof + 0.0035) {
			col += horizon_glow_color * 0.75;
		}

		// Procedural window matrix
		vec2 building_uv = vec2(fract(uv.x * num_cols_near), (uv.y - near_roof) / max(h_near, 0.001));
		vec2 win_grid = fract(vec2(building_uv.x * 5.0, building_uv.y * (h_near * 90.0)));
		vec2 win_id = floor(vec2(uv.x * num_cols_near * 5.0, uv.y * 120.0));

		// Margin around windows
		if (win_grid.x > 0.22 && win_grid.x < 0.78 && win_grid.y > 0.22 && win_grid.y < 0.78) {
			float win_rand = hash21(win_id);
			// 45% of windows are illuminated
			if (win_rand > 0.55) {
				// Organic subtle flicker
				float flicker = 0.85 + 0.15 * sin(t * 3.5 + win_rand * 31.4);
				vec4 win_color;
				if (win_rand > 0.88) {
					// Neon Cyan window
					win_color = vec4(0.0, 0.95, 1.0, 1.0);
				} else if (win_rand > 0.72) {
					// Neon Magenta / Pink window
					win_color = vec4(1.0, 0.15, 0.65, 1.0);
				} else {
					// Warm amber / gold window
					win_color = vec4(1.0, 0.82, 0.35, 1.0);
				}
				col = mix(col, win_color * flicker, 0.88);
			}
		}
	}

	return col;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	// Rhythmic neon pulse
	float pulse = 0.85 + 0.15 * sin(t * pulse_speed);

	vec4 final_color = vec4(0.0);

	if (uv.y <= horizon_y) {
		// --- SKY REGION ---
		float sky_factor = smoothstep(0.0, horizon_y, uv.y);
		vec4 sky = mix(sky_top_color, sky_bottom_color, sky_factor);

		// Horizon twilight glow
		float horizon_proximity = smoothstep(horizon_y - 0.28, horizon_y, uv.y);
		sky = mix(sky, horizon_glow_color * 0.8, horizon_proximity * 0.45 * pulse);

		// Stars
		float star = get_star(uv, t);
		sky += vec4(star * 0.9, star * 0.95, star * 1.0, 0.0);

		// Render Skyscraper silhouettes on top of sky
		final_color = render_skyline(uv, t, sky);

	} else {
		// --- 3D PERSPECTIVE SCROLLING NEON GRID FLOOR ---
		float ground_d = (uv.y - horizon_y) / (1.0 - horizon_y);
		ground_d = max(ground_d, 0.0001);

		// Perspective projection
		float depth = 1.0 / ground_d;
		float x_proj = (uv.x - 0.5) * depth * 2.2;
		float z_proj = depth * 0.45 - t * grid_speed;

		// Grid line calculations
		vec2 grid_uv = vec2(x_proj, z_proj) * (grid_scale * 0.3);
		vec2 grid_fract = abs(fract(grid_uv - 0.5) - 0.5);
		vec2 grid_deriv = fwidth(grid_uv);
		vec2 grid_line = smoothstep(grid_deriv * 1.25, vec2(0.0), grid_fract);
		float line_intensity = max(grid_line.x, grid_line.y);

		// Distance fog falloff towards horizon
		float depth_fog = smoothstep(0.0, 0.85, ground_d);
		float horizon_fog = exp(-ground_d * 5.0);

		// Dynamic color: primary cyan grid with magenta accent pulses
		vec4 current_grid_color = mix(grid_color, horizon_glow_color, 0.3 * sin(t * pulse_speed + z_proj * 0.5));
		vec4 floor_color = mix(grid_base_color, current_grid_color, line_intensity * depth_fog * pulse);

		// Horizon ground glow
		floor_color += horizon_glow_color * horizon_fog * 0.55 * pulse;

		final_color = floor_color;
	}

	// --- HORIZON ATMOSPHERIC HAZE BAND ---
	float horizon_band = exp(-abs(uv.y - horizon_y) * 45.0);
	final_color += horizon_glow_color * horizon_band * 0.65 * pulse;

	// --- SUBTLE CRT SCANLINE & VIGNETTE POLISH ---
	float scanline = 0.97 + 0.03 * sin(uv.y * 360.0 * 3.14159);
	vec2 vig_uv = uv * (1.0 - uv.yx);
	float vignette = vig_uv.x * vig_uv.y * 15.0;
	vignette = clamp(pow(vignette, 0.18), 0.0, 1.0);

	final_color.rgb *= scanline * vignette;
	final_color.a = 1.0;

	COLOR = final_color;
}
