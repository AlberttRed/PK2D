class_name SpriteFramesGenerator

## Generador automático de SpriteFrames desde spritesheets 4x4
## 
## Layout esperado (estilo Pokémon/RPG Maker):
##   Row 0: Down (idle en col 0, step_right en col 1, idle en col 2, step_left en col 3)
##   Row 1: Up    (idle en col 0, step_right en col 1, idle en col 2, step_left en col 3)
##   Row 2: Left  (idle en col 0, step_right en col 1, idle en col 2, step_left en col 3)
##   Row 3: Right (idle en col 0, step_right en col 1, idle en col 2, step_left en col 3)

## Genera un SpriteFrames estándar desde un spritesheet 4x4
static func generate_from_4x4_spritesheet(
	texture: Texture2D, 
	frame_size := Vector2(32, 48),
	walk_speed := 7.5,
	run_speed := 15.0
) -> SpriteFrames:
	if not texture:
		return null
	
	var frames = SpriteFrames.new()
	
	# Direcciones: row 0 = down, row 1 = left, row 2 = right, row 3 = up
	var directions = ["down", "left", "right", "up"]
	
	# Crear animaciones walk y run para cada dirección
	for row_idx in range(4):
		var dir_name = directions[row_idx]
		
		# LEFT stride: idle (col 0) -> step_left (col 3)
		var walk_left_anim = "walk_%s_left" % dir_name
		frames.add_animation(walk_left_anim)
		frames.set_animation_loop(walk_left_anim, false)
		frames.set_animation_speed(walk_left_anim, walk_speed)
		frames.add_frame(walk_left_anim, _create_atlas_texture(texture, 3, row_idx, frame_size))  # Col 3 = step left
		frames.add_frame(walk_left_anim, _create_atlas_texture(texture, 2, row_idx, frame_size))  # Col 2 = idle
		
		# RIGHT stride: idle (col 2) -> step_right (col 1)
		var walk_right_anim = "walk_%s_right" % dir_name
		frames.add_animation(walk_right_anim)
		frames.set_animation_loop(walk_right_anim, false)
		frames.set_animation_speed(walk_right_anim, walk_speed)
		frames.add_frame(walk_right_anim, _create_atlas_texture(texture, 1, row_idx, frame_size))  # Col 1 = step right
		frames.add_frame(walk_right_anim, _create_atlas_texture(texture, 0, row_idx, frame_size))  # Col 0 = idle
		
		# RUN animations (mismos frames pero más rápidos)
		var run_left_anim = "run_%s_left" % dir_name
		frames.add_animation(run_left_anim)
		frames.set_animation_loop(run_left_anim, false)
		frames.set_animation_speed(run_left_anim, run_speed)
		frames.add_frame(run_left_anim, _create_atlas_texture(texture, 3, row_idx, frame_size))
		frames.add_frame(run_left_anim, _create_atlas_texture(texture, 2, row_idx, frame_size))
		
		var run_right_anim = "run_%s_right" % dir_name
		frames.add_animation(run_right_anim)
		frames.set_animation_loop(run_right_anim, false)
		frames.set_animation_speed(run_right_anim, run_speed)
		frames.add_frame(run_right_anim, _create_atlas_texture(texture, 1, row_idx, frame_size))
		frames.add_frame(run_right_anim, _create_atlas_texture(texture, 0, row_idx, frame_size))
	
	# Animación idle (frame base de cada dirección - col 0)
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", walk_speed)
	for row_idx in range(4):
		frames.add_frame("idle", _create_atlas_texture(texture, 0, row_idx, frame_size))
	
	return frames

## Crea un AtlasTexture para una región específica del spritesheet
static func _create_atlas_texture(atlas: Texture2D, col: int, row: int, frame_size: Vector2) -> AtlasTexture:
	var tex = AtlasTexture.new()
	tex.atlas = atlas
	tex.region = Rect2(col * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
	return tex

