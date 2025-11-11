extends ColorRect

## FadeLayer - Sistema de transiciones visuales de fundido
## Maneja fade_in y fade_out para transiciones suaves entre escenas
## También soporta transiciones con imágenes para entrada a combate

signal fade_finished
signal transition_finished

var is_fading: bool = false
var transition_overlay: ColorRect = null
var transition_shader: ShaderMaterial = null

func _ready():
	# Configurar el FadeLayer
	color = Color.BLACK
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	# Inicialmente en negro para ocultar la carga inicial
	modulate.a = 1.0
	visible = true

	# Crear el overlay para transiciones con shader
	_setup_transition_overlay()

	# Conectar señales del SignalManager
	# SignalManager.fade_requested.connect(_on_fade_requested)  # DEPRECATED: Usar DisplayManager.fade_in/out()
	# SignalManager.battle_transition_requested.connect(_on_battle_transition_requested)  # DEPRECATED
	# SignalManager.battle_reveal_requested.connect(_on_battle_reveal_requested)  # DEPRECATED

## Configura el overlay para las transiciones con shader
func _setup_transition_overlay() -> void:
	transition_overlay = ColorRect.new()
	transition_overlay.name = "TransitionOverlay"
	transition_overlay.anchor_left = 0.0
	transition_overlay.anchor_top = 0.0
	transition_overlay.anchor_right = 1.0
	transition_overlay.anchor_bottom = 1.0
	transition_overlay.offset_left = 0
	transition_overlay.offset_top = 0
	transition_overlay.offset_right = 0
	transition_overlay.offset_bottom = 0
	transition_overlay.color = Color.WHITE  # Color base para el shader
	transition_overlay.visible = false
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Cargar el shader
	var shader = load("res://Shaders/transition.gdshader")
	transition_shader = ShaderMaterial.new()
	transition_shader.shader = shader
	transition_overlay.material = transition_shader

	add_child(transition_overlay)

## Ejecuta fade in (fundido a negro)
func fade_in(duration: float = 1.0) -> void:
	if is_fading:
		return

	is_fading = true
	visible = true
	modulate.a = 0.0


	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration)
	await tween.finished

	is_fading = false
	fade_finished.emit()
	# SignalManager.fade_finished.emit()  # DEPRECATED

## Ejecuta fade out (fundido desde negro)
func fade_out(duration: float = 1.0) -> void:
	if is_fading:
		return

	is_fading = true
	visible = true
	modulate.a = 1.0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	await tween.finished

	visible = false
	is_fading = false
	fade_finished.emit()
	# SignalManager.fade_finished.emit()  # DEPRECATED

## DEPRECATED: Maneja las solicitudes de fade desde el SignalManager (ya no se usa)
# func _on_fade_requested(mode: String, duration: float) -> void:
# 	match mode:
# 		"fade_in":
# 			await fade_in(duration)
# 		"fade_out":
# 			await fade_out(duration)
# 		_:
# 			push_warning("FadeLayer: Modo de fade no reconocido: " + mode)

## Verifica si está ejecutando un fade
func is_fade_active() -> bool:
	return is_fading

## Ejecuta parpadeos previos a la transición (efecto clásico de Pokémon)
func play_battle_flashes(flash_duration: float = 0.15) -> void:
	visible = true
	color = Color(0.5, 0.5, 0.5, 1.0)  # Gris

	# Primer parpadeo: Transparente -> Gris -> Transparente
	modulate.a = 0.0
	var tween1 = create_tween()
	tween1.tween_property(self, "modulate:a", 1.0, flash_duration)
	await tween1.finished

	var tween2 = create_tween()
	tween2.tween_property(self, "modulate:a", 0.0, flash_duration)
	await tween2.finished

	# Segundo parpadeo: Transparente -> Gris -> Transparente
	var tween3 = create_tween()
	tween3.tween_property(self, "modulate:a", 1.0, flash_duration)
	await tween3.finished

	var tween4 = create_tween()
	tween4.tween_property(self, "modulate:a", 0.0, flash_duration)
	await tween4.finished

	# Restaurar color negro para la transición
	color = Color.BLACK

