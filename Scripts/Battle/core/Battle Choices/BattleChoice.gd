class_name BattleChoice
extends RefCounted

var battle_spot: BattleSpot = null
var pokemon: BattlePokemon:
	get:
		return battle_spot.get_active_pokemon() if battle_spot != null else null
	set(value):
		battle_spot = value.battle_spot if value != null else null
var canceled: bool = false

func get_priority() -> int:
	return 0 # Por defecto, prioridad base

func is_blocking_action() -> bool:
	# Por defecto, las acciones no bloquean al resto del equipo
	# Override en acciones como Huir o Lanzar Pokéball
	return false

func resolve():
	push_error("resolve() method not implemented at BattleChoice class!")

func is_pass() -> bool:
	return false
