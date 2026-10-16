shader_type spatial;
// Suelos GridMap: evita costuras por muestreo en el borde del atlas
// y reduce z-fighting con un offset mínimo de profundidad.
render_mode cull_disabled, specular_schlick_ggx, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
// Rect del tile en el atlas (x, y, w, h) en UV 0..1
uniform vec4 uv_rect = vec4(0.0, 0.140625, 0.015625, 0.015625);
// Contracción en texels del tile (0.5 = medio texel)
uniform float texel_inset : hint_range(0.0, 2.0) = 0.75;
uniform float tile_resolution = 32.0;
uniform vec3 albedo_tint = vec3(1.0);

void fragment() {
	vec2 local = (UV - uv_rect.xy) / max(uv_rect.zw, vec2(1e-6));
	float inset = texel_inset / max(tile_resolution, 1.0);
	local = clamp(local, vec2(inset), vec2(1.0 - inset));
	vec2 atlas_uv = uv_rect.xy + local * uv_rect.zw;
	vec4 tex = texture(albedo_tex, atlas_uv);
	ALBEDO = tex.rgb * albedo_tint;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
