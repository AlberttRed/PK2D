shader_type canvas_item;

// Varias bandas diagonales blancas que recorren el hielo (reflejo).
uniform float shine_pos : hint_range(-0.5, 1.5) = -0.5;
uniform float shine_width : hint_range(0.02, 0.4) = 0.055;
uniform float shine_intensity : hint_range(0.0, 2.0) = 1.15;
uniform float band_gap : hint_range(0.0, 0.2) = 0.05;

void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;
	float axis = UV.x * 0.62 + UV.y * 0.38;
	float band = 1.0 - smoothstep(0.0, shine_width, abs(axis - shine_pos));
	band += 0.72 * (1.0 - smoothstep(0.0, shine_width * 0.75, abs(axis - shine_pos - band_gap)));
	band += 0.48 * (1.0 - smoothstep(0.0, shine_width * 0.55, abs(axis - shine_pos - band_gap * 2.0)));
	col.rgb += vec3(1.0) * min(band, 1.0) * shine_intensity * col.a;
	COLOR = col;
}
