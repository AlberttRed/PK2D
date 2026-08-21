extends Node
class_name Battler
## Representa un entrenador (Trainer) o al jugador en combate.
## Gestiona el equipo de Pokémon y convierte los datos a BattleParticipant.
##
## Configuración:
## - Asignar TrainerData en el inspector (contiene equipo, textos, IA, sprites)
## - Marcar is_player=true para el jugador
## - Todas las propiedades se cargan automáticamente desde TrainerData

## === CONFIGURACIÓN DEL ENTRENADOR ===

@export_group("Trainer Data")
## TrainerData Resource con toda la información del entrenador (equipo, textos, IA, sprites, etc.)
@export var trainer_data: TrainerData = null

@export_group("Player Config")
## Marcar como true si este Battler pertenece al jugador
@export var is_player: bool = false

@export_group("State")
## Si el entrenador ya fue derrotado
@export var is_defeated: bool = false

@export_group("Partner (for Double Battles)")
## Ruta al Battler del partner para combates dobles
@export var partner_path: NodePath = ""

## === PROPIEDADES INTERNAS (cargadas desde TrainerData) ===

## Estos campos se cargan automáticamente desde trainer_data en _ready()
var trainer_id: int = -1
var trainer_name: String = ""
var battler_type: CONST.BATTLER_TYPES = CONST.BATTLER_TYPES.TRAINER
var battle_ia: BattleIA = null
var allow_double_battle: bool = false
var battle_front_sprite: Texture
var battle_back_sprite: Texture = null
var before_battle_message: String = ""
var init_battle_message: String = ""
var end_battle_message: String = ""
var party: Array[Pokemon] = []


func _ready() -> void:
	_load_from_trainer_data()
	_initialize_party()


## Carga la configuración desde TrainerData si existe
func _load_from_trainer_data() -> void:
	if trainer_data == null:
		push_warning("Battler: No se ha asignado TrainerData. El Battler no tendrá datos configurados.")
		return

	# Inicializar TrainerData (carga TrainerClassData desde el enum)
	trainer_data.initialize()

	# Cargar propiedades básicas
	trainer_id = trainer_data.trainer_id
	trainer_name = trainer_data.display_name
	battle_ia = trainer_data.ai_profile
	# Fallback de clase cuando el trainer no define perfil propio
	if battle_ia == null and trainer_data.trainer_class != null:
		battle_ia = trainer_data.trainer_class.default_ai
	allow_double_battle = trainer_data.double_battle

	# Cargar sprites (front y back) con fallback a los de la clase
	battle_front_sprite = trainer_data.get_battle_front_sprite()
	battle_back_sprite = trainer_data.get_battle_back_sprite()

	# Cargar textos
	before_battle_message = trainer_data.intro_text
	init_battle_message = trainer_data.intro_text  # Usar intro para ambos
	end_battle_message = trainer_data.defeat_text

	# Cargar equipo según el tipo de battler
	if is_player:
		# Player: si tiene TrainerData con PokemonDefinition, crear Pokemon persistentes
		# Solo cargar si el party está vacío (para no duplicar Pokemon ya configurados)
		if trainer_data and party.is_empty():
			var definitions = trainer_data.get_party_data()
			if not definitions.is_empty():
				print("Battler._load_from_trainer_data(): Player tiene %d PokemonDefinition(s), creando Pokemon persistentes" % definitions.size())
				for definition in definitions:
					if definition:
						var pokemon = definition.create_pokemon()
						if pokemon:
							party.append(pokemon)
							print("Battler._load_from_trainer_data(): Creado Pokemon %s (Lv.%d) para player" % [pokemon.get_display_name(), pokemon.level])
			else:
				push_warning("Battler._load_from_trainer_data(): Player TrainerData no tiene PokemonDefinition en party_data")
		elif party.is_empty() and not trainer_data:
			push_warning("Battler._load_from_trainer_data(): Player no tiene TrainerData ni Pokemon en party. El party debe configurarse manualmente.")
	# Para trainers: party se creará en to_battle_participant() desde PokemonDefinition (temporal)


