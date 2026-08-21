## Clase TrainerClassData
##
## Resource que define una clase/tipo de entrenador (Líder de Gimnasio, Alto Mando, etc.)
## Se guarda como .tres en Resources/Data/TrainerClasses/
##
## Cada clase de entrenador puede tener:
## - Nombre localizado
## - Multiplicador de recompensa base
## - Sprites específicos (opcional)
## - Configuración de IA por defecto
extends Resource
class_name TrainerClassData

## ID único de la clase de entrenador
@export var id: int = 0

## Nombre interno (ej: "gym_leader", "elite_four")
@export var internal_name: String = ""

## Nombre para mostrar (ej: "Líder de Gimnasio", "Alto Mando")
@export var display_name: String = "Entrenador"

## Multiplicador para calcular recompensa de dinero
## Formula típica: base_reward * nivel_promedio * multiplicador
@export var reward_multiplier: float = 1.0

## Sprites por defecto para esta clase (opcional)
## Si son null, cada entrenador usa sus propios sprites
@export var default_battle_front_sprite: Texture2D = null
@export var default_battle_back_sprite: Texture2D = null

## IA por defecto para esta clase (opcional; se usa si el trainer no define ai_profile)
@export var default_ai: TrainerBattleIA = null

## Descripción (opcional, para notas)
@export_multiline var description: String = ""

## === MÉTODOS ===

## Calcula la recompensa base según nivel promedio del equipo
func calculate_base_reward(average_level: int) -> int:
	# Fórmula típica de Pokémon: nivel promedio * multiplicador de clase * constante
	var base = average_level * 20  # 20 por nivel es la base estándar
	return int(base * reward_multiplier)

## Retorna el nombre para mostrar
func get_display_name() -> String:
	return display_name

## Debug
func _to_string() -> String:
	return "%s (ID: %d)" % [display_name, id]
