extends EventCommand
class_name ShowPortraitCommand

## Comando para mostrar una imagen o sprite de Pokémon en una caja de diálogo estilo Pokémon
## Replica el comportamiento visual clásico de selección de iniciales en FireRed/Emerald

enum ImageSource {
	POKEMON,
	TEXTURE
}

enum Position {
	LEFT,
	RIGHT,
	CENTER
}

enum CloseMode {
	WAIT_INPUT,    # Espera input del usuario para cerrar
	AUTO_TIME,     # Se cierra automáticamente después de un tiempo
	NO_CLOSE       # No se cierra automáticamente, requiere ClosePortraitCommand
}

enum ScaleMode {
	PIXEL_PERFECT,
	FIT_BOX
}

## Fuente de la imagen
@export var image_source: ImageSource = ImageSource.POKEMON

## Si image_source es POKEMON: especie del Pokémon
@export var pokemon_species: PokemonsEnum.Values = PokemonsEnum.Values.BULBASAUR

## Si image_source es TEXTURE: textura a mostrar
@export var texture: Texture2D = null

## Modo de escala (solo para TEXTURE)
@export var scale_mode: ScaleMode = ScaleMode.PIXEL_PERFECT

## Estilo de marco del MessageBox
@export var frame_style: MessageBoxFrameStyle.Values = MessageBoxFrameStyle.Values.HGSS

## Posición de la caja
@export var position: Position = Position.CENTER

## Offset de z_index (opcional)
@export var z_index_offset: int = 0

## Modo de cierre
@export var close_mode: CloseMode = CloseMode.WAIT_INPUT

## Tiempo de cierre automático (solo si close_mode es AUTO_TIME)
@export var auto_close_time: float = 2.0

func execute(context: Node) -> void:
	print("ShowPortraitCommand: Mostrando imagen")

	# Preparar datos según la fuente
	var image_data = null
	if image_source == ImageSource.POKEMON:
		# Obtener PokemonData desde DatabaseService
		var pokemon_data = DatabaseService.get_pokemon(pokemon_species)
		if pokemon_data == null:
			push_error("ShowPortraitCommand: No se pudo cargar PokemonData para especie %d" % pokemon_species)
			context.continue_execution()
			return

		# Obtener el sprite frontal del Pokémon (para mostrar al jugador)
		var sprite = pokemon_data.battle_front_sprite
		if sprite == null:
			push_error("ShowPortraitCommand: El Pokémon %d no tiene battle_front_sprite" % pokemon_species)
			context.continue_execution()
			return

		image_data = sprite
	else:  # TEXTURE
		if texture == null:
			push_error("ShowPortraitCommand: No se especificó textura")
			context.continue_execution()
			return
		image_data = texture

	# Mostrar el portrait box usando DisplayManager
	await DisplayManager.show_portrait_box(
		image_source,
		image_data,
		frame_style,
		position,
		close_mode,
		auto_close_time,
		scale_mode,
		z_index_offset
	)

	context.continue_execution()

func is_async() -> bool:
	return true

func is_safe_for_parallel() -> bool:
	return false

