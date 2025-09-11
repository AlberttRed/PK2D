class_name Ailment
extends Resource

@export var id: String                # ID interno o el de PokeAPI, como "paralysis"
@export var display_name: String     # Nombre visible ("Parálisis")
@export var description: String = "" # Texto opcional descriptivo
@export var icon: Texture2D = null   # Icono opcional para mostrar en batalla
@export var is_persistent: bool = true  # Si persiste fuera de combate o al hacer switch
@export var effect: Resource = null        # Script del PersistentBattleEffect asociado

func get_effect(_min_turn = null, _max_turn = null):
	return effect.new(self,_min_turn,_max_turn) if effect != null else null
