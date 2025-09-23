extends ColorRect

## FadeLayer - Sistema de transiciones visuales de fundido
## Maneja fade_in y fade_out para transiciones suaves entre escenas

signal fade_finished

var is_fading: bool = false

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
	
	# Inicialmente invisible
	modulate.a = 0.0
	visible = false
	
	# Conectar señales del SignalManager
	SignalManager.fade_requested.connect(_on_fade_requested)

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
	SignalManager.fade_finished.emit()

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
	SignalManager.fade_finished.emit()

## Maneja las solicitudes de fade desde el SignalManager
func _on_fade_requested(mode: String, duration: float) -> void:
	match mode:
		"fade_in":
			await fade_in(duration)
		"fade_out":
			await fade_out(duration)
		_:
			push_warning("FadeLayer: Modo de fade no reconocido: " + mode)

## Verifica si está ejecutando un fade
func is_fade_active() -> bool:
	return is_fading
