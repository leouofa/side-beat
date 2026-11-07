shader_type canvas_item;
render_mode unshaded;

// Layer 1: Side Beat Full-Screen Arcade Post-FX Shader
// Supports:
//   - CRT Presets: 0 = Off, 1 = Crisp Arcade (Default), 2 = Heavy Retro CRT
//   - Radial Screen-Space Shockwave Ripple + High-Contrast Impact Frame (Perfect Parry & Pantheon Super)
//   - RGB Channel Split + Digital Scanline Roll Glitch (Shared-Soul Morph & Boss Phase Shift)

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform int crt_mode : hint_range(0, 2) = 1;
uniform float barrel_curvature : hint_range(0.0, 0.12) = 0.0;
uniform float scanline_opacity : hint_range(0.0, 0.6) = 0.08;
uniform float phosphor_mask_strength : hint_range(0.0, 0.5) = 0.06;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.22;

// Dynamic Radial Shockwave & Parry/Super Impact Frame
uniform vec2 ripple_center = vec2(0.5, 0.5);
uniform float ripple_progress : hint_range(0.0, 1.0) = 0.0;
uniform float ripple_strength : hint_range(0.0, 0.08) = 0.0;
uniform float impact_flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 impact_flash_color : source_color = vec4(1.0, 0.88, 0.4, 1.0);

// Dynamic Glitch & Chromatic Split (Morph / Boss Phase Shift)
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glitch_tint : source_color = vec4(0.0, 0.83, 1.0, 1.0);
uniform float shader_time = 0.0;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

