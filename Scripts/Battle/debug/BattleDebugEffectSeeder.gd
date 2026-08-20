class_name BattleDebugEffectSeeder
extends RefCounted

## Activa lluvia (campo), Reflejo (lado jugador) y veneno (primer Pokémon activo del jugador)
## Pensado para probar el orden de fin de turno en TestBattle.
static var _pending: bool = false

static func enable() -> void:
	_pending = true

static func try_apply(controller: BattleController) -> void:
	if not _pending:
		return
	_pending = false
	_apply(controller)

static func _apply(controller: BattleController) -> void:
	if controller == null or controller.player_side == null:
		return
	var player_team: Array = controller.player_side.get_active_pokemons()
	if player_team.is_empty():
		push_warning("BattleDebugEffectSeeder: no hay Pokémon activo del jugador.")
		return
	var player_pkmn: BattlePokemon = player_team[0] as BattlePokemon

	_seed_rain()
	_seed_reflect(player_pkmn)
	_seed_poison(player_pkmn)

	print(
		"BattleDebugEffectSeeder: lluvia + Reflejo (Player) + veneno en %s. Fin de turno → visual: Reflejo → Lluvia → Veneno."
		% player_pkmn.get_name()
	)

static func _seed_rain() -> void:
	var weather: WeatherData = DatabaseService.get_weather("rain")
	if weather == null:
		push_warning("BattleDebugEffectSeeder: DatabaseService.get_weather('rain') devolvió null.")
		return
	var rain := weather.get_effect(5, true)
	if rain == null:
		return
	if BattleEffectController.has_field_effect(rain):
		return
	BattleEffectController.add_field_effect(rain)

static func _seed_reflect(player_pkmn: BattlePokemon) -> void:
	var move_data: MoveData = DatabaseService.get_move(115)
	if move_data == null:
		push_warning("BattleDebugEffectSeeder: no se encontró el movimiento Reflejo (115).")
		return
	var battle_move := BattleMove.new(Move.new(move_data), player_pkmn)
	var reflect := ReflectFieldEffect.new(battle_move, 5, BattleSide.Types.PLAYER)
	if BattleEffectController.has_side_effect(BattleSide.Types.PLAYER, reflect):
		return
	BattleEffectController.add_side_effect(BattleSide.Types.PLAYER, reflect)

static func _seed_poison(player_pkmn: BattlePokemon) -> void:
	var poison_data: AilmentData = AilmentData.from_major_status(CONST.STATUS.POISON)
	if poison_data == null:
		push_warning("BattleDebugEffectSeeder: no se encontró ailment de veneno.")
		return
	player_pkmn.set_status(poison_data)
	var poison: PersistentBattleEffect = poison_data.get_effect()
	if poison == null:
		return
	if not BattleEffectController.has_effect_for(player_pkmn, poison):
		BattleEffectController.add_pokemon_effect(player_pkmn, poison)
	player_pkmn.status_changed.emit()
