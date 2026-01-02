extends Node
class_name MOSystem

## MOSystem - Sistema central para gestionar el uso de Máquinas Ocultas (MO)
## Se encarga de:
## - Validar si una MO puede ser usada
## - Ejecutar el efecto lógico de la MO
## - Comunicar el resultado mediante señales
##
## Utiliza OverworldContext para acceder a otros sistemas sin acoplamiento
## NO gestiona mensajes ni animaciones visuales, eso lo hacen los eventos

# Señales locales de MO
signal mo_requested(mo_type: String, target: Node)
signal mo_finished(mo_type: String, success: bool, reason: String)

# Referencia al OverworldContext (inyectada desde OverworldCoordinator)
var context: OverworldContext = null

# Diccionario de acciones MO disponibles: {"CUT": MOAction, "SURF": MOAction, ...}
var mo_actions: Dictionary = {}

# Estados activos de MOs en el mapa actual (para STRENGTH, FLASH, etc.)
# Ejemplo: {"STRENGTH_ENABLED": true, "FLASH_ACTIVE": true}
var active_effects: Dictionary = {}

const FLASH_EFFECT_KEY := "FLASH_ACTIVE"
# Estado actual del sistema
var is_processing_mo: bool = false
var current_mo_type: String = ""
var current_target: Node = null

func _ready() -> void:
	# Inicializar el diccionario de acciones MO
	_initialize_mo_actions()

## Inicializa el diccionario de acciones MO disponibles
## Las clases específicas de cada MO se registrarán aquí cuando se implementen
func _initialize_mo_actions() -> void:
	# Registrar MO: CORTE (CUT)
	var cut_action = preload("res://Scripts/Overworld/Core/MOActions/CutAction.gd").new()
	register_mo_action("CUT", cut_action)

	# Registrar MO: GOLPE ROCA (ROCK SMASH)
	var rock_smash_action = preload("res://Scripts/Overworld/Core/MOActions/RockSmashAction.gd").new()
	register_mo_action("ROCK_SMASH", rock_smash_action)

	# Registrar MO: FUERZA (STRENGTH)
	var strength_action = preload("res://Scripts/Overworld/Core/MOActions/StrengthAction.gd").new()
	register_mo_action("STRENGTH", strength_action)

	# Registrar MO: SURF
	var surf_action = preload("res://Scripts/Overworld/Core/MOActions/SurfAction.gd").new()
	register_mo_action("SURF", surf_action)

	# Registrar MO: DESTELLO (FLASH)
	var flash_action = preload("res://Scripts/Overworld/Core/MOActions/FlashAction.gd").new()
	register_mo_action("FLASH", flash_action)

## Registra una nueva acción MO en el sistema
## @param mo_type: Identificador de la MO (ej: "CUT", "SURF")
## @param action: Instancia de MOAction que define el comportamiento
func register_mo_action(mo_type: String, action: Resource) -> void:
	if mo_type.is_empty():
		push_error("MOSystem: No se puede registrar una MO sin tipo")
		return

	if not action:
		push_error("MOSystem: No se puede registrar una acción MO nula")
		return

	# Inyectar referencia al MOSystem en la acción (para acceso a efectos activos)
	if action.has_method("set_mo_system"):
		action.set_mo_system(self)

	mo_actions[mo_type] = action

## Elimina una acción MO del sistema
## @param mo_type: Identificador de la MO a eliminar
func unregister_mo_action(mo_type: String) -> void:
	if mo_actions.has(mo_type):
		mo_actions.erase(mo_type)
		print("MOSystem: MO desregistrada - Tipo: %s" % mo_type)

## Verifica si una MO está registrada
## @param mo_type: Identificador de la MO
## @return: true si está registrada, false si no
func has_mo_action(mo_type: String) -> bool:
	return mo_actions.has(mo_type)

