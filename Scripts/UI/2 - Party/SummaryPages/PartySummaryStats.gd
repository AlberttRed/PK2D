extends Panel


func open() -> void:
	show()


func loadPokemonInfo(pokemon: Pokemon) -> void:
	if pokemon == null or pokemon.base == null:
		return
	var max_hp := pokemon.get_final_stat(StatsEnum.Values.HP)
	var ps_line := str(pokemon.hp_actual) + "/" + str(max_hp)
	if not pokemon.fainted and pokemon.major_status != CONST.STATUS.OK:
		ps_line += "  (" + AilmentData.major_status_display_name(pokemon.major_status) + ")"
	$dPS.text = ps_line

	$health_bar.set_values(pokemon.hp_actual, max_hp)

	$ValueStats/dAtaque.text = str(pokemon.get_final_stat(StatsEnum.Values.ATTACK))

	$ValueStats/dDefensa.text = str(pokemon.get_final_stat(StatsEnum.Values.DEFENSE))

	$ValueStats/dAtEsp.text = str(pokemon.get_final_stat(StatsEnum.Values.SP_ATTACK))

	$ValueStats/dDefEsp.text = str(pokemon.get_final_stat(StatsEnum.Values.SP_DEFENSE))

	$ValueStats/dVelocidad.text = str(pokemon.get_final_stat(StatsEnum.Values.SPEED))

	var ab_idx := int(pokemon.ability_id)
	var ab_text := "—"
	if ab_idx >= 0 and ab_idx < CONST.AbilitiesName.size():
		ab_text = str(CONST.AbilitiesName[ab_idx])

	$dHabilidad.text = ab_text

	var ab_desc := "—"
	if ab_idx >= 0 and ab_idx < CONST.AbilitiesDesc.size():
		ab_desc = str(CONST.AbilitiesDesc[ab_idx])

	$DescHabilidad.text = ab_desc


func clear() -> void:
	$dPS.text = ""

	$health_bar.clear()

	$ValueStats/dAtaque.text = ""

	$ValueStats/dDefensa.text = ""

	$ValueStats/dAtEsp.text = ""

	$ValueStats/dDefEsp.text = ""

	$ValueStats/dVelocidad.text = ""

	$dHabilidad.text = ""

	$DescHabilidad.text = ""
