shader_type canvas_item;

uniform float white_mix : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base_col = texture(TEXTURE, UV) * COLOR;
	vec3 mixed = mix(base_col.rgb, vec3(1.0), white_mix);
	COLOR = vec4(mixed, base_col.a);
}