## Procesa una petición de MO validando y ejecutando la acción
## @param mo_type: Tipo de MO
## @param target: Nodo target
func _process_mo_request(mo_type: String, target: Node) -> Dictionary:
	is_processing_mo = true
	current_mo_type = mo_type
	current_target = target

	var outcome: Dictionary = {}

	# Verificar que la MO esté registrada
	if not mo_actions.has(mo_type):
		push_warning("MOSystem: MO '%s' no está registrada" % mo_type)
		outcome = {"success": false, "error": "MO no registrada"}
		mo_finished.emit(mo_type, false, outcome.error)
		_reset_state()
		return outcome

	# Obtener la acción MO
	var action: Resource = mo_actions[mo_type]

	# Obtener el jugador del contexto
	if not context:
		push_error("MOSystem: Contexto no disponible")
		outcome = {"success": false, "error": "Contexto no disponible"}
		mo_finished.emit(mo_type, false, outcome.error)
		_reset_state()
		return outcome

	var player: Node = context.get_player()
	if not player:
		push_error("MOSystem: Player no disponible en el contexto")
		outcome = {"success": false, "error": "Player no disponible"}
		mo_finished.emit(mo_type, false, outcome.error)
		_reset_state()
		return outcome

	# Validar si se puede usar la MO
	if not action.can_use(player, target):
		print("MOSystem: No se puede usar la MO '%s' en el contexto actual" % mo_type)
		outcome = {"success": false, "error": "No se puede usar la MO en el contexto actual"}
		mo_finished.emit(mo_type, false, outcome.error)
		_reset_state()
		return outcome

	# Obtener el EventSystem del contexto
	var event_sys: EventSystem = context.get_event_system()
	if not event_sys or not event_sys.controller:
		push_error("MOSystem: EventController no disponible")
		outcome = {"success": false, "error": "EventController no disponible"}
		mo_finished.emit(mo_type, false, outcome.error)
		_reset_state()
		return outcome

	var event_controller = event_sys.controller

	# Ejecutar el flujo completo de la MO (mensajes, choice, animación, etc.)
	var result: Dictionary = await action.execute(player, target, event_controller)

	# Verificar el resultado y emitir señal unificada
	if result.get("success", false):
		print("MOSystem: MO '%s' ejecutada con éxito" % mo_type)
		outcome = {"success": true}
		mo_finished.emit(mo_type, true, "")
	elif result.get("cancelled", false):
		print("MOSystem: MO '%s' cancelada por el jugador" % mo_type)
		outcome = {"success": false, "cancelled": true, "error": "Cancelado"}
		mo_finished.emit(mo_type, false, "Cancelado")
	else:
		var error_msg = result.get("error", "Error desconocido")
		print("MOSystem: MO '%s' falló - %s" % [mo_type, error_msg])
		outcome = {"success": false, "error": error_msg}
		mo_finished.emit(mo_type, false, error_msg)

	_reset_state()
	return outcome

## Resetea el estado interno del sistema
func _reset_state() -> void:
	is_processing_mo = false
	current_mo_type = ""
	current_target = null

func play_overlay_for_pokemon(pokemon: Pokemon, visual_override: Variant = null) -> void:
	var overlay_visual: Variant = visual_override
	if overlay_visual == null and pokemon:
		overlay_visual = pokemon.get_battle_front_sprite()

	if overlay_visual == null:
		return

	await DisplayManager.play_mo_overlay(overlay_visual)

## Verifica si el sistema está procesando una MO
func is_busy() -> bool:
	return is_processing_mo

## Obtiene información del estado actual
func get_current_mo_info() -> Dictionary:
	return {
		"is_processing": is_processing_mo,
		"mo_type": current_mo_type,
		"target": current_target,
		"registered_mos": mo_actions.keys()
	}

## Obtiene todas las MO registradas
func get_registered_mo_types() -> Array:
	return mo_actions.keys()

## ========================
## GESTIÓN DE EFECTOS ACTIVOS
## ========================