## Inicializa el equipo cargado desde TrainerData
## Si el equipo está vacío, muestra una advertencia
## NOTA: Para trainers, el party se crea runtime en to_battle_participant()
func _initialize_party() -> void:
	# Solo inicializar si es player (party persistente)
	# Para trainers, el party se crea temporalmente en to_battle_participant()
	if is_player:
		var trainer_display_name = trainer_data.display_name if trainer_data else trainer_name

		if party.is_empty():
			push_warning("Battler '%s': No tiene Pokémon en el equipo." % trainer_display_name)
			return

		# Inicializar cada Pokemon del array (solo para player)
		for pokemon in party:
			if pokemon:
				# Solo llamar _post_init si el Pokemon no está inicializado
				if pokemon.base == null:
					pokemon._post_init()


## Agrega un Pokémon al equipo (runtime)
func add_pokemon_to_party(pokemon) -> void:  # pokemon: Pokemon
	if pokemon == null:
		push_warning("Battler: Intentando agregar un Pokémon nulo")
		return

	party.append(pokemon)

## Agrega un Pokémon desde PokemonData (crea el runtime automáticamente)
func add_pokemon_from_data(pokemon_data: PokemonData, level: int = 5, gender: int = -1) -> void:
	if pokemon_data == null:
		push_warning("Battler: PokemonData nulo")
		return

	# Crear Pokemon con stats aleatorios
	var pokemon = Pokemon.new(
		pokemon_data,     # pokemon_data
		level,            # pokemon_level
		gender,           # pokemon_gender (0 = aleatorio)
		0,                # pokemon_ability (0 = aleatorio según especie)
		0,                # pokemon_nature (0 = aleatorio)
		true              # randomize_stats (IVs aleatorios)
	)

	if battler_type == CONST.BATTLER_TYPES.TRAINER:
		pokemon.trainer_id = trainer_id
		pokemon.original_trainer = trainer_name if not trainer_name.is_empty() else "Desconocido"

	party.append(pokemon)


## Elimina un Pokémon del equipo
func remove_pokemon_from_party(pokemon) -> void:  # pokemon: Pokemon
	var index = party.find(pokemon)
	if index != -1:
		party.remove_at(index)


## Verifica si tiene un Pokémon específico
func has_pokemon(pokemon) -> bool:  # pokemon: Pokemon
	return party.has(pokemon)


## Party de combate / UI: `GameStateService` si hay miembros; si no, `party` del nodo (p. ej. definición en escena).
func get_combat_party() -> Array[Pokemon]:
	if not is_player:
		return party
	if not Engine.is_editor_hint() and GameStateService and GameStateService.get_party().count() > 0:
		return GameStateService.get_party().get_all()
	return party


## Obtiene el número de Pokémon en el equipo
func get_party_size() -> int:
	if is_player:
		return get_combat_party().size()
	else:
		# Para trainers, obtener desde PokemonDefinition
		if trainer_data:
			return trainer_data.get_party_data().size()
		return party.size()  # Fallback legacy


## Obtiene el número de Pokémon no debilitados
## NOTA: Para trainers, esto solo funciona durante el combate (cuando party está poblado temporalmente)
func get_alive_pokemon_count() -> int:
	var count := 0
	for pokemon in get_combat_party():
		if pokemon and pokemon.hp_actual > 0:
			count += 1
	return count


## Verifica si el entrenador puede pelear
func can_battle() -> bool:
	if is_player:
		# Player: verificar party persistente
		return get_alive_pokemon_count() > 0
	else:
		# Trainer: verificar que tenga PokemonDefinition válidos
		if trainer_data:
			return trainer_data.has_valid_party()
		# Fallback legacy
		return get_alive_pokemon_count() > 0


## Obtiene el nombre completo del entrenador (clase + nombre si trainer_data existe)
func get_full_name() -> String:
	if trainer_data:
		return trainer_data.get_full_name()
	return trainer_name


## Obtiene la recompensa en dinero por ganar
func get_reward_money() -> int:
	if trainer_data:
		return trainer_data.calculate_reward()
	return 0  # Sin trainer_data, no hay recompensa definida


## Obtiene el texto de introducción
func get_intro_text() -> String:
	if trainer_data:
		return trainer_data.get_intro_message()
	return before_battle_message if not before_battle_message.is_empty() else "¡Vamos a combatir!"


