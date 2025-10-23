shader_type canvas_item;

// Textura de transición (máscara en escala de grises)
uniform sampler2D transition_mask;
// Progreso de la transición (0.0 = sin transición, 1.0 = completamente negro)
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Suavizado del borde de la transición
uniform float smoothness : hint_range(0.0, 0.1) = 0.02;

void fragment() {
	// Obtener el valor de la máscara (escala de grises)
	float mask_value = texture(transition_mask, UV).r;

	// Calcular la opacidad basada SOLO en el valor de la máscara
	float alpha = smoothstep(progress - smoothness, progress + smoothness, mask_value);

	// Invertir para que avance correctamente
	alpha = 1.0 - alpha;

	// Color negro con la opacidad calculada
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
