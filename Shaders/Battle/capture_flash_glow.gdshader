shader_type canvas_item;
render_mode blend_add, unshaded;

## Flash de captura: blanquea el asset y suma luz (glow) sobre el fondo.
uniform float white_mix : hint_range(0.0, 1.0) = 0.0;
## Multiplica el brillo aditivo (1 = normal, >1 más glow).
uniform float glow_boost : hint_range(0.5, 3.0) = 1.35;

void fragment() {
	vec4 base_col = texture(TEXTURE, UV) * COLOR;
	vec3 mixed = mix(base_col.rgb, vec3(1.0), white_mix);
	COLOR = vec4(mixed * glow_boost, base_col.a);
}
