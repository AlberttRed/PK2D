shader_type spatial;
// Tiles animados exportados desde Crocotile ("Export UV Animations").
//
// Los vértices animados traen los UV codificados en el .glb:
//   U = 100 + índice de animación
//   V = 100 * (esquina + 1) + índice en el array `custom` de la animación
// Los datos de cada animación (frames, duraciones, UV por esquina y tiempos custom) los rellena
// `Scripts/Overworld3D/tools/build_uv_animated_material.gd` a partir de uvAnimation.txt.
// Los vértices con U < 100 (tiles estáticos) conservan su UV.
//
// Como el GridMap comparte el material entre todas las celdas del item, la animación va sincronizada
// (igual que los tiles animados del TileSet 2D); la variación entre tiles viene de `custom`.
//
// IMPORTANTE: el .glb debe importarse con `meshes/force_disable_compression = true`.
render_mode cull_disabled, specular_schlick_ggx, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform vec3 albedo_tint = vec3(1.0);
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;
// Multiplicador de velocidad de la animación (1.0 = la definida en Crocotile).
uniform float speed = 1.0;
// Elevación (m) del tile para evitar z-fighting cuando se dibuja sobre el suelo (y = 0).
uniform float y_lift = 0.02;

// Capacidad: 4 animaciones, hasta 16 frames cada una, hasta 8 tiempos custom por animación.
uniform int anim_frame_count[4];
uniform float anim_total[4];
// Instante (s) en que termina cada frame, acumulado: índice = anim * 16 + frame.
uniform float frame_end[64];
// UV por esquina del frame: índice = (anim * 16 + frame) * 4 + esquina.
uniform vec2 frame_uv[256];
// Tiempo de inicio (s) de cada valor `custom`: índice = anim * 8 + custom.
uniform float custom_start[32];

void vertex() {
	if (UV.x >= 99.5) {
		int anim = clamp(int(floor(UV.x - 100.0 + 0.5)), 0, 3);
		int code = int(floor(UV.y + 0.5));
		int corner = clamp(code / 100 - 1, 0, 3);
		int custom_idx = clamp(code - (corner + 1) * 100, 0, 7);
		int count = anim_frame_count[anim];
		if (count > 0) {
			float total = max(anim_total[anim], 0.0001);
			float t = mod(TIME * speed + custom_start[anim * 8 + custom_idx], total);
			int frame = 0;
			for (int i = 0; i < 15; i++) {
				if (i < count - 1 && t >= frame_end[anim * 16 + i]) {
					frame = i + 1;
				}
			}
			UV = frame_uv[(anim * 16 + frame) * 4 + corner];
		}
	}
	VERTEX.y += y_lift;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = tex.rgb * albedo_tint;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
