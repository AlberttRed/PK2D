extends Panel


func open() -> void:
	show()


func loadPokemonInfo(pokemon: Pokemon) -> void:
	if pokemon == null or pokemon.base == null:
		return
	var max_hp := pokemon.get_final_stat(StatsEnum.Values.HP)
	$dPS.setText(str(pokemon.hp_actual) + "/" + str(max_hp))

	$health_bar.init(pokemon)

	$ValueStats/dAtaque.setText(str(pokemon.get_final_stat(StatsEnum.Values.ATTACK)))

	$ValueStats/dDefensa.setText(str(pokemon.get_final_stat(StatsEnum.Values.DEFENSE)))

	$ValueStats/dAtEsp.setText(str(pokemon.get_final_stat(StatsEnum.Values.SP_ATTACK)))

	$ValueStats/dDefEsp.setText(str(pokemon.get_final_stat(StatsEnum.Values.SP_DEFENSE)))

	$ValueStats/dVelocidad.setText(str(pokemon.get_final_stat(StatsEnum.Values.SPEED)))

	var ab_idx := int(pokemon.ability_id)
	var ab_text := "—"
	if ab_idx >= 0 and ab_idx < CONST.AbilitiesName.size():
		ab_text = str(CONST.AbilitiesName[ab_idx])

	$dHabilidad.setText(ab_text)

	var ab_desc := "—"
	if ab_idx >= 0 and ab_idx < CONST.AbilitiesDesc.size():
		ab_desc = str(CONST.AbilitiesDesc[ab_idx])

	$DescHabilidad.setText(ab_desc)


func clear() -> void:
	$dPS.setText("")

	$health_bar.clear()

	$ValueStats/dAtaque.setText("")

	$ValueStats/dDefensa.setText("")

	$ValueStats/dAtEsp.setText("")

	$ValueStats/dDefEsp.setText("")

	$ValueStats/dVelocidad.setText("")

	$dHabilidad.setText("")

	$DescHabilidad.setText("")
