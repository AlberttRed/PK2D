extends AnimatedSprite2D
## Efecto visual que se muestra al pisar hierba.
## Se auto-destruye cuando termina la animación.

func _ready() -> void:
	# Configurar para que la animación continúe aunque el árbol esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Conectar señal de fin de animación
	animation_finished.connect(_on_animation_finished)

	# Reproducir animación por defecto
	if sprite_frames and sprite_frames.has_animation("default"):
		play("default")


func _on_animation_finished() -> void:
	# Auto-destruirse al terminar
	queue_free()
