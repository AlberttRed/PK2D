shader_type canvas_item;
render_mode unshaded, blend_mix;

/// Tamaño del bloque de mosaico en píxeles de atlas (1 = nítido). Estilo PC FRLG.
/// UV ya viene en espacio de atlas (AtlasTexture); no usar tamaño de región.
uniform float block_size : hint_range(1.0, 64.0) = 1.0;

void fragment() {
	float b = max(block_size, 1.0);
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	vec2 snapped = (floor(px / b) + 0.5) * b;
	COLOR = texture(TEXTURE, snapped * TEXTURE_PIXEL_SIZE);
}