## Obtiene el texto de derrota
func get_defeat_text() -> String:
	if trainer_data:
		return trainer_data.get_defeat_message()
	return end_battle_message if not end_battle_message.is_empty() else "He perdido..."


## === CONVERSIÓN A BATTLEPARTICIPANT ===

## Convierte este Battler a un BattleParticipant para usar en combate
func to_battle_participant() -> BattleParticipant:
	var participant := BattleParticipant.new()

	# Configurar datos del participante
	participant.trainer_id = trainer_id
	# Obtener identificador del resource si hay TrainerData
	if trainer_data:
		participant.trainer_resource_id = trainer_data.get_resource_id()
		print("Battler.to_battle_participant: trainer_resource_id='%s' (desde resource_path='%s')" % [participant.trainer_resource_id, trainer_data.resource_path])
	# Usar get_full_name() para incluir la clase del trainer (ej: "Cazabichos Jano")
	var effective_name: String = get_full_name() if trainer_data else (trainer_name if not trainer_name.is_empty() else str(name))
	participant.name = effective_name
	participant.is_player = is_player
	# is_trainer antes de asignar IA: la validación runtime depende del tipo de participante
	participant.is_trainer = (battler_type != CONST.BATTLER_TYPES.WILD_POKEMON)
	participant.set_ai_controller(battle_ia, effective_name)
	var resolved_ia: BattleIA = participant.ai_controller

	# Pasar mensajes del trainer (para mostrar al final del combate)
	participant.intro_message = before_battle_message
	participant.defeat_message = end_battle_message
	participant.victory_message = ""  # Por si se añade en el futuro

	# Obtener el equipo según el tipo de battler
	var battle_pokemon_team: Array[BattlePokemon] = []

	if is_player:
		# Misma lista y orden que Party UI (`GameStateService`); si está vacío, fallback al `party` del Battler (escena).
		var player_team: Array[Pokemon] = get_combat_party()
		print("Battler.to_battle_participant(): Player tiene %d Pokemon en equipo de combate" % player_team.size())

		if player_team.is_empty():
			push_error("Battler.to_battle_participant(): Player sin Pokémon en equipo (GameStateService ni party del Battler).")
		else:
			for pokemon in player_team:
				if pokemon:
					var battle_pokemon = pokemon.to_battle_pokemon()
					battle_pokemon.controllable = true
					battle_pokemon.participant = participant
					battle_pokemon_team.append(battle_pokemon)
					print("Battler.to_battle_participant(): Añadido BattlePokemon %s (Lv.%d) del player" % [pokemon.get_display_name(), pokemon.level])
	else:
		# Trainer: crear Pokemon runtime desde PokemonDefinition
		if trainer_data:
			var definitions = trainer_data.get_party_data()
			print("Battler.to_battle_participant(): Trainer '%s' tiene %d PokemonDefinition(s)" % [trainer_name, definitions.size()])

			if definitions.is_empty():
				push_error("Battler.to_battle_participant(): Trainer '%s' no tiene PokemonDefinition en party_data" % trainer_name)
			else:
				for i in range(definitions.size()):
					var definition = definitions[i]
					if definition == null:
						push_warning("Battler.to_battle_participant(): PokemonDefinition[%d] null en trainer '%s', saltando" % [i, trainer_name])
						continue

					# Crear Pokemon runtime desde la definición
					var pokemon = definition.create_pokemon()
					if pokemon == null:
						push_error("Battler.to_battle_participant(): No se pudo crear Pokemon desde PokemonDefinition[%d] (pokemon_id: %d) para trainer '%s'" % [i, definition.pokemon_id, trainer_name])
						continue

					# Convertir a BattlePokemon
					var battle_pokemon = pokemon.to_battle_pokemon(resolved_ia)
					if battle_pokemon == null:
						push_error("Battler.to_battle_participant(): No se pudo convertir Pokemon a BattlePokemon para trainer '%s'" % trainer_name)
						continue

					battle_pokemon.controllable = false
					battle_pokemon.is_wild = false
					battle_pokemon.participant = participant
					battle_pokemon_team.append(battle_pokemon)
					print("Battler.to_battle_participant(): Añadido BattlePokemon %s (Lv.%d) al participante" % [pokemon.get_display_name(), pokemon.level])
		else:
			# Fallback: usar party existente (compatibilidad legacy)
			for pokemon in party:
				if pokemon:
					var battle_pokemon = pokemon.to_battle_pokemon(resolved_ia)
					battle_pokemon.controllable = false
					battle_pokemon.participant = participant
					battle_pokemon_team.append(battle_pokemon)

	# Añadir todos los BattlePokemon al participante
	print("Battler.to_battle_participant(): Añadiendo %d BattlePokemon(s) al participante '%s'" % [battle_pokemon_team.size(), participant.name])
	for battle_pokemon in battle_pokemon_team:
		participant.add_pokemon(battle_pokemon)

	print("Battler.to_battle_participant(): Participante '%s' tiene %d Pokemon en pokemon_team" % [participant.name, participant.pokemon_team.size()])

	return participant


