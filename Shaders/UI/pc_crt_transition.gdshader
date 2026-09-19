shader_type canvas_item;
render_mode unshaded, blend_mix;

/// 0 = pantalla apagada (negro), 1 = abierta (overlay transparente).
/// 0→line_end: punto blanco → línea horizontal.
/// line_end→1: la línea se abre arriba/abajo revelando el contenido.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float line_end : hint_range(0.05, 0.6) = 0.32;
/// Grosor de la línea en UV (mitad).
uniform float line_half_uv : hint_range(0.0005, 0.02) = 0.0035;
/// Borde blanco al abrir/cerrar.
uniform float rim_uv : hint_range(0.0, 0.05) = 0.007;

void fragment() {
	float p = clamp(progress, 0.0, 1.0);
	if (p <= 0.0001) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}
	if (p >= 0.999) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		return;
	}

	float beam_w;
	float open_t;
	if (p <= line_end) {
		beam_w = p / max(line_end, 0.0001);
		open_t = 0.0;
	} else {
		beam_w = 1.0;
		open_t = (p - line_end) / max(1.0 - line_end, 0.0001);
	}

	float dx = abs(UV.x - 0.5) * 2.0;
	float dy = abs(UV.y - 0.5) * 2.0;
	float slit = mix(line_half_uv, 1.0, open_t);

	if (dx > beam_w || dy > slit) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	if (open_t < 0.001) {
		COLOR = vec4(1.0, 1.0, 1.0, 1.0);
		return;
	}

	float rim = max(rim_uv * (1.0 - open_t * 0.9), 0.0012);
	if (dy > slit - rim) {
		COLOR = vec4(1.0, 1.0, 1.0, 1.0);
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
}
