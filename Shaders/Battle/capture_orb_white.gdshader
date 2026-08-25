shader_type canvas_item;
render_mode blend_add, unshaded;

## Solo usa el alpha del asset; el RGB es blanco puro (sin crema/amarillo del PNG).
uniform float glow_boost : hint_range(0.5, 4.0) = 1.8;

void fragment() {
	float a = texture(TEXTURE, UV).a * COLOR.a;
	COLOR = vec4(COLOR.rgb * glow_boost, a);
}
