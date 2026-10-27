extends SceneTree
## Genera un ShaderMaterial para tiles animados de Crocotile (UV Animations) a partir de uvAnimation.txt.
##
## Uso (valores por defecto = Flower):
##   godot --headless --path . -s res://Scripts/Overworld3D/tools/build_uv_animated_material.gd
## Con parámetros:
##   ... -s res://Scripts/Overworld3D/tools/build_uv_animated_material.gd -- \
##       json=res://.../uvAnimation.txt texture=res://.../Flower_0.png out=res://.../Flower_UVAnimated.tres
##
## Las animaciones se indexan igual que en el JSON (el U del vértice = 100 + índice). Capacidad del shader:
## 4 animaciones, 16 frames por animación y 8 valores `custom` por animación (ver UVAnimatedTile.gdshader).

const SHADER_PATH := "res://Shaders/Overworld3D/UVAnimatedTile.gdshader"
const MAX_ANIMS := 4
const MAX_FRAMES := 16
const MAX_CUSTOM := 8

const DEFAULT_JSON := "res://Resources/Overworld3D/Models/uvAnimation.txt"
const DEFAULT_TEXTURE := "res://Resources/Overworld3D/Models/Flower_0.png"
const DEFAULT_OUT := "res://Resources/Overworld3D/Materials/Flower_UVAnimated.tres"


func _initialize() -> void:
	var args := _parse_args()
	var json_path: String = args.get("json", DEFAULT_JSON)
	var texture_path: String = args.get("texture", DEFAULT_TEXTURE)
	var out_path: String = args.get("out", DEFAULT_OUT)

	var shader := load(SHADER_PATH) as Shader
	if shader == null:
		push_error("No se pudo cargar el shader: %s" % SHADER_PATH)
		quit(1)
		return
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_error("No se pudo cargar la textura: %s" % texture_path)
		quit(1)
		return
	var anims = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (anims is Array):
		push_error("uvAnimation.txt inválido (se esperaba un array JSON): %s" % json_path)
		quit(1)
		return
	if anims.size() > MAX_ANIMS:
		push_warning("El JSON tiene %d animaciones; solo se usan las %d primeras." % [anims.size(), MAX_ANIMS])

	var frame_count := PackedInt32Array()
	frame_count.resize(MAX_ANIMS)
	var total := PackedFloat32Array()
	total.resize(MAX_ANIMS)
	var frame_end := PackedFloat32Array()
	frame_end.resize(MAX_ANIMS * MAX_FRAMES)
	var frame_uv := PackedVector2Array()
	frame_uv.resize(MAX_ANIMS * MAX_FRAMES * 4)
	var custom_start := PackedFloat32Array()
	custom_start.resize(MAX_ANIMS * MAX_CUSTOM)

	for a in mini(anims.size(), MAX_ANIMS):
		var anim: Dictionary = anims[a]
		var frames: Array = anim.get("frame", [])
		if frames.size() > MAX_FRAMES:
			push_warning("Animación %d ('%s'): %d frames; solo se usan %d." % [
				a, anim.get("name", ""), frames.size(), MAX_FRAMES])
		var n := mini(frames.size(), MAX_FRAMES)
		var t := 0.0
		for f in n:
			var frame: Dictionary = frames[f]
			t += maxf(float(frame.get("duration", 0.0)), 0.0001)
			frame_end[a * MAX_FRAMES + f] = t
			var uvs: Array = frame.get("uv", [])
			for c in mini(uvs.size(), 4):
				frame_uv[(a * MAX_FRAMES + f) * 4 + c] = Vector2(float(uvs[c]["x"]), float(uvs[c]["y"]))
		frame_count[a] = n
		total[a] = t
		var customs: Array = anim.get("custom", [])
		for i in mini(customs.size(), MAX_CUSTOM):
			custom_start[a * MAX_CUSTOM + i] = float(customs[i])
		print("Animación %d '%s': %d frames, %.3f s (tileset %s)" % [
			a, anim.get("name", ""), n, t, str(anim.get("tileset", "?"))])

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("albedo_tex", texture)
	mat.set_shader_parameter("anim_frame_count", frame_count)
	mat.set_shader_parameter("anim_total", total)
	mat.set_shader_parameter("frame_end", frame_end)
	mat.set_shader_parameter("frame_uv", frame_uv)
	mat.set_shader_parameter("custom_start", custom_start)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var err := ResourceSaver.save(mat, out_path)
	if err != OK:
		push_error("Error guardando material (%s): %s" % [out_path, error_string(err)])
		quit(1)
		return
	print("Material generado: ", out_path)
	quit(0)


func _parse_args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		var parts := String(arg).split("=", false, 1)
		if parts.size() == 2:
			result[parts[0]] = parts[1]
	return result
