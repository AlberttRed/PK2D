extends Node3D
class_name MapScene3D
## Script base para mapas del overworld 3D (equivalente a `MapScene` en 2D).
##
## USO:
## 1. Duplicar `Scenes/Overworld3D/Maps/MapTemplate3D.tscn` (o heredar de ella).
## 2. Guardar como `NombreMapa.tscn` — el id de mapa es el basename (lo indexa World3DSystem).
## 3. Pintar Floor / Objects y añadir Event3D bajo `OverworldGrid3D/Events`.
## 4. Registrar la escena en `Overworld.tscn` → World3DSystem.world_map_scenes.
##
## No incluye Player3D: lo instancia World3DSystem. Tampoco chunks/vecinos (aún no en 3D).

@export_group("World Configuration")
## Si true, este mapa se considera interior (casa/cueva/edificio). Sincroniza el flag `indoor`.
@export var is_indoor: bool = false
## ID del mapa (vacío = nombre del nodo / archivo de escena).
@export var map_id: String = ""
## Nombre para el cartel de ubicación. Vacío = no mostrar cartel.
@export var display_name: String = ""

@export_group("Overlay Settings")
@export_range(0.0, 1.0, 0.01) var overlay_darkness: float = 0.0
@export_enum("none", "rain", "snow", "fog", "storm") var overlay_weather: String = "none"
@export var overlay_flashlight_required: bool = false

@export_group("Battle Visuals")
@export var battle_back: BattleBackEnum.Values = BattleBackEnum.Values.FIELD

@export_group("Audio")
@export var bgm: AudioStream
@export_range(0.0, 8.0, 0.05) var bgm_fade: float = 1.0

@onready var grid: OverworldGrid3D = $OverworldGrid3D


func _ready() -> void:
	if map_id.is_empty():
		map_id = name


func get_grid() -> OverworldGrid3D:
	return grid


func get_location_display_name() -> String:
	return display_name.strip_edges()


func get_battle_back() -> BattleBackEnum.Values:
	return battle_back


## Misma forma que MapScene: OverlayLayer / WorldSystem pueden leerlo por duck typing.
func get_overlay_settings() -> Dictionary:
	return {
		"darkness": clampf(overlay_darkness, 0.0, 1.0),
		"weather": overlay_weather,
		"flashlight_required": overlay_flashlight_required,
	}


func get_bgm_settings() -> Dictionary:
	return {
		"bgm": bgm,
		"fade": bgm_fade,
	}
