extends Control
class_name PortraitBox

## PortraitBox - Caja de diálogo para mostrar imágenes (Pokémon, retratos, etc.)
## Estilo similar a la selección de iniciales en FireRed/Emerald

signal closed

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

@onready var panel: Panel = $Panel
@onready var texture_rect: TextureRect = $Panel/TextureRect
var wait_indicator: Sprite2D = null
var animation_player: AnimationPlayer = null

var _close_mode: CloseMode = CloseMode.WAIT_INPUT
var _auto_close_timer: Timer = null
var _frame_style: MessageBoxFrameStyle.Values = MessageBoxFrameStyle.Values.HGSS
var _messagebox_theme: MessageBoxTheme = null

## Tamaño del panel (por defecto 200x200, se puede ajustar pasando custom_size a setup())
## Para ajustar el tamaño desde el script, modifica este valor antes de llamar a setup()
## Ejemplo: portrait_box.panel_size = Vector2(250, 150)  # Ancho 250, Alto 150
var panel_size: Vector2 = Vector2(200, 200)

## Margen entre la imagen y el borde del marco (en píxeles)
## Este valor se aplica uniformemente en todos los lados (izquierda, arriba, derecha, abajo)
## Si es 0, el marco se ajusta exactamente al tamaño de la imagen
## Actualmente está configurado en 0 (sin margen)
const IMAGE_MARGIN: float = 48.0

## Si es true, el marco se ajusta al tamaño de la imagen (imagen + margen)
## Si es false, el marco tiene un tamaño fijo y la imagen se ajusta dentro
var auto_size_to_image: bool = true

func _ready() -> void:
	# Configurar para que continúe procesando aunque el árbol esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	# Obtener referencias a los nodos opcionales (pueden no existir)
	wait_indicator = get_node_or_null("Panel/WaitIndicator")
	if wait_indicator:
		animation_player = wait_indicator.get_node_or_null("AnimationPlayer")
		# Configurar AnimationPlayer para que procese aunque el árbol esté pausado
		if animation_player:
			animation_player.process_mode = Node.PROCESS_MODE_ALWAYS

## Configura y muestra el portrait box
## @param image_texture: La textura a mostrar (AtlasTexture o Texture2D)
## @param frame_style: Estilo de marco del MessageBox
## @param box_position: Posición de la caja (LEFT, RIGHT, CENTER)
## @param close_mode: Modo de cierre (WAIT_INPUT, AUTO_TIME)
## @param auto_close_time: Tiempo de cierre automático (solo si close_mode es AUTO_TIME)
## @param scale_mode: Modo de escala (PIXEL_PERFECT, FIT_BOX)
## @param z_index_offset: Offset de z_index
## @param custom_size: Tamaño personalizado del panel (Vector2.ZERO = usar tamaño por defecto 200x200)
func setup(
	image_texture: Texture2D,
	frame_style: MessageBoxFrameStyle.Values,
	box_position: Position,
	close_mode: CloseMode,
	auto_close_time: float = 0.0,
	scale_mode: ScaleMode = ScaleMode.PIXEL_PERFECT,
	z_index_offset: int = 0,
	custom_size: Vector2 = Vector2.ZERO
) -> void:
	_frame_style = frame_style
	_close_mode = close_mode

	# Aplicar tema del MessageBox
	_messagebox_theme = MessageBoxFrameStyle.get_messagebox_theme(frame_style)
	if _messagebox_theme and _messagebox_theme.frame_stylebox:
		panel.add_theme_stylebox_override("panel", _messagebox_theme.frame_stylebox)

	# Configurar textura
	texture_rect.texture = image_texture

	# Calcular tamaño del panel basado en la imagen
	if auto_size_to_image and image_texture:
		# Obtener el tamaño real de la textura
		var image_size: Vector2
		if image_texture is AtlasTexture:
			# Para AtlasTexture, usar el tamaño de la región
			image_size = (image_texture as AtlasTexture).region.size
		else:
			# Para Texture2D normal, usar get_size()
			image_size = image_texture.get_size()

		# Añadir márgenes al tamaño de la imagen
		panel_size = image_size + Vector2(IMAGE_MARGIN * 2, IMAGE_MARGIN * 2)
		panel.custom_minimum_size = panel_size
		panel.size = panel_size
	elif custom_size != Vector2.ZERO:
		# Tamaño personalizado explícito
		panel_size = custom_size
		panel.custom_minimum_size = panel_size
		panel.size = panel_size
	else:
		# Usar tamaño por defecto de la escena
		panel_size = panel.custom_minimum_size if panel.custom_minimum_size != Vector2.ZERO else Vector2(200, 200)

	# Aplicar márgenes uniformes entre la imagen y el marco
	# El margen se aplica en todos los lados (izquierda, arriba, derecha, abajo)
	texture_rect.offset_left = IMAGE_MARGIN
	texture_rect.offset_top = IMAGE_MARGIN
	texture_rect.offset_right = -IMAGE_MARGIN
	texture_rect.offset_bottom = -IMAGE_MARGIN

	# Configurar escala
	# NOTA: El recuadro (Panel) es cuadrado, y el margen es uniforme en todos los lados.
	# Sin embargo, la imagen puede verse rectangular si:
	# - El sprite original no es cuadrado (aunque los sprites de batalla suelen ser 80x80)
	# - Se usa PIXEL_PERFECT: mantiene el aspecto original del sprite
	# - Se usa FIT_BOX: ajusta la imagen al área disponible manteniendo aspecto (puede dejar espacio)
	match scale_mode:
		ScaleMode.PIXEL_PERFECT:
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP  # Mantiene tamaño original del sprite
		ScaleMode.FIT_BOX:
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # Ajusta manteniendo aspecto

	# Configurar posición
	_setup_position(box_position)

	# Configurar z_index
	z_index = 10 + z_index_offset

	# Configurar wait indicator si existe (solo se muestra si está en modo WAIT_INPUT)
	_setup_wait_indicator()

	# Configurar modo de cierre
	_setup_close_mode(auto_close_time)

	# Mostrar
	visible = true
	# Notificar cambio de visibilidad para el sistema de pausa
	if has_signal("visibility_changed"):
		visibility_changed.emit()

