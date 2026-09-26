extends Panel

func open():
	show()
	
func loadPokemonInfo(pokemon: Pokemon) -> void:
	var nidx := int(pokemon.nature_id)
	var nname := "—"
	if nidx >= 0 and nidx < CONST.NaturesName.size():
		nname = str(CONST.NaturesName[nidx])
	$Naturaleza.text = nname + "."

	$Labels/FechaCaptura.text = pokemon.capture_date

	$Labels/RutaCaptura.text = pokemon.capture_route

	$Labels/NivelCaptura.text = "Encontrado con Nv. " + str(pokemon.capture_level) + "."

	$DescNaturaleza.text = pokemon.personality

func clear():
	$Naturaleza.text = ""

	$Labels/FechaCaptura.text = ""

	$Labels/RutaCaptura.text = ""

	$Labels/NivelCaptura.text = ""

	$DescNaturaleza.text = ""
