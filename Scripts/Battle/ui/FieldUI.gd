extends Control

class_name FieldUI

@onready var animation_layer: Node2D = $BattleAnimationLayer
@onready var player_party_bar: BattlePartyBarUI = $PlayerBase/Party
@onready var enemy_party_bar: BattlePartyBarUI = $EnemyBase/Party

## Spot A doble: la party queda un poco baja respecto al marker HP.
const ENEMY_PARTY_SPOT_A_Y_ADJUST := -10.0
## z absoluto de HPBar: mismo nivel que el panel de mensajes (6); el MessageBox gana por orden en árbol.
const HP_BAR_CANVAS_Z := 6
## Balls de recall/throw en campo: debajo del HPBar, encima del layer de animación (z=1).
const FIELD_POKEBALL_Z := HP_BAR_CANVAS_Z - 1


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


## HPBar siempre por encima de BattleAnimationLayer (balls, VFX).
func ensure_all_hp_bars_display_z(mode: int) -> void:
	for spot: BattleSpot in get_all_spots_for_mode(mode):
		if spot != null:
			spot.ensure_hp_bar_display_z()


func hide_all_party_bars() -> void:
	if player_party_bar != null:
		player_party_bar.park_offscreen()
	if enemy_party_bar != null:
		enemy_party_bar.park_offscreen()


func refresh_party_bars(player_side: BattleSide, enemy_side: BattleSide, rules: BattleRules) -> void:
	if player_party_bar != null and player_side != null:
		var local_player: BattleParticipant = player_side.get_local_player_participant()
		if local_player != null:
			player_party_bar.refresh_from_party(player_side.get_participant_battle_party(local_player))
		else:
			player_party_bar.refresh_from_party(player_side.pokemonParty)
	if (
		enemy_party_bar != null
		and enemy_side != null
		and rules != null
		and rules.type == BattleRules.BattleTypes.TRAINER
	):
		var local_enemy: BattleParticipant = enemy_side.get_local_player_participant()
		if local_enemy != null:
			enemy_party_bar.refresh_from_party(enemy_side.get_participant_battle_party(local_enemy))
		else:
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
	var show_player := (
		player_party_bar != null
		and player_side != null
		and rules != null
		and rules.type == BattleRules.BattleTypes.TRAINER
	)
	var show_enemy := (
		enemy_party_bar != null
		and enemy_side != null
		and rules != null
		and rules.type == BattleRules.BattleTypes.TRAINER
	)
	await _slide_party_bars(host, show_player, show_enemy, true)


func show_enemy_party_bar(
	host: Node,
	enemy_side: BattleSide,
	rules: BattleRules,
	landing_spot: BattleSpot = null,
	incoming: BattlePokemon = null
) -> void:
	if host == null or not is_instance_valid(host):
		return
	if (
		enemy_party_bar == null
		or enemy_side == null
		or rules == null
		or rules.type != BattleRules.BattleTypes.TRAINER
	):
		return
	if landing_spot != null:
		position_enemy_party_for_spot(landing_spot, rules.mode)
	else:
		enemy_party_bar.reset_rest_position()
	var party: Array = enemy_side.pokemonParty
	if incoming != null and incoming.participant != null:
		party = enemy_side.get_participant_battle_party(incoming.participant)
	enemy_party_bar.refresh_from_party(party)
	await enemy_party_bar.slide_in(host)