func _setup_position(box_position: Position) -> void:
	var viewport_size = get_viewport_rect().size
	var box_size = panel.size if panel.size != Vector2.ZERO else panel_size

	# Altura aproximada del MessageBox (para evitar superposición)
	# El MessageBox tiene 96 píxeles de altura y está anclado abajo
	var messagebox_height = 96
	var bottom_margin = messagebox_height + 20  # Espacio adicional para evitar superposición

	# El recuadro crece hacia arriba, así que lo posicionamos desde abajo
	match box_position:
		Position.LEFT:
			# Posicionar desde la parte inferior izquierda, creciendo hacia arriba
			panel.position = Vector2(20, viewport_size.y - box_size.y - bottom_margin)
		Position.RIGHT:
			# Posicionar desde la parte inferior derecha, creciendo hacia arriba
			panel.position = Vector2(viewport_size.x - box_size.x - 20, viewport_size.y - box_size.y - bottom_margin)
		Position.CENTER:
			# Posicionar centrado horizontalmente, pero desde la parte inferior, creciendo hacia arriba
			panel.position = Vector2((viewport_size.x - box_size.x) / 2, viewport_size.y - box_size.y - bottom_margin)

func _setup_wait_indicator() -> void:
	if not wait_indicator:
		return

	# Ocultar wait indicator por defecto - solo se muestra cuando está esperando input
	wait_indicator.visible = false
	if animation_player:
		animation_player.stop()

	# Solo mostrar wait indicator si está en modo WAIT_INPUT y hay tema configurado
	if _close_mode != CloseMode.WAIT_INPUT:
		return

	if not _messagebox_theme:
		return

	# Aplicar textura del wait indicator solo en modo WAIT_INPUT
	if _messagebox_theme.wait_indicator_texture:
		wait_indicator.texture = _messagebox_theme.wait_indicator_texture
		wait_indicator.visible = true

		# Configurar animación si existe y está visible
		if animation_player:
			# Configurar para que procese aunque el árbol esté pausado
			animation_player.process_mode = Node.PROCESS_MODE_ALWAYS
			animation_player.speed_scale = _messagebox_theme.wait_indicator_blink_speed
			# Reproducir animación usando call_deferred para asegurar que todo esté listo
			if animation_player.has_animation("Idle"):
				call_deferred("_start_wait_indicator_animation")

	# Posicionar wait indicator según el modo (solo si está visible)
	if wait_indicator.visible:
		var box_size = panel.size if panel.size != Vector2.ZERO else panel_size
		match _messagebox_theme.wait_indicator_mode:
			MessageBoxTheme.WaitIndicatorMode.BOTTOM_RIGHT:
				wait_indicator.position = Vector2(box_size.x - 30, box_size.y - 30) + _messagebox_theme.wait_indicator_offset
			MessageBoxTheme.WaitIndicatorMode.INLINE_END_OF_TEXT:
				# Para portrait box, usar esquina inferior derecha por defecto
				wait_indicator.position = Vector2(box_size.x - 30, box_size.y - 30) + _messagebox_theme.wait_indicator_offset

## Inicia la animación del wait indicator de forma segura
func _start_wait_indicator_animation() -> void:
	if not animation_player:
		return
	if not animation_player.has_animation("Idle"):
		return
	if not wait_indicator.visible:
		return

	# Verificar que el AnimationPlayer esté listo
	if not is_inside_tree():
		return

	# Asegurar que el root_node esté configurado correctamente
	# Si el AnimationPlayer es hijo de WaitIndicator, el root_node debe ser "." (el padre)
	if animation_player.root_node == NodePath(""):
		animation_player.root_node = NodePath(".")

	animation_player.play("Idle")

func _setup_close_mode(auto_close_time: float) -> void:
	match _close_mode:
		CloseMode.AUTO_TIME:
			if auto_close_time > 0.0:
				_auto_close_timer = Timer.new()
				_auto_close_timer.wait_time = auto_close_time
				_auto_close_timer.one_shot = true
				_auto_close_timer.timeout.connect(_on_auto_close_timeout)
				add_child(_auto_close_timer)
				_auto_close_timer.start()
		CloseMode.WAIT_INPUT:
			# El input se maneja en DisplayManager
			pass
		CloseMode.NO_CLOSE:
			# No se cierra automáticamente, requiere ClosePortraitCommand
			pass

func _on_auto_close_timeout() -> void:
	close()

## Cierra el portrait box
func close() -> void:
	if _auto_close_timer:
		_auto_close_timer.queue_free()
		_auto_close_timer = null

	# Detener animación si existe
	if animation_player:
		animation_player.stop()

	visible = false
	# Notificar cambio de visibilidad para el sistema de pausa
	if has_signal("visibility_changed"):
		visibility_changed.emit()
	closed.emit()

func _input(event: InputEvent) -> void:
	# Solo procesar input si está visible y en modo WAIT_INPUT
	if not visible or _close_mode != CloseMode.WAIT_INPUT:
		return

	# Cerrar con cualquier input de aceptación o cancelación
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
