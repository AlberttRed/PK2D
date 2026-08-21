class_name DamageEffect
extends ImmediateBattleEffect

var move: BattleMove
var amount: int

var is_critical := false
var is_stab := false
var effectiveness := 1.0

func _init(_user: BattlePokemon, _target: BattlePokemon, _move: BattleMove, _amount:int):
	user = _user
	target = _target
	move = _move
	amount = _amount

func apply() -> void:
	# PS y barra se aplican en visualize() tras la fase PRE del sustituto.
	pass

func visualize(_ui: BattleUI) -> void:
	if is_ineffective():
		return
	var defender: BattlePokemon = target.get_active_battle_pokemon() if target != null else null
	if defender == null:
		return
	var spot: BattleSpot = defender.resolve_battle_spot()
	if spot == null:
		return
	var pokemon: BattlePokemon = spot.get_active_pokemon()
	if pokemon == null:
		return

	# Tras el cálculo: amount = 0 si el sustituto interceptó (todo al muñeco).
	var hp_loss := amount

	var ctx := BattlePhaseContext.for_incoming_damage(pokemon, self)
	await BattleEffectController.process_phase(
		pokemon, BattleEffect.Phases.ON_INCOMING_DAMAGE_PRE, ctx
	)

	if hp_loss > 0:
		await spot.play_hit_animation()
		pokemon.hp = maxi(pokemon.hp - hp_loss, 0)
		pokemon.fainted = pokemon.hp <= 0
		await spot.apply_damage(hp_loss)

	await BattleEffectController.process_phase(
		pokemon, BattleEffect.Phases.ON_INCOMING_DAMAGE_POST, ctx
	)

func is_super_effective() -> bool:
	return effectiveness > 1.0

func is_not_very_effective() -> bool:
	return effectiveness > 0.0 and effectiveness < 1.0

func is_ineffective() -> bool:
	return effectiveness == 0.0

func validate() -> void:
	amount = max(amount, 1) if !is_ineffective() else amount # El daño siempre debe ser como mínimo 1
