class_name BattleEffect
extends RefCounted

## Quién aplica el efecto y sobre quién (rellenados por el handler al crear la instancia).
var user: BattlePokemon = null
var target: BattlePokemon = null

enum Phases {
	ON_BATTLE_START,
	ON_INIT_BATTLE_TURN,
	ON_INIT_POKEMON_TURN,
	ON_BEFORE_MOVE,
	ON_AFTER_MOVE,
	ON_SWITCH_IN,
	ON_SWITCH_OUT,
	ON_ENTRY_BEGIN,
	ON_END_POKEMON_TURN,
	ON_END_BATTLE_TURN,
}


enum Modifiers {
	MOVE_POWER,
	MOVE_ACCURACY,
	CRITICAL_CHANCE
}

## Comprueba si el efecto puede aplicarse. Sobrescribir en subclases con reglas propias.
func can_apply() -> int:
	return ApplyFailReason.Values.OK

# Helper para mostrar mensajes desde efectos sin repetir diccionarios
# Por defecto: tipo "wait" y wait_time 1.0
func show_effect_message(ui: BattleUI, text: String, wait_time: float = 1.0, message_type: String = "wait") -> void:
	await ui.show_message_from_dict({
		"type": message_type,
		"text": text,
		"wait_time": wait_time
	})
