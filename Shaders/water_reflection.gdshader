shader_type canvas_item;

group_uniforms Wave;
uniform bool enableWave = true;
uniform float waveAmplitude : hint_range(0.0, 10.0, 0.1) = 1.0; // Amplitud de la ola en píxeles
uniform float waveFrequency : hint_range(0.0, 20.0, 0.1) = 4.0; // Frecuencia de la ola
uniform float waveSpeed : hint_range(0.0, 5.0, 0.1) = 1.0; // Velocidad de la ola

group_uniforms Color;
uniform vec3 color: source_color = vec3(1.0);
uniform float colorMix: hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float alpha: hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	vec2 uv = UV;

	if (enableWave) {
		// Efecto de ola simple: desplazamiento horizontal basado en la posición Y
		float wave = sin(UV.y * waveFrequency + TIME * waveSpeed) * waveAmplitude * TEXTURE_PIXEL_SIZE.x;
		uv.x += wave;
	}

	// Clamp UV para evitar muestrear fuera de la textura
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	COLOR = texture(TEXTURE, uv);
	COLOR.rgb = mix(COLOR.rgb, color, colorMix);
	COLOR.a *= alpha;
}
