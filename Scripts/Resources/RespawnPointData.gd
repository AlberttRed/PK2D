extends RefCounted
class_name RespawnPointData
## Estructura del último Centro Pokémon / punto seguro (blanqueo).
## Se serializa en el guardado; no desplaza al jugador al cargar partida.

var map_id: String = ""
var position: Vector2i = Vector2i.ZERO
var facing: Vector2 = Vector2.DOWN


func to_save_dictionary() -> Dictionary:
	return {
		"map_id": map_id,
		"position": {"x": position.x, "y": position.y},
		"facing": {"x": facing.x, "y": facing.y},
	}


static func from_save_dictionary(
	d: Dictionary,
	default_map: String,
	default_pos: Vector2i,
	default_facing: Vector2
) -> RespawnPointData:
	var o := RespawnPointData.new()
	o.map_id = str(d.get("map_id", default_map))
	if o.map_id.is_empty():
		o.map_id = default_map
	var pos_any: Variant = d.get("position", null)
	if pos_any is Vector2i:
		o.position = pos_any
	elif pos_any is Dictionary:
		o.position = Vector2i(int((pos_any as Dictionary).get("x", default_pos.x)), int((pos_any as Dictionary).get("y", default_pos.y)))
	else:
		o.position = default_pos
	var fac_any: Variant = d.get("facing", null)
	if fac_any is Vector2:
		o.facing = fac_any
	elif fac_any is Dictionary:
		var fd: Dictionary = fac_any
		o.facing = Vector2(float(fd.get("x", default_facing.x)), float(fd.get("y", default_facing.y)))
	else:
		o.facing = default_facing
	return o