## Ejecuta una transición de combate con imagen usando shader (solo entrada, hasta negro)
## texture_path: Ruta a la textura de transición (máscara en escala de grises)
## duration: Duración de la transición de entrada
func play_battle_transition(texture_path: String, duration: float = 1.0) -> void:
	if is_fading:
		return

	is_fading = true

	# Primero hacer los parpadeos previos
	await play_battle_flashes(0.15)

	# Ocultar el MessageBox del overworld justo cuando terminan los parpadeos
	# (En los juegos originales, se oculta al empezar el fade con máscara)
	DisplayManager.request_hide_overworld_messagebox()

	visible = true

	# Cargar y configurar la textura de transición
	var texture = load(texture_path)
	if texture == null:
		push_error("FadeLayer: No se pudo cargar la textura de transición: " + texture_path)
		is_fading = false
		return

	# Mantener el FadeLayer opaco pero con color transparente durante la transición
	modulate.a = 1.0
	color = Color.TRANSPARENT

	# Configurar el shader con la textura de máscara
	transition_shader.set_shader_parameter("transition_mask", texture)
	transition_shader.set_shader_parameter("progress", 0.0)
	transition_shader.set_shader_parameter("smoothness", 0.01)  # Suavizado para transiciones graduales

	# El overlay será visible y el shader se encarga del efecto
	transition_overlay.modulate.a = 1.0
	transition_overlay.visible = true

	# Animar el shader desde 0.0 hasta 1.0, exactamente el rango de la máscara
	# Ahora es visible desde el inicio, no necesitamos valores negativos
	var tween = create_tween()
	tween.tween_method(
		func(value: float): transition_shader.set_shader_parameter("progress", value),
		0.0,   # Empezar desde el inicio de la máscara
		1.0,   # Terminar al final de la máscara
		duration
	).set_trans(Tween.TRANS_LINEAR)

	await tween.finished

	# Ocultar el overlay de transición
	transition_overlay.visible = false

	# Restaurar el color negro para mantener la pantalla en negro
	color = Color.BLACK

	# La pantalla queda en negro - NO hacemos fade_out aquí
	# El fade_out se hará manualmente cuando el combate esté listo

	is_fading = false
	transition_finished.emit()
	# SignalManager.battle_transition_finished.emit()  # DEPRECATED

## Revelar la escena de combate usando transición con máscara (inverso: de negro a transparente)
func reveal_battle(duration: float = 0.4) -> void:
	if is_fading:
		return

	is_fading = true
	visible = true

	# Cargar la textura de reveal
	var texture = load("res://Sprites/Transiciones/wipe-vertical-reflected.png")
	if texture == null:
		push_error("FadeLayer: No se pudo cargar la textura de reveal")
		is_fading = false
		return

	# El FadeLayer debe estar opaco pero transparente para no tapar el shader
	modulate.a = 1.0
	color = Color.TRANSPARENT

	# Configurar el shader con la máscara de reveal
	transition_shader.set_shader_parameter("transition_mask", texture)
	transition_shader.set_shader_parameter("progress", 1.0)  # Empezar en negro (inverso)
	transition_shader.set_shader_parameter("smoothness", 0.01)

	# Mostrar el overlay
	transition_overlay.modulate.a = 1.0
	transition_overlay.visible = true

	# Animar el shader de 1.0 a 0.0 (de negro a transparente)
	var tween = create_tween()
	tween.tween_method(
		func(value: float): transition_shader.set_shader_parameter("progress", value),
		1.0,   # Empezar totalmente negro
		0.0,   # Terminar totalmente transparente
		duration
	).set_trans(Tween.TRANS_LINEAR)

	await tween.finished

	# Ocultar todo el FadeLayer
	transition_overlay.visible = false
	visible = false
	color = Color.BLACK  # Restaurar para futuros fades normales
	is_fading = false

	# Emitir señal de que el reveal terminó
	# SignalManager.battle_reveal_finished.emit()  # DEPRECATED

## DEPRECATED: Ya no se usan, Battle.gd llama directamente a DisplayManager
# func _on_battle_transition_requested(texture_path: String, duration: float) -> void:
# 	await play_battle_transition(texture_path, duration)

# func _on_battle_reveal_requested() -> void:
# 	await reveal_battle(0.4)
