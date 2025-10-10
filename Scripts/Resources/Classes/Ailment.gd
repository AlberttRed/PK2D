class_name Ailment
extends Resource

# Esquema unificado: id numérico e internal_name en minúsculas
@export var id: int = 0                 # ID numérico (PokeAPI)
@export var internal_name: String = "" # nombre interno en minúsculas ("paralysis")

@export var display_name: String     # Nombre visible ("Parálisis")
@export var description: String = "" # Texto opcional descriptivo
@export var icon: Texture2D = null   # Icono opcional para mostrar en batalla
@export var is_persistent: bool = true  # Si persiste fuera de combate o al hacer switch
@export var effect: Resource = null        # Script del PersistentBattleEffect asociado

func get_effect(_min_turn = null, _max_turn = null):
	return effect.new(self,_min_turn,_max_turn) if effect != null else null

# Helper para obtener el enum de mensajes de forma segura durante la transición
func get_enum_value() -> int:
	if id != 0:
		return AilmentsEnum.from_id(id)
	elif internal_name != "":
		return AilmentsEnum.from_string(internal_name)
	else:
		return AilmentsEnum.Values.NONE
