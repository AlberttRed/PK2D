extends Control

class_name FieldUI

@onready var animation_layer: Node2D = $BattleAnimationLayer
@onready var player_party_bar: BattlePartyBarUI = $PlayerBase/Party
@onready var enemy_party_bar: BattlePartyBarUI = $EnemyBase/Party


func _ready() -> void:
	if player_party_bar != null:
		player_party_bar.configure(true)
	if enemy_party_bar != null:
		enemy_party_bar.configure(false)
	hide_all_party_bars()


func get_animation_layer() -> Node2D:
	return animation_layer


func get_player_party_bar() -> BattlePartyBarUI:
	return player_party_bar


func get_enemy_party_bar() -> BattlePartyBarUI:
	return enemy_party_bar


func hide_all_party_bars() -> void:
	if player_party_bar != null:
		player_party_bar.park_offscreen()
	if enemy_party_bar != null:
		enemy_party_bar.park_offscreen()


func refresh_party_bars(player_side: BattleSide, enemy_side: BattleSide, rules: BattleRules) -> void:
	if player_party_bar != null and player_side != null:
		player_party_bar.refresh_from_party(player_side.pokemonParty)
	if (
		enemy_party_bar != null
		and enemy_side != null
		and rules != null
		and rules.type == BattleRules.BattleTypes.TRAINER
	):
		enemy_party_bar.refresh_from_party(enemy_side.pokemonParty)


func show_party_bars(
	host: Node,
	player_side: BattleSide,
	enemy_side: BattleSide,
	rules: BattleRules
) -> void:
	if host == null or not is_instance_valid(host):
		return
	refresh_party_bars(player_side, enemy_side, rules)
	var show_player := player_party_bar != null and player_side != null
	var show_enemy := (
		enemy_party_bar != null
		and enemy_side != null
		and rules != null
		and rules.type == BattleRules.BattleTypes.TRAINER
	)
	await _slide_party_bars(host, show_player, show_enemy, true)


func show_enemy_party_bar(host: Node, enemy_side: BattleSide, rules: BattleRules) -> void:
	if host == null or not is_instance_valid(host):
		return
	if (
		enemy_party_bar == null
		or enemy_side == null
		or rules == null
		or rules.type != BattleRules.BattleTypes.TRAINER
	):
		return
	enemy_party_bar.refresh_from_party(enemy_side.pokemonParty)
	await enemy_party_bar.slide_in(host)


func fade_out_enemy_party_bar(host: Node, duration: float = BattlePartyBarUI.FADE_OUT_DURATION) -> void:
	if host == null or not is_instance_valid(host) or enemy_party_bar == null:
		return
	await enemy_party_bar.fade_out(host, duration)


func hide_party_bars(host: Node, rules: BattleRules) -> void:
	if host == null or not is_instance_valid(host):
		return
	var show_enemy := rules != null and rules.type == BattleRules.BattleTypes.TRAINER
	await _slide_party_bars(host, player_party_bar != null, show_enemy, false)


## Retira la barra del lado del spot en paralelo (no bloqueante).
func hide_party_bar_for_spot(host: Node, landing_spot: BattleSpot, rules: BattleRules) -> void:
	if host == null or not is_instance_valid(host) or landing_spot == null:
		return
	var is_enemy := (
		landing_spot.side != null
		and landing_spot.side.type == BattleSide.Types.ENEMY
	)
	if is_enemy:
		if rules == null or rules.type != BattleRules.BattleTypes.TRAINER:
			return
		if enemy_party_bar == null:
			return
		(func() -> void:
			await enemy_party_bar.intro_roll_out(host)
		).call()
	else:
		if player_party_bar == null:
			return
		(func() -> void:
			await player_party_bar.intro_roll_out(host)
		).call()


