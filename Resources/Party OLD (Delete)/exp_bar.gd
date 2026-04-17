extends Node2D

signal updated
signal levelUP
signal levelUPEnded

var actual_level_exp :int = 0
var next_level_exp :int = 0
var actual_exp :int = 0

func init(pokemon: Pokemon) -> void:
	clear()
	updateUI(pokemon)
	#update_color()
#	percentage = float(pokemon_target.hp_actual) / float(pokemon_target.hp_total)
#	$health.scale = Vector2(percentage, 1)

func updateUI(pokemon: Pokemon) -> void:
	actual_exp = pokemon.totalExp
	actual_level_exp = pokemon.actualLevelExpBase
	next_level_exp = pokemon.nextLevelExpBase
	print("Min: " + str(actual_level_exp))
	print("Actual: " + str(actual_exp))
	print("Max: " + str(next_level_exp))
	$TextureProgressBar.max_value = next_level_exp
	$TextureProgressBar.min_value = actual_level_exp
	$TextureProgressBar.value = actual_exp
	
func update_color():
	var percentage = float($TextureProgressBar.value) / float($TextureProgressBar.max_value)
	if percentage > 0.5:
		$TextureProgressBar.tint_progress = CONST.BATTLE.HPCOLORGREEN
	elif percentage >= 0.20 and percentage <=0.50:
		$TextureProgressBar.tint_progress = CONST.BATTLE.HPCOLORYELLOW
	else:
		$TextureProgressBar.tint_progress = CONST.BATTLE.HPCOLORRED

func on_exp_changes(exp):
	animate_value(actual_exp, exp)
	actual_exp = exp

func updateEXP(exp):
	while $TextureProgressBar.value != exp:
		var end:int = getValueEnd(exp)
		await animate_value(actual_exp, end)
		if isNewLevel():
			levelUP.emit()
			await levelUPEnded
	actual_exp = exp
	updated.emit()
	
func animate_value(start, end):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property($TextureProgressBar, "value", end, 1.0)
	await tween.finished

func getValueEnd(end:int):
	if end > next_level_exp:
		return next_level_exp
	else:
		return end
	
func isNewLevel():
	return $TextureProgressBar.value == next_level_exp


func clear():
	actual_level_exp = 0
	next_level_exp = 0
	actual_exp = 0
	$TextureProgressBar.min_value = 0
	$TextureProgressBar.value = 0
	$TextureProgressBar.max_value = 0

func _on_value_changed(value):
	if value == next_level_exp:
		print("LEVEL UP!")