## === MÉTODOS DE UTILIDAD ===

## Obtiene el partner para batallas dobles
func get_partner() -> Battler:
	if partner_path.is_empty():
		return null

	var partner_node = get_node_or_null(partner_path)
	if partner_node and partner_node is Battler:
		return partner_node

	return null


## Imprime información del equipo (debug)
func print_party_info() -> void:
	print("=== Battler: %s ===" % trainer_name)
	print("  Tipo: %s" % CONST.BATTLER_TYPES.keys()[battler_type])
	print("  Es jugador: %s" % is_player)

	if is_player:
		# Player: mostrar party persistente
		print("  Equipo (%d):" % party.size())
		for i in party.size():
			var pokemon = party[i]
			if pokemon:
				print("    %d. %s (Lv.%d) - HP: %d/%d" % [
					i + 1,
					pokemon.get_display_name(),
					pokemon.level,
					pokemon.hp_actual,
					pokemon.get_final_stat(StatsEnum.Values.HP)
				])
	else:
		# Trainer: mostrar PokemonDefinition
		if trainer_data:
			var definitions = trainer_data.get_party_data()
			print("  Equipo (PokemonDefinition) (%d):" % definitions.size())
			for i in definitions.size():
				var definition = definitions[i]
				if definition:
					print("    %d. PokemonDefinition: %s (Lv.%d) - pokemon_id: %d" % [
						i + 1,
						PokemonsEnum.get_display_name(definition.pokemon_id),
						definition.level,
						definition.pokemon_id
					])
		else:
			# Fallback legacy
			print("  Equipo (%d):" % party.size())
			for i in party.size():
				var pokemon = party[i]
				if pokemon:
					print("    %d. %s (Lv.%d) - HP: %d/%d" % [
						i + 1,
						pokemon.get_display_name(),
						pokemon.level,
						pokemon.hp_actual,
						pokemon.get_final_stat(StatsEnum.Values.HP)
					])


## === MÉTODOS LEGACY (compatibilidad) ===

## Crea un Battler programáticamente (para código legacy)
func create(
	_type: CONST.BATTLER_TYPES,
	_party: Array,
	_IA: BattleIA,
	_name: String = "",
	_battle_front_sprite: Texture = null,
	_battle_back_sprite: Texture = null,
	_before_battle_message: String = "",
	_init_battle_message: String = "",
	_end_battle_message: String = "",
	_is_defeated: bool = false,
	_double_battle: bool = false,
	_is_playable: bool = false,
	_partner: NodePath = NodePath("")
) -> Battler:

	battler_type = _type
	battle_ia = _IA
	trainer_name = _name
	battle_front_sprite = _battle_front_sprite
	battle_back_sprite = _battle_back_sprite
	before_battle_message = _before_battle_message
	init_battle_message = _init_battle_message
	end_battle_message = _end_battle_message
	is_defeated = _is_defeated
	allow_double_battle = _double_battle
	is_player = _is_playable
	partner_path = _partner

	# Agregar Pokémon al equipo
	party.clear()
	for p in _party:
		if p is Pokemon:
			add_pokemon_to_party(p)

	return self
