## Clase TrainerData
##
## Resource que define los datos completos de un entrenador.
## Se guarda como .tres en Resources/Trainers/ para reutilización.
##
## Uso:
##   var trainer_data = preload("res://Resources/Trainers/brock.tres")
##   battler.trainer_data = trainer_data
extends Resource
class_name TrainerData

## === IDENTIFICACIÓN ===

## ID único del entrenador (para tracking de derrotas, rematches, etc.)
@export var trainer_id: int = 0

## Clase del entrenador (usa el enum, se cargará el TrainerClassData automáticamente)
@export var trainer_class_id: TrainerClassEnum.Values = TrainerClassEnum.Values.POKEMON_TRAINER

## Nombre para mostrar en combate y diálogos
@export var display_name: String = "Entrenador"

## Identificador único del trainer para tracking de combates (opcional, se usa como fallback si resource_path está vacío)
## Si no se especifica, se intentará obtener desde resource_path
@export var resource_id: String = ""

# Propiedades calculadas (se cargan automáticamente)
var trainer_class: TrainerClassData  # Se carga desde trainer_class_id

## === SPRITES Y VISUAL ===

## Sprite del entrenador para combate (vista frontal - enemigo)
@export var battle_front_sprite: Texture2D = null

## Sprite del entrenador para combate (vista trasera - jugador/aliado)
@export var battle_back_sprite: Texture2D = null

@export_group("Battle Visuals")
## Fondo de combate para este entrenador (INHERIT = clase → mapa).
@export var battle_back: BattleBackEnum.Values = BattleBackEnum.Values.INHERIT
## Variante de base bajo los Pokémon (INHERIT = clase → resolver por backdrop).
@export var base_variant: BattleBaseVariantEnum.Values = BattleBaseVariantEnum.Values.INHERIT

## === INTELIGENCIA ARTIFICIAL ===

## Perfil de IA para el combate (null = default_ai de la clase, o BattleIA_TrainerEasy)
@export var ai_profile: TrainerBattleIA = null

## === TEXTOS DE COMBATE ===

## Texto de introducción antes del combate
@export_multiline var intro_text: String = "¡Vamos a combatir!"

## Texto al perder el combate
@export_multiline var defeat_text: String = "He perdido..."

## Texto al ganar el combate (usado para rival/eventos especiales)
@export_multiline var victory_text: String = "¡Gané!"

## === EQUIPO POKÉMON ===

## Equipo del entrenador como Array de PokemonDefinition (plantillas)
## Configura PokemonDefinition desde el inspector con nivel, IVs, movimientos, etc.
## Los Pokémon runtime se crean al iniciar el combate mediante create_party()
## NOTA: Usamos Array genérico para permitir migración automática desde Pokemon antiguos
@export var party_data: Array = []
var _party_data_migrated: bool = false


## === CONFIGURACIÓN DE COMBATE ===

## Si true, el entrenador puede hacer combates dobles
@export var double_battle: bool = false

## Cantidad de dinero que da al ganar
@export var reward_money: int = 1000

## === OTROS ===

## Items de combate del entrenador (item_id; repetidos se apilan).
## Se copia a `BattleParticipant.bag` al crear el participante (no jugadores humanos).
@export var battle_items: Array[int] = []

## Si true, el entrenador ya fue derrotado (para tracking)
var is_defeated: bool = false

## Si true, este entrenador puede hacer rematches
@export var can_rematch: bool = false

## Nivel de rematch (si aumentan los niveles en rematch)
@export var rematch_level_bonus: int = 0

## === MÉTODOS ÚTILES ===

## Inicializa el TrainerData (carga el TrainerClassData desde el enum)
## Llamar esto después de crear/cargar el TrainerData
func initialize() -> void:
	# Migrar party_data si es necesario (convertir Pokemon antiguos a PokemonDefinition)
	_migrate_party_data()

	# Cargar TrainerClassData desde el enum (DatabaseService o directorio)
	# Por ahora, creamos uno temporal hasta que existan los .tres
	_load_trainer_class()

## Migra party_data de Array[Pokemon] a Array[PokemonDefinition] si es necesario
func _migrate_party_data() -> void:
	if _party_data_migrated:
		return

	var migrated_party: Array[PokemonDefinition] = []
	var needs_migration = false

	for item in party_data:
		if item == null:
			continue
		elif item is PokemonDefinition:
			# Ya es PokemonDefinition, añadir directamente
			migrated_party.append(item)
		elif item is Pokemon:
			# Es un Pokemon antiguo, convertir a PokemonDefinition
			needs_migration = true
			var pokemon_runtime = item as Pokemon
			var definition = _convert_pokemon_to_definition(pokemon_runtime)
			if definition:
				migrated_party.append(definition)
				push_warning("TrainerData._migrate_party_data(): Migrado Pokemon a PokemonDefinition para trainer '%s'" % display_name)
		else:
			push_warning("TrainerData._migrate_party_data(): Elemento de tipo desconocido (%s) en party_data, saltando" % (item.get_class() if item else "null"))

	if needs_migration:
		party_data = migrated_party
		_party_data_migrated = true
		# Solo persistir en disco cuando sea posible: en exportación `res://` es solo lectura y las rutas
		# embebidas (p. ej. escena.tscn::SubResource) no son guardables con ResourceSaver.
		if not resource_path.is_empty():
			var can_save_to_path := true
			if resource_path.begins_with("res://"):
				can_save_to_path = Engine.is_editor_hint()
			if can_save_to_path:
				var error := ResourceSaver.save(self, resource_path)
				if error == OK:
					print("TrainerData._migrate_party_data(): Guardado trainer migrado: %s" % resource_path)
				else:
					push_warning("TrainerData._migrate_party_data(): Error al guardar trainer migrado: %s (error: %d)" % [resource_path, error])

