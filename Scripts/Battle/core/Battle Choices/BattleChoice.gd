class_name BattleChoice
extends RefCounted

var battle_spot: BattleSpot = null
## Pokémon que declaró la acción (fijado al elegir; no revalidar desde el spot tras un KO).
var pokemon: BattlePokemon = null:
	set(pkmn):
		pokemon = pkmn
		battle_spot = pkmn.battle_spot if pkmn != null else null
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
