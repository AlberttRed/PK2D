shader_type canvas_item;

uniform vec2 center = vec2(0.5, 0.5);
uniform float radius : hint_range(0.0, 1.0) = 0.35;
uniform float softness : hint_range(0.01, 0.5) = 0.2;

void fragment() {
	vec2 uv = SCREEN_UV;
	float dist = distance(uv, center);
	float outer = clamp(radius + softness, 0.0, 1.0);
	float alpha = smoothstep(radius, outer, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}

