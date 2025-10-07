class_name BattleChoice
extends RefCounted

var pokemon: BattlePokemon = null
var canceled: bool = false

func get_priority() -> int:
	return 0 # Por defecto, prioridad base

func resolve():
	push_error("resolve() method not implemented at BattleChoice class!")

func is_pass() -> bool:
	return false
