extends BattleHandler

class_name MultiHitHandler

var category: BattleMoveCategory
var move: BattleMove
var user: BattlePokemon
var target: BattlePokemon
var num_hits: int

var per_hit_handlers: Array[BattleHandler] = []
var show_effectiveness := false

func _init(_category: BattleMoveCategory, _move: BattleMove, _user: BattlePokemon, _target: BattlePokemon, _num_hits: int):
	category = _category
	move = _move
	user = _user
	target = _target
	num_hits = _num_hits

func apply() -> void:
	per_hit_handlers.clear()
	for i in num_hits:
		if target.is_fainted():
			break
		var base_handler := category._create_handler(move, user, target)
		if base_handler != null:
			base_handler.apply()
			show_effectiveness = show_effectiveness or base_handler.show_effectiveness
			per_hit_handlers.append(base_handler)

func visualize(ui: BattleUI) -> void:
	for h in per_hit_handlers:
		await h.visualize(ui)
	if num_hits > 1:
		await ui.show_multi_hit_message(per_hit_handlers.size())

	if show_effectiveness and !per_hit_handlers.is_empty():
		await ui.show_effectiveness_message(per_hit_handlers[0].damage)


