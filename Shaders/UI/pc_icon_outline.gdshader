shader_type canvas_item;
render_mode unshaded, blend_mix;

/// Contorno rojo solo en el borde (anillo), sin relleno detrás del icono.
uniform vec4 outline_color : source_color = vec4(0.973, 0.282, 0.282, 1.0);
uniform int outline_size : hint_range(1, 4) = 2;

void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec2 ps = TEXTURE_PIXEL_SIZE;
	float neighbor_a = 0.0;
	int r = outline_size;
	for (int x = -r; x <= r; x++) {
		for (int y = -r; y <= r; y++) {
			if (x == 0 && y == 0) {
				continue;
			}
			neighbor_a = max(neighbor_a, texture(TEXTURE, UV + vec2(float(x), float(y)) * ps).a);
		}
	}
	// Solo píxeles transparentes junto a opacos = anillo exterior.
	float ring = neighbor_a * (1.0 - a);
	COLOR = vec4(outline_color.rgb, ring * outline_color.a);
}