## Carga el TrainerClassData desde el enum ID
func _load_trainer_class() -> void:
	# Intentar cargar desde DatabaseService
	trainer_class = DatabaseService.get_trainer_class(trainer_class_id)

## Convierte un Pokemon runtime a PokemonDefinition (para migración automática)
func _convert_pokemon_to_definition(pokemon: Pokemon) -> PokemonDefinition:
	if pokemon == null:
		return null

	var definition = PokemonDefinition.new()

	# Copiar campos básicos
	definition.pokemon_id = pokemon.pokemon_id
	definition.level = pokemon.level
	definition.nickname = pokemon.nickname
	definition.gender = pokemon.gender
	definition.shiny = pokemon.shiny
	definition.is_wild = pokemon.is_wild

	# Copiar IVs (no aleatorizar, usar valores existentes)
	definition.randomize_ivs = false
	definition.hp_IVs = pokemon.hp_IVs
	definition.attack_IVs = pokemon.attack_IVs
	definition.defense_IVs = pokemon.defense_IVs
	definition.spAttack_IVs = pokemon.spAttack_IVs
	definition.spDefense_IVs = pokemon.spDefense_IVs
	definition.speed_IVs = pokemon.speed_IVs

	# Copiar EVs (no aleatorizar, usar valores existentes)
	definition.randomize_evs = false
	definition.hp_EVs = pokemon.hp_EVs
	definition.attack_EVs = pokemon.attack_EVs
	definition.defense_EVs = pokemon.defense_EVs
	definition.spAttack_EVs = pokemon.spAttack_EVs
	definition.spDefense_EVs = pokemon.spDefense_EVs
	definition.speed_EVs = pokemon.speed_EVs

	# Copiar naturaleza y habilidad
	definition.nature_id = pokemon.nature_id
	definition.ability_id = pokemon.ability_id

	# Copiar movimientos personalizados
	definition.custom_move_ids = pokemon.custom_move_ids.duplicate()

	# Copiar objeto equipado
	definition.held_item_id = pokemon.held_item_id

	return definition

## Obtiene party_data como Array[PokemonDefinition] tipado
func get_party_data() -> Array[PokemonDefinition]:
	var result: Array[PokemonDefinition] = []
	for item in party_data:
		if item is PokemonDefinition:
			result.append(item)
	return result

## Crea el equipo runtime a partir de las definiciones (PokemonDefinition)
## Retorna un Array[Pokemon] listo para usar en combate
func create_party() -> Array[Pokemon]:
	var party: Array[Pokemon] = []

	# Asegurar que party_data esté migrado
	_migrate_party_data()
	var definitions = get_party_data()

	# Crear Pokemon runtime desde cada PokemonDefinition
	for i in range(definitions.size()):
		var definition = definitions[i]
		if definition == null:
			push_warning("TrainerData.create_party(): party_data[%d] es null para trainer '%s', saltando" % [i, display_name])
			continue

		if not (definition is PokemonDefinition):
			push_error("TrainerData.create_party(): party_data[%d] no es PokemonDefinition (tipo: %s) para trainer '%s', saltando" % [i, definition.get_class() if definition else "null", display_name])
			continue

		var pokemon = definition.create_pokemon()
		if pokemon == null:
			push_error("TrainerData.create_party(): No se pudo crear Pokemon desde party_data[%d] para trainer '%s'" % [i, display_name])
			continue

		# Asignar datos del entrenador
		pokemon.trainer_id = trainer_id
		pokemon.original_trainer = display_name
		party.append(pokemon)

	return party

## Retorna el nombre completo (clase + nombre)
func get_full_name() -> String:
	if trainer_class:
		return "%s %s" % [trainer_class.display_name, display_name]
	else:
		return display_name

## Retorna el sprite frontal (prioridad: trainer → clase → null)
func get_battle_front_sprite() -> Texture2D:
	if battle_front_sprite != null:
		return battle_front_sprite
	if trainer_class and trainer_class.default_battle_front_sprite != null:
		return trainer_class.default_battle_front_sprite
	return null