func _slide_party_bars(host: Node, slide_player: bool, slide_enemy: bool, slide_in: bool) -> void:
	if not slide_player and not slide_enemy:
		return
	var flags := {
		"player": not slide_player,
		"enemy": not slide_enemy,
	}
	if slide_player:
		(
			func() -> void:
				if slide_in:
					await player_party_bar.intro_roll_in(host)
				else:
					await player_party_bar.intro_roll_out(host)
				flags.player = true
		).call()
	if slide_enemy:
		(
			func() -> void:
				if slide_in:
					await enemy_party_bar.intro_roll_in(host)
				else:
					await enemy_party_bar.intro_roll_out(host)
				flags.enemy = true
		).call()
	while host != null and is_instance_valid(host) and host.get_tree() != null:
		if flags.player and flags.enemy:
			return
		await host.get_tree().process_frame


func get_player_trainer(index: int = 0) -> Node2D:
	match index:
		0:
			return $PlayerBase/TrainerA
		1:
			return $PlayerBase/TrainerB
		_:
			return null


func get_enemy_trainer(index: int = 0) -> Node2D:
	match index:
		0:
			return $EnemyBase/TrainerA
		1:
			return $EnemyBase/TrainerB
		_:
			return null


func get_player_base() -> Node2D:
	return $PlayerBase


func get_enemy_base() -> Node2D:
	return $EnemyBase


## Coloca trainers en las posiciones de descanso (CONST.BATTLE) según el modo.
## Preferir capture_trainer_rest_positions() si la escena es la fuente de verdad.
func apply_trainer_rest_positions(mode: int = BattleRules.BattleModes.SINGLE) -> void:
	var player_a := get_player_trainer(0)
	var enemy_a := get_enemy_trainer(0)
	match mode:
		BattleRules.BattleModes.DOUBLE:
			if player_a:
				_set_trainer_rest(player_a, CONST.BATTLE.BACK_DOUBLE1_TRAINER_POS)
			var player_b := get_player_trainer(1)
			if player_b:
				_set_trainer_rest(player_b, CONST.BATTLE.BACK_DOUBLE2_TRAINER_POS)
			if enemy_a:
				_set_trainer_rest(enemy_a, CONST.BATTLE.FRONT_DOUBLE1_TRAINER_POS)
			var enemy_b := get_enemy_trainer(1)
			if enemy_b:
				_set_trainer_rest(enemy_b, CONST.BATTLE.FRONT_DOUBLE2_TRAINER_POS)
		_:
			if player_a:
				_set_trainer_rest(player_a, CONST.BATTLE.BACK_SINGLE_TRAINER_POS)
			if enemy_a:
				_set_trainer_rest(enemy_a, CONST.BATTLE.FRONT_SINGLE_TRAINER_POS)


## Usa la posición actual del nodo en la escena como descanso (no pisa con CONST).
func capture_trainer_rest_positions() -> void:
	for t in [
		get_player_trainer(0),
		get_player_trainer(1),
		get_enemy_trainer(0),
		get_enemy_trainer(1),
	]:
		if t == null or not is_instance_valid(t):
			continue
		if not t.has_meta("trainer_rest_pos"):
			t.set_meta("trainer_rest_pos", t.position)


## Muestra trainers ya colocados en la base (antes del slide de la base).
func reveal_intro_trainers(rules: BattleRules) -> void:
	var player_t := get_player_trainer(0)
	if player_t != null:
		BattleAnimationUtils.set_trainer_idle_frame(player_t)
		player_t.visible = true
	var show_enemy := rules != null and rules.type == BattleRules.BattleTypes.TRAINER
	var enemy_t := get_enemy_trainer(0)
	if enemy_t != null:
		BattleAnimationUtils.set_trainer_idle_frame(enemy_t)
		enemy_t.visible = show_enemy


func hide_all_hp_bars(mode: int = BattleRules.BattleModes.SINGLE) -> void:
	for spot: BattleSpot in get_all_spots_for_mode(mode):
		if spot == null or spot.hp_bar == null:
			continue
		spot.hp_bar.visible = false