## Activa un efecto de MO en el mapa actual
## Útil para MOs como STRENGTH (habilita empujar rocas) o FLASH (ilumina cueva)
## @param effect_name: Nombre del efecto (ej: "STRENGTH_ENABLED", "FLASH_ACTIVE")
## @param value: Estado del efecto (true = activo, false = desactivo)
func activate_effect(effect_name: String, value: bool = true) -> void:
	if effect_name.is_empty():
		push_warning("MOSystem: Nombre de efecto vacío")
		return

	active_effects[effect_name] = value
	print("MOSystem: Efecto '%s' = %s" % [effect_name, value])

	if effect_name == FLASH_EFFECT_KEY:
		_apply_flashlight_overlay(value)

## Verifica si un efecto de MO está activo
## @param effect_name: Nombre del efecto a verificar
## @return: true si está activo, false si no
func is_effect_active(effect_name: String) -> bool:
	return active_effects.get(effect_name, false)

## Desactiva un efecto específico
## @param effect_name: Nombre del efecto a desactivar
func deactivate_effect(effect_name: String) -> void:
	if active_effects.has(effect_name):
		active_effects.erase(effect_name)
		print("MOSystem: Efecto '%s' desactivado" % effect_name)

		if effect_name == FLASH_EFFECT_KEY:
			_apply_flashlight_overlay(false)

## Resetea todos los efectos activos
## Se llama automáticamente al cambiar de mapa
func reset_effects() -> void:
	if not active_effects.is_empty():
		print("MOSystem: Reseteando %d efecto(s) activo(s)" % active_effects.size())
		active_effects.clear()
		_apply_flashlight_overlay(false)

## Callback cuando el jugador cambia de mapa
## Resetea los efectos de MO (STRENGTH y FLASH no persisten al cambiar de mapa)
func _on_map_changed(_map_id: String, _tile_pos: Vector2i) -> void:
	reset_effects()
	print("MOSystem: Efectos de MO reseteados al cambiar de mapa")

## Obtiene todos los efectos activos (para debug)
func get_active_effects() -> Dictionary:
	return active_effects.duplicate()


## Aplica el efecto de luz de destello a la capa de overlays
func apply_flash_light(enabled: bool, _config: Dictionary = {}) -> void:
	if enabled:
		activate_effect(FLASH_EFFECT_KEY, true)
	else:
		deactivate_effect(FLASH_EFFECT_KEY)

	var overlay := _get_overlay_or_warn()
	if not overlay:
		return

	overlay.set_flashlight_enabled(enabled)


func _apply_flashlight_overlay(enabled: bool) -> void:
	var overlay := _get_overlay()
	if not overlay:
		return

	overlay.set_flashlight_enabled(enabled)


## ========================
## DESTELLO - GESTIÓN DE ILUMINACIÓN
## ========================

func enable_flash_override(_map_id: String, _config: Dictionary = {}) -> void:
	# Destello persistente se gestionará más adelante con flag global
	print("MOSystem: enable_flash_override() sin efecto (pendiente de implementación)")


func disable_flash_override() -> void:
	print("MOSystem: disable_flash_override() sin efecto (pendiente de implementación)")


func apply_overlay_overrides(_overlay: OverlayLayer, _map_id: String) -> void:
	pass


func is_flash_override_active() -> bool:
	return false


func _apply_flash_override_to_overlay() -> void:
	pass

## Maneja solicitudes externas de MO
func request_mo(mo_type: String, target: Node) -> Dictionary:
	if is_processing_mo:
		push_warning("MOSystem: Ya hay una MO en proceso, ignorando solicitud")
		return {"success": false, "error": "MO en proceso"}
	mo_requested.emit(mo_type, target)
	return await _process_mo_request(mo_type, target)

func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context
	if context:
		var warp_sys = context.get_warp_system()
		if warp_sys and not warp_sys.warp_finished.is_connected(_on_map_changed):
			warp_sys.warp_finished.connect(_on_map_changed)


func _get_overlay() -> OverlayLayer:
	if not context:
		return null
	return context.get_overlay_layer()


func _get_overlay_or_warn() -> OverlayLayer:
	var overlay := _get_overlay()
	if not overlay:
		push_warning("MOSystem: OverlayLayer no disponible para aplicar efecto de destello")
	return overlay
