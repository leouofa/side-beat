shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

// Layer 2A: Fighter Surface FX Next-Pass Shader
// Provides:
//   - Crisp 2-3 frame additive Hit-Strike emission flash during hitstop
//   - Pantheon-colored Fresnel Rim Aura for active God & Super-Armor / Enrage pulse for Bosses & Bruisers

uniform float hit_flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 hit_flash_color : source_color = vec4(1.0, 0.96, 0.82, 1.0);

uniform vec4 rim_color : source_color = vec4(0.0, 0.83, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 4.0) = 0.85;
uniform float rim_power : hint_range(1.0, 8.0) = 2.8;

uniform float armor_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float enrage_factor : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(0.5, 16.0) = 3.5;

void fragment() {
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, rim_power);

	// Rhythmic aura & super-armor pulse
	float speed = mix(pulse_speed, 11.0, enrage_factor);
	float pulse = 0.78 + 0.22 * sin(TIME * speed + VERTEX.y * 3.0);

	// Blend between standard rim color, golden Super-Armor shell, and crimson Enrage strobe
	vec3 active_rim_col = rim_color.rgb;
	if (armor_ratio > 0.01) {
		vec3 armor_gold = vec3(1.0, 0.84, 0.15);
		active_rim_col = mix(active_rim_col, armor_gold, 0.55 * armor_ratio);
	}
	if (enrage_factor > 0.01) {
		vec3 enrage_crimson = vec3(1.0, 0.12, 0.26);
		float strobe = 0.5 + 0.5 * sin(TIME * 18.0);
		active_rim_col = mix(active_rim_col, enrage_crimson, enrage_factor * (0.5 + 0.5 * strobe));
	}

	float total_rim = fresnel * rim_strength * pulse * (1.0 + armor_ratio * 0.65 + enrage_factor * 0.55);
	vec3 rim_contrib = active_rim_col * total_rim;

	// Hit-Strike Flash (full surface + extra hot rim flare)
	vec3 flash_contrib = hit_flash_color.rgb * hit_flash_amount * (0.85 + 0.55 * fresnel);

	ALBEDO = rim_contrib + flash_contrib;
	ALPHA = clamp(total_rim + hit_flash_amount, 0.0, 1.0);
}
