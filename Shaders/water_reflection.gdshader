shader_type canvas_item;

// Shader para recortar el reflejo según la máscara de agua
// La máscara se pasa como textura y solo muestra el reflejo donde la máscara es blanca

uniform sampler2D reflection_mask : source_color, hint_default_white;
uniform float reflection_alpha : hint_range(0.0, 1.0) = 0.45;
uniform vec4 reflection_tint : source_color = vec4(0.7, 0.8, 1.0, 1.0);

void fragment() {
	vec4 sprite_color = texture(TEXTURE, UV);
	vec4 mask_color = texture(reflection_mask, SCREEN_UV);

	// Solo mostrar reflejo donde la máscara tiene alpha > 0.5
	float mask_alpha = mask_color.a;

	// Aplicar tint y alpha
	vec4 final_color = sprite_color * reflection_tint;
	final_color.a *= reflection_alpha * mask_alpha;

	COLOR = final_color;
}

