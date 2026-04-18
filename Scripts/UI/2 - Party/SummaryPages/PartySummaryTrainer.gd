extends Panel

func open():
	show()
	
func loadPokemonInfo(pokemon: Pokemon) -> void:
	var nidx := int(pokemon.nature_id)
	var nname := "—"
	if nidx >= 0 and nidx < CONST.NaturesName.size():
		nname = str(CONST.NaturesName[nidx])
	$Naturaleza.setText(nname + ".")

	$Labels/FechaCaptura.setText(pokemon.capture_date)

	$Labels/RutaCaptura.setText(pokemon.capture_route)

	$Labels/NivelCaptura.setText("Encontrado con Nv. " + str(pokemon.capture_level) + ".")

	$DescNaturaleza.setText(pokemon.personality)

func clear():
	$Naturaleza.setText("")

	$Labels/FechaCaptura.setText("")

	$Labels/RutaCaptura.setText("")

	$Labels/NivelCaptura.setText("")

	$DescNaturaleza.setText("")
