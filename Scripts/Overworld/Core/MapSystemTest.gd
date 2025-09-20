extends Node

## Script de prueba para verificar el funcionamiento del MapSystem
## Este script puede ser usado para probar las funcionalidades del MapSystem

func _ready() -> void:
	# Esperar un frame para que todos los nodos estén listos
	await get_tree().process_frame
	
	# Obtener el MapSystem
	var map_system: MapSystem = get_tree().get_first_node_in_group("MapSystem")
	if not map_system:
		push_error("MapSystemTest: No se encontró el MapSystem")
		return
	
	print("=== Prueba del MapSystem ===")
	
	# Probar get_active_map()
	var active_map = map_system.get_active_map()
	if active_map:
		print("✓ Mapa activo encontrado: ", active_map.name)
	else:
		print("✗ No se encontró mapa activo")
	
	# Probar get_active_grid()
	var active_grid = map_system.get_active_grid()
	if active_grid:
		print("✓ OverworldGrid activo encontrado: ", active_grid.name)
	else:
		print("✗ No se encontró OverworldGrid activo")
	
	# Probar get_player()
	var player = map_system.get_player()
	if player:
		print("✓ Jugador encontrado: ", player.name)
		print("  Posición del jugador: ", player.global_position)
	else:
		print("✗ No se encontró jugador")
	
	# Probar que el jugador puede acceder al OverworldGrid
	if player and active_grid:
		var player_tile = active_grid.world_to_tile(player.global_position)
		print("✓ Jugador puede acceder al OverworldGrid")
		print("  Tile actual del jugador: ", player_tile)
	else:
		print("✗ El jugador no puede acceder al OverworldGrid")
	
	print("=== Fin de la prueba ===")
