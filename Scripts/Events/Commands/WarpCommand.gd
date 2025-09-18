extends EventCommand
class_name WarpCommand

## Comando para teletransportar al jugador
@export var target_scene: String = ""
@export var target_position: Vector2i = Vector2i.ZERO

func execute(context: Node) -> void:
	print("Warp: Teletransportando a escena '%s' en posición %s" % [target_scene, target_position])
	
	# TODO: Implementar cambio de escena real
	# Por ahora solo mostramos en consola
	if target_scene.is_empty():
		print("Warp: Error - No se especificó escena de destino")
		context.continue_execution()
		return
	
	# Placeholder: Simular teletransporte
	var player = context.get_tree().get_first_node_in_group("Player")
	if player and player.has_method("teleport_to_tile"):
		player.teleport_to_tile(target_position)
	
	context.continue_execution()

func is_async() -> bool:
	# Será asíncrono cuando implementemos cambio de escena
	return false