## Retorna el sprite trasero (prioridad: trainer → clase → null)
func get_battle_back_sprite() -> Texture2D:
	if battle_back_sprite != null:
		return battle_back_sprite
	if trainer_class and trainer_class.default_battle_back_sprite != null:
		return trainer_class.default_battle_back_sprite
	return null


## Override de fondo de combate (trainer → clase → INHERIT).
func get_battle_back_override() -> BattleBackEnum.Values:
	if battle_back != BattleBackEnum.Values.INHERIT:
		return battle_back
	if trainer_class and trainer_class.default_battle_back != BattleBackEnum.Values.INHERIT:
		return trainer_class.default_battle_back
	return BattleBackEnum.Values.INHERIT


## Override de variante de base (trainer → clase → INHERIT).
func get_base_variant_override() -> BattleBaseVariantEnum.Values:
	if base_variant != BattleBaseVariantEnum.Values.INHERIT:
		return base_variant
	if trainer_class and trainer_class.default_base_variant != BattleBaseVariantEnum.Values.INHERIT:
		return trainer_class.default_base_variant
	return BattleBaseVariantEnum.Values.INHERIT

## Retorna el texto de intro formateado
func get_intro_message() -> String:
	return intro_text.replace("{player}", "Jugador")  # Placeholder para nombre del jugador

## Retorna el texto de derrota formateado
func get_defeat_message() -> String:
	return defeat_text

## Retorna el texto de victoria formateado
func get_victory_message() -> String:
	return victory_text

## Calcula la recompensa de dinero según el equipo y la clase
func calculate_reward() -> int:
	# Si hay reward_money específico, usarlo
	if reward_money > 0:
		return reward_money

	# Si no, calcular según clase y nivel promedio del equipo
	_migrate_party_data()
	var definitions = get_party_data()
	if trainer_class and not definitions.is_empty():
		var total_level = 0
		for definition in definitions:
			if definition:
				total_level += definition.level
		var avg_level = int(float(total_level) / float(definitions.size()))
		return trainer_class.calculate_base_reward(avg_level)

	return 1000  # Recompensa por defecto

## Verifica si el entrenador tiene un equipo válido
func has_valid_party() -> bool:
	_migrate_party_data()
	var definitions = get_party_data()

	if definitions.is_empty():
		push_warning("TrainerData.has_valid_party(): party_data está vacío para trainer '%s'" % display_name)
		return false

	# Verificar que al menos un PokemonDefinition sea válido
	for i in range(definitions.size()):
		var definition = definitions[i]
		if definition == null:
			push_warning("TrainerData.has_valid_party(): party_data[%d] es null para trainer '%s'" % [i, display_name])
			continue

		# Verificar que sea un PokemonDefinition válido
		if not (definition is PokemonDefinition):
			push_warning("TrainerData.has_valid_party(): party_data[%d] no es PokemonDefinition (tipo: %s) para trainer '%s'" % [i, definition.get_class(), display_name])
			continue

		# Verificar que tenga un pokemon_id válido
		if definition.pokemon_id == null:
			push_warning("TrainerData.has_valid_party(): party_data[%d].pokemon_id es null para trainer '%s'" % [i, display_name])
			continue

		if definition.pokemon_id == PokemonsEnum.Values.NONE:
			push_warning("TrainerData.has_valid_party(): party_data[%d].pokemon_id es NONE para trainer '%s'" % [i, display_name])
			continue

		# Si llegamos aquí, encontramos un PokemonDefinition válido
		return true

	push_warning("TrainerData.has_valid_party(): No se encontró ningún PokemonDefinition válido para trainer '%s' (party_data.size() = %d)" % [display_name, definitions.size()])
	return false

## Obtiene el identificador único del trainer desde el resource_path
## Retorna el nombre del archivo .res sin extensión (ej: "brock" de "res://Resources/Trainers/brock.tres")
## Si no hay resource_path, usa el campo resource_id como fallback
## Si ambos están vacíos, lanza un error
func get_resource_id() -> String:
	# Prioridad 1: Si hay resource_id configurado manualmente, usarlo
	if not resource_id.is_empty():
		return resource_id

	# Prioridad 2: Intentar obtener desde resource_path
	if not resource_path.is_empty():
		# Extraer el nombre del archivo sin extensión
		var file_name = resource_path.get_file()
		if file_name.ends_with(".tres"):
			return file_name.substr(0, file_name.length() - 5)  # Quitar ".tres"
		return file_name

	# Si ambos están vacíos, lanzar error
	push_error("TrainerData: No se pudo obtener resource_id - resource_path y resource_id están vacíos. Configura resource_id manualmente o guarda el TrainerData como archivo .tres")
	return ""

## Debug: imprime información del entrenador
func print_trainer_info() -> void:
	print("=== Entrenador: %s ===" % get_full_name())
	print("ID: %d" % trainer_id)
	print("Resource ID: %s" % get_resource_id())
	var definitions = get_party_data()
	print("Equipo: %d Pokémon" % definitions.size())
	print("Dinero: $%d" % reward_money)
	print("Combate doble: %s" % ("Sí" if double_battle else "No"))
	print("========================")