## En dobles, la party rival entra donde estaba el HPBar del spot que cambia.
func position_enemy_party_for_spot(landing_spot: BattleSpot, mode: int) -> void:
	if enemy_party_bar == null or landing_spot == null:
		return
	var enemy_base := get_enemy_base()
	if enemy_base == null:
		return
	var marker := (
		landing_spot.hp_bar_pos_double
		if mode == BattleRules.BattleModes.DOUBLE
		else landing_spot.hp_bar_pos_single
	)
	if marker == null:
		return
	var default_rest := enemy_party_bar.get_default_rest_position()
	var party_y := enemy_base.to_local(marker.global_position).y + _enemy_party_y_nudge(mode)
	if mode == BattleRules.BattleModes.DOUBLE and landing_spot == get_enemy_spot(0):
		party_y += ENEMY_PARTY_SPOT_A_Y_ADJUST
	enemy_party_bar.set_rest_position(Vector2(default_rest.x, party_y))


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
		if rules != null and rules.type == BattleRules.BattleTypes.WILD:
			return
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
## En doble con un solo entrenador por lado, usa posición single (centro).
## Preferir capture_trainer_rest_positions() si la escena es la fuente de verdad.
func apply_trainer_rest_positions(
	mode: int = BattleRules.BattleModes.SINGLE,
	player_trainer_count: int = 1,
	enemy_trainer_count: int = 1
) -> void:
	var player_a := get_player_trainer(0)
	var enemy_a := get_enemy_trainer(0)
	var use_player_double := (
		mode == BattleRules.BattleModes.DOUBLE and player_trainer_count >= 2
	)
	var use_enemy_double := (
		mode == BattleRules.BattleModes.DOUBLE and enemy_trainer_count >= 2
	)
	if use_player_double:
		if player_a:
			_set_trainer_rest(player_a, CONST.BATTLE.BACK_DOUBLE1_TRAINER_POS)
		var player_b := get_player_trainer(1)
		if player_b:
			_set_trainer_rest(player_b, CONST.BATTLE.BACK_DOUBLE2_TRAINER_POS)
	elif player_a:
		_set_trainer_rest(player_a, CONST.BATTLE.BACK_SINGLE_TRAINER_POS)
	if use_enemy_double:
		if enemy_a:
			_set_trainer_rest(enemy_a, CONST.BATTLE.FRONT_DOUBLE1_TRAINER_POS)
		var enemy_b := get_enemy_trainer(1)
		if enemy_b:
			_set_trainer_rest(enemy_b, CONST.BATTLE.FRONT_DOUBLE2_TRAINER_POS)
	elif enemy_a:
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
func reveal_intro_trainers(
	rules: BattleRules,
	player_trainer_count: int = 1,
	enemy_trainer_count: int = 1
) -> void:
	var mode := BattleRules.BattleModes.SINGLE
	if rules != null:
		mode = rules.mode
	var show_enemy := rules != null and rules.type == BattleRules.BattleTypes.TRAINER
	for i in 2:
		var player_t := get_player_trainer(i)
		if player_t == null:
			continue
		var show_player_trainer := i == 0 or (
			mode == BattleRules.BattleModes.DOUBLE and player_trainer_count >= 2
		)
		if show_player_trainer:
			BattleAnimationUtils.set_trainer_idle_frame(player_t)
		_set_trainer_shown(player_t, show_player_trainer)
	for i in 2:
		var enemy_t := get_enemy_trainer(i)
		if enemy_t == null:
			continue
		var show_this_enemy := show_enemy and (
			i == 0 or (mode == BattleRules.BattleModes.DOUBLE and enemy_trainer_count >= 2)
		)
		if show_this_enemy:
			BattleAnimationUtils.set_trainer_idle_frame(enemy_t)
		_set_trainer_shown(enemy_t, show_this_enemy)


func _set_trainer_shown(trainer_root: Node2D, should_show: bool) -> void:
	if trainer_root == null:
		return
	trainer_root.visible = should_show
	var spr := trainer_root.get_node_or_null("Sprite") as Sprite2D
	if spr != null:
		spr.visible = should_show


func hide_all_enemy_trainers() -> void:
	for i in 2:
		_set_trainer_shown(get_enemy_trainer(i), false)


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


## Desplazamiento vertical party vs marker HP (intro spot B ≈ 43 px; mitad evita recorte arriba en spot A).
func _enemy_party_y_nudge(mode: int) -> float:
	if not has_meta("enemy_party_y_nudge"):
		var ref_idx := 1 if mode == BattleRules.BattleModes.DOUBLE else 0
		var ref_spot := get_enemy_spot(ref_idx)
		var nudge := 22.0
		if ref_spot != null and enemy_party_bar != null:
			var marker := (
				ref_spot.hp_bar_pos_double
				if mode == BattleRules.BattleModes.DOUBLE
				else ref_spot.hp_bar_pos_single
			)
			if marker != null:
				var ref_y := get_enemy_base().to_local(marker.global_position).y
				nudge = (enemy_party_bar.get_default_rest_position().y - ref_y) * 0.5
		set_meta("enemy_party_y_nudge", nudge)
	return get_meta("enemy_party_y_nudge")


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
