shader_type canvas_item;
render_mode unshaded;

uniform float scroll_speed = -0.6;
uniform float brightness = 1.0;

float wrap01(float value) {
	value = fract(value);
	if (value < 0.0) {
		value += 1.0;
	}
	return value;
}

void fragment() {
	vec2 uv = UV;
	uv.x = wrap01(uv.x + TIME * scroll_speed);

	vec4 tex = texture(TEXTURE, uv);
	COLOR = vec4(tex.rgb * brightness, tex.a);
}

