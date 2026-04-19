extends Panel


func open() -> void:
	show()


func loadPokemonInfo(pokemon: Pokemon) -> void:
	if pokemon == null or pokemon.base == null:
		return
	$dNumDex.setText(str(int(pokemon.pokemon_id)).pad_zeros(3))

	$dEspecie.setText(pokemon.base.Name)
	$Tipos/pTipo1/dTipo1.vframes = 1
	var t1 := pokemon.get_type1()
	if t1 != null and t1.image != null:
		$Tipos/pTipo1/dTipo1.texture = t1.image

	var t2 := pokemon.get_type2()
	if t2 != null and t2.image != null:
		$Tipos/pTipo2.visible = true
		$Tipos/pTipo2/dTipo2.vframes = 1
		$Tipos/pTipo2/dTipo2.texture = t2.image
	else:
		$Tipos/pTipo2.visible = false

	$dEO.setText(pokemon.original_trainer)

	$dID.setText(str(pokemon.trainer_id))

	$dExperiencia.setText(str(pokemon.totalExp))

	$dSigNivel.setText(str(pokemon.nextLevelExpBase - pokemon.totalExp))

	var exp_seg: Vector2i = pokemon.get_exp_bar_segment_values()
	$exp_bar.set_values(exp_seg.x, exp_seg.y)


func clear() -> void:
	$dNumDex.setText("")

	$dEspecie.setText("")
	$Tipos/pTipo1/dTipo1.vframes = 2
	$Tipos/pTipo1/dTipo1.texture = null

	$Tipos/pTipo2.visible = false
	$Tipos/pTipo2/dTipo2.vframes = 2
	$Tipos/pTipo2/dTipo2.texture = null

	$dEO.setText("")

	$dID.setText("")

	$dExperiencia.setText("")

	$dSigNivel.setText("")

	$exp_bar.clear()
