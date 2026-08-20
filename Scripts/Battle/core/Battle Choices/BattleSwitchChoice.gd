class_name BattleSwitchChoice
extends BattleChoice

var target_index: int # El índice del Pokémon al que cambiar
var side: BattleSide = null
var outgoing_pokemon: BattlePokemon = null
var incoming_pokemon: BattlePokemon = null
var origin_spot_index: int = -1
var target_spot: BattleSpot = null
var forced_by_faint: bool = false

func get_priority() -> int:
	return 6 # En los juegos oficiales, cambiar tiene prioridad 6

func resolve() -> Array[BattleHandler]:
	# Crear el handler de switch
	var side_ref := side if side != null else pokemon.side
	if side_ref == null:
		print("[SWITCH] Side inválido")
		return []
	var spot := _resolve_target_spot(side_ref)
	if spot == null:
		print("[SWITCH] Spot de origen inválido")
		return []
	var current := outgoing_pokemon if outgoing_pokemon != null else spot.get_active_pokemon()
	if not forced_by_faint and current != null:
		var trap_ctx := BattlePhaseContext.for_choice(current, self)
		BattleEffectController.run_apply_phase(
			current, BattleEffect.Phases.ON_VALIDATE_SWITCH, trap_ctx
		)
		if trap_ctx.validation != null and trap_ctx.validation.rejected:
			print("[SWITCH] Pokémon atrapado, no puede cambiar")
			return []
	var target_idx := target_index
	var party := side_ref.pokemonParty

	if target_idx < 0 or target_idx >= party.size():
		print("[SWITCH] Índice destino inválido")
		return []

	var incoming: BattlePokemon = incoming_pokemon if incoming_pokemon != null else party[target_idx]
	if incoming == null:
		print("[SWITCH] Pokémon de entrada inválido")
		return []
	if incoming == current:
		print("[SWITCH] Mismo Pokémon, no se realiza el cambio")
		return []

	if incoming.in_battle:
		print("[SWITCH] El Pokémon ya está en combate")
		return []

	var handler = BattleSwitchHandler.new(side_ref, spot, current, incoming, side_ref.battle_rules)
	return [handler]


func _resolve_target_spot(side_ref: BattleSide) -> BattleSpot:
	if target_spot != null:
		return target_spot
	if pokemon != null and pokemon.battle_spot != null:
		return pokemon.battle_spot
	if origin_spot_index >= 0 and side_ref != null and origin_spot_index < side_ref.battle_spots.size():
		return side_ref.battle_spots[origin_spot_index]
	return null