vec2 apply_barrel_warp(vec2 uv, float amt) {
	if (amt <= 0.0001) {
		return uv;
	}
	vec2 centered = uv * 2.0 - 1.0;
	vec2 offset = centered.yx * centered.yx * amt;
	centered += centered * offset;
	return centered * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = shader_time;

	// 1. Apply CRT barrel curvature when in Heavy Retro CRT mode (or custom curvature)
	float active_curve = (crt_mode == 2) ? max(barrel_curvature, 0.038) : barrel_curvature;
	uv = apply_barrel_warp(uv, active_curve);

	// Out-of-bounds bezel check for curved CRT mode
	bool out_of_bezel = (crt_mode == 2) && (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0);
	vec2 sample_uv = clamp(uv, vec2(0.001), vec2(0.999));

	// 2. Dynamic Digital Block-Slice & Scanline Roll Glitch (Morph / Boss Phase Shift)
	float chroma_offset = 0.0;
	if (glitch_intensity > 0.001) {
		float slice_y = floor(sample_uv.y * 28.0);
		float slice_rnd = hash11(slice_y + floor(t * 42.0));
		float slice_gate = step(1.0 - glitch_intensity * 0.65, slice_rnd);
		float horiz_tear = (hash11(slice_y * 3.7 + floor(t * 60.0)) - 0.5) * 0.045 * glitch_intensity * slice_gate;
		sample_uv.x = clamp(sample_uv.x + horiz_tear, 0.001, 0.999);
		chroma_offset = (0.004 + 0.014 * glitch_intensity) * (0.6 + 0.4 * slice_gate);
	}

	// 3. Dynamic Radial Shockwave Ripple (Perfect Parry & Pantheon Super)
	float ripple_ring_glow = 0.0;
	if (ripple_strength > 0.0001 && ripple_progress > 0.0 && ripple_progress < 1.0) {
		vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.00001), 1.0);
		vec2 delta = (sample_uv - ripple_center) * aspect;
		float dist = length(delta);
		float radius = ripple_progress * 1.15;
		float band = abs(dist - radius);
		float wave = smoothstep(0.11, 0.0, band);
		float wave_osc = sin((dist - radius) * 55.0) * wave;
		vec2 dir = (dist > 0.0001) ? normalize(delta) : vec2(0.0, 1.0);
		float fade = 1.0 - ripple_progress;
		sample_uv = clamp(sample_uv + dir * wave_osc * ripple_strength * fade, vec2(0.001), vec2(0.999));
		ripple_ring_glow = wave * fade * clamp(ripple_strength * 28.0, 0.0, 1.0);
		chroma_offset = max(chroma_offset, wave * fade * 0.008);
	}

	// Baseline subtle chromatic fringe in Heavy Retro CRT mode
	if (crt_mode == 2) {
		chroma_offset = max(chroma_offset, 0.0016);
	}

	// 4. Sample Screen Texture (with RGB Chromatic Aberration when active)
	vec3 col;
	if (chroma_offset > 0.0001) {
		float r = texture(screen_texture, clamp(sample_uv + vec2(chroma_offset, 0.0), vec2(0.001), vec2(0.999))).r;
		float g = texture(screen_texture, sample_uv).g;
		float b = texture(screen_texture, clamp(sample_uv - vec2(chroma_offset, 0.0), vec2(0.001), vec2(0.999))).b;
		col = vec3(r, g, b);
	} else {
		col = texture(screen_texture, sample_uv).rgb;
	}

	// 5. Add Glitch Scanline Roll Tint & Shockwave Ring Highlight
	if (glitch_intensity > 0.001) {
		float roll_bar = 0.5 + 0.5 * sin(sample_uv.y * 45.0 - t * 28.0);
		col = mix(col, col + glitch_tint.rgb * 0.42, glitch_intensity * roll_bar * 0.55);
	}
	if (ripple_ring_glow > 0.001) {
		col += impact_flash_color.rgb * ripple_ring_glow * 0.65;
	}

	// 6. High-Contrast Inverted / Gold Impact Frame (Perfect Parry & Pantheon Super)
	if (impact_flash_strength > 0.001) {
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 high_contrast = mix(vec3(1.0 - step(0.45, luma)), impact_flash_color.rgb * (0.45 + luma * 1.15), 0.72);
		col = mix(col, high_contrast, impact_flash_strength * 0.78);
	}

	// 7. CRT Scanlines, RGB Phosphor Subpixel Mask, and Vignette
	if (crt_mode > 0) {
		float eff_scan = (crt_mode == 2) ? max(scanline_opacity, 0.22) : scanline_opacity;
		float eff_mask = (crt_mode == 2) ? max(phosphor_mask_strength, 0.16) : phosphor_mask_strength;
		float eff_vig = (crt_mode == 2) ? max(vignette_strength, 0.36) : vignette_strength;

		float screen_h = 1.0 / max(SCREEN_PIXEL_SIZE.y, 0.0001);
		float scan_wave = 0.5 + 0.5 * sin(sample_uv.y * screen_h * 3.14159265);
		col *= 1.0 - eff_scan * (1.0 - scan_wave);

		// RGB triad phosphor subpixel modulation
		float px_x = mod(FRAGCOORD.x, 3.0);
		vec3 triad = (px_x < 1.0) ? vec3(1.12, 0.94, 0.94) : ((px_x < 2.0) ? vec3(0.94, 1.12, 0.94) : vec3(0.94, 0.94, 1.12));
		col = mix(col, col * triad, eff_mask);

		// Rolling refresh bar in Heavy Retro mode
		if (crt_mode == 2) {
			float refresh_bar = smoothstep(0.08, 0.0, abs(fract(sample_uv.y - t * 0.18) - 0.5));
			col += vec3(0.03, 0.04, 0.06) * refresh_bar;
		}

		// Corner vignette
		vec2 vig_uv = sample_uv * (1.0 - sample_uv.yx);
		float vig = clamp(pow(max(vig_uv.x * vig_uv.y * 16.0, 0.0), eff_vig), 0.0, 1.0);
		col *= vig;
	}

	if (out_of_bezel) {
		col = vec3(0.01, 0.01, 0.02);
	}

	COLOR = vec4(col, 1.0);
}
