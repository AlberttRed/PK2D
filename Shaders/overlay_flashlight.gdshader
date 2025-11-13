shader_type canvas_item;

uniform vec2 center = vec2(0.5, 0.5);
uniform float radius : hint_range(0.0, 1.0) = 0.35;
uniform float softness : hint_range(0.0, 1.0) = 0.2;
uniform vec2 viewport_size = vec2(512.0, 384.0);
uniform float pixel_snap = 1.0;
uniform float pixel_block_size : hint_range(1.0, 12.0) = 1.0;
uniform float edge_sharpness : hint_range(1.0, 64.0) = 2.0;
uniform float min_softness_px : hint_range(0.0, 2.0) = 0.15;
uniform float alpha_steps : hint_range(0.0, 64.0) = 0.0;

void fragment() {
	vec2 size = max(viewport_size, vec2(1.0));
	vec2 coord = SCREEN_UV * size;
	vec2 center_px = center * size;

	if (pixel_snap > 0.5) {
		float block = max(pixel_block_size, 1.0);
		coord = floor(coord / block) * block + block * 0.5;
	}

	float min_dim = min(size.x, size.y);
	float radius_px = radius * min_dim;
	float softness_px = pow(softness, 1.5) * min_dim;
	softness_px = max(softness_px, max(min_softness_px, 0.001));

	float dist = length(coord - center_px);
	float alpha = clamp((dist - radius_px) / softness_px, 0.0, 1.0);
	alpha = pow(alpha, edge_sharpness);

	if (alpha_steps > 0.5) {
		alpha = floor(alpha * alpha_steps + 0.5) / alpha_steps;
	}

	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}

