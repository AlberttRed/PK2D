shader_type canvas_item;

// Textura del overlay (OverlayHeal.png, OverlayStatUp.png, etc.)
uniform sampler2D overlay_texture : repeat_enable;

// Progreso de la animación (0.0 a 1.0)
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// Si true, el efecto va hacia arriba; si false, va hacia abajo
uniform bool animate_up = false;

// Intensidad/opacidad del overlay
uniform float overlay_alpha : hint_range(0.0, 1.0) = 0.7;

// Velocidad del scroll de la animación (mayor = más rápido)
uniform float scroll_speed : hint_range(1.0, 10.0) = 3.0;

// Escala del overlay (mayor = overlay más pequeño/repetido)
uniform float overlay_scale : hint_range(1.0, 10.0) = 2.0;

void fragment() {
	// Obtener el color original del sprite del Pokémon
	vec4 sprite_color = texture(TEXTURE, UV);

	// Calcular UVs normalizadas independientes del atlas
	// TEXTURE_PIXEL_SIZE da el tamaño de un píxel en coordenadas UV
	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 normalized_uv = UV * texture_size / 96.0; // 96 = tamaño de referencia para sprites Pokémon

	// Calcular UVs repetidas para el overlay (solo overlay_scale afecta el tamaño)
	vec2 overlay_uv = normalized_uv / overlay_scale;

	// Desplazar las UVs según el progreso para crear el efecto de scroll
	// Multiplicamos por overlay_scale para que la velocidad sea proporcional al tamaño
	if (animate_up) {
		// Mover hacia arriba: las ondas suben (de abajo hacia arriba)
		overlay_uv.y += progress / scroll_speed;
	} else {
		// Mover hacia abajo: las ondas bajan (de arriba hacia abajo)
		overlay_uv.y -= progress / scroll_speed;
	}

	// Obtener el color del overlay con las UVs modificadas
	vec4 overlay_color = texture(overlay_texture, overlay_uv);

	// Solo aplicar overlay donde el sprite tiene alpha > 0 (no es transparente)
	vec4 final_color = sprite_color;

	if (sprite_color.a > 0.1 && overlay_color.a > 0.1) {
		// Mezclar el overlay sobre el sprite usando el alpha del sprite como máscara
		final_color.rgb = mix(sprite_color.rgb, overlay_color.rgb, overlay_color.a * overlay_alpha);
	}

	COLOR = final_color;
}