func _set_trainer_rest(trainer_root: Node2D, rest: Vector2) -> void:
	if trainer_root == null:
		return
	trainer_root.position = rest
	trainer_root.set_meta("trainer_rest_pos", rest)


func get_player_spots_for_mode(mode: int) -> Array[BattleSpot]:
	match mode:
		BattleRules.BattleModes.SINGLE:
			return [$PlayerBase/PokemonSpotA]
		BattleRules.BattleModes.DOUBLE:
			return [$PlayerBase/PokemonSpotA, $PlayerBase/PokemonSpotB]
	return []

func get_enemy_spots_for_mode(mode: int) -> Array[BattleSpot]:
	match mode:
		BattleRules.BattleModes.SINGLE:
			return [$EnemyBase/PokemonSpotA]
		BattleRules.BattleModes.DOUBLE:
			return [$EnemyBase/PokemonSpotA, $EnemyBase/PokemonSpotB]
	return []

func get_all_spots_for_mode(mode: int) -> Array[BattleSpot]:
	return get_player_spots_for_mode(mode) + get_enemy_spots_for_mode(mode)


func get_player_spot(index: int) -> BattleSpot:
	match index:
		0: return $PlayerBase/PokemonSpotA
		1: return $PlayerBase/PokemonSpotB
		_: return null
		
func get_enemy_spot(index: int) -> BattleSpot:
	match index:
		0: return $EnemyBase/PokemonSpotA
		1: return $EnemyBase/PokemonSpotB
		_: return null

func position_battlespots_for_mode(
	mode: int,
	player_active_count: int = -1,
	enemy_active_count: int = -1
) -> void:
	match mode:
		BattleRules.BattleModes.SINGLE:
			$PlayerBase/PokemonSpotA.global_position = $PlayerBase/Positions/SpotA_Single.global_position
			$PlayerBase/PokemonSpotB.visible = false

			$EnemyBase/PokemonSpotA.global_position = $EnemyBase/Positions/SpotA_Single.global_position
			$EnemyBase/PokemonSpotB.visible = false

		BattleRules.BattleModes.DOUBLE:
			$PlayerBase/PokemonSpotA.global_position = $PlayerBase/Positions/SpotA_Double.global_position
			$PlayerBase/PokemonSpotB.global_position = $PlayerBase/Positions/SpotB_Double.global_position
			$PlayerBase/PokemonSpotB.visible = player_active_count != 1

			$EnemyBase/PokemonSpotA.global_position = $EnemyBase/Positions/SpotA_Double.global_position
			$EnemyBase/PokemonSpotB.global_position = $EnemyBase/Positions/SpotB_Double.global_position
			$EnemyBase/PokemonSpotB.visible = enemy_active_count != 1

		_:
			push_warning("Combate no compatible: usando modo SINGLE por defecto")
			$PlayerBase/PokemonSpotA.global_position = $PlayerBase/Positions/SpotA_Single.global_position
			$PlayerBase/PokemonSpotA.global_position = $EnemyBase/Positions/SpotA_Single.global_position

# Ordena el z_indez de cada BattleSpot para que se vean en el orden correcto en pantalla
func apply_z_order_for_mode(mode: int) -> void:
	match mode:
		BattleRules.BattleModes.SINGLE:
			# En combate individual, solo SpotA está activo y debe estar por encima
			$PlayerBase/PokemonSpotA.z_index = 1
			$PlayerBase/PokemonSpotB.z_index = 0
			$EnemyBase/PokemonSpotA.z_index = 1
			$EnemyBase/PokemonSpotB.z_index = 0

		BattleRules.BattleModes.DOUBLE:
			# En combate doble, en player el SpotA debe estar por detrás, y en enemy por delante (más "cerca" de cámara)
			$PlayerBase/PokemonSpotA.z_index = 1
			$PlayerBase/PokemonSpotB.z_index = 2
			$EnemyBase/PokemonSpotA.z_index = 2
			$EnemyBase/PokemonSpotB.z_index = 1

		_:
			push_warning("Modo de combate no soportado para orden de Z")
