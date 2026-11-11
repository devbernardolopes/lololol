shader_type canvas_item;

// Glint sweep for items, cards, UI and collectibles. Animate `progress` from 0 to 1,
// or set `auto_speed` above 0 and it sweeps by itself, pausing between sweeps.
group_uniforms Shine;
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float progress : hint_range(-0.5, 1.5) = 0.55;
uniform float width : hint_range(0.01, 0.6) = 0.16;
uniform float angle : hint_range(-1.57, 1.57) = 0.6;
uniform float intensity : hint_range(0.0, 2.0) = 1.1;
group_uniforms Variations;
uniform float bands : hint_range(1.0, 3.0, 1.0) = 1.0;       // 1 to 3 parallel bands
uniform float band_gap : hint_range(0.02, 0.5) = 0.12;       // distance between bands
uniform float band_falloff : hint_range(0.0, 1.0) = 0.45;    // how much thinner / fainter each extra band is
uniform float hardness : hint_range(0.0, 1.0) = 0.0;         // 0 soft glow, 1 crisp stylised stripe
uniform vec4 tail_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);  // colour at the edges of the band
group_uniforms Auto;
uniform float auto_speed : hint_range(0.0, 3.0) = 0.0;       // sweeps per second, 0 = use progress
uniform float auto_pause : hint_range(0.0, 3.0) = 1.0;       // seconds between sweeps

varying vec4 vertex_tint;   // modulate and self_modulate, applied at the end

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float p = progress;
	if (auto_speed > 0.0) {
		float period = 1.0 / auto_speed + auto_pause;
		p = mod(TIME, period) * auto_speed * 1.8 - 0.4;   // runs from -0.4 to past 1.4, then waits
	}
	float d = UV.x * cos(angle) + UV.y * sin(angle);
	float aa = fwidth(d) + 1e-4;
	float glow = 0.0;
	vec3 tint = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		if (float(i) >= bands) break;
		float fi = float(i);
		float w = width * pow(1.0 - band_falloff * 0.6, fi);
		float x = abs(d - (p - fi * (band_gap + width)));
		float soft = smoothstep(w, 0.0, x);
		float hard = 1.0 - smoothstep(w * 0.55 - aa, w * 0.55 + aa, x);
		float b = mix(soft, hard, hardness) * pow(1.0 - band_falloff, fi);
		if (b > glow) {
			glow = b;
			tint = mix(tail_color.rgb, shine_color.rgb, mix(soft, 1.0, hardness));
		}
	}
	col.rgb += tint * glow * intensity * col.a;
	COLOR = col;
	COLOR *= vertex_tint;
}
