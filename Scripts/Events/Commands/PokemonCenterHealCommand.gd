extends EventCommand
class_name PokemonCenterHealCommand

## Secuencia visual de la máquina de curación del Centro Pokémon.
##
## Atlas bolas (1-based como en el editor de sprites):
## - Filas = nº de bolas. Sheet1: filas 1..3 → 1..3 bolas. Sheet2: filas 1..3 → 4..6 bolas.
## - Columna 1 = reposo; columnas 2..4 = frames de brillo.
##
## Aparición (siempre columna 1):
##   S1 F1C1 → S1 F2C1 → S1 F3C1 → S2 F1C1 → S2 F2C1 → S2 F3C1 (hasta N del party)
## Brillo (última fila alcanzada, p.ej. 6 bolas):
##   S2 F3C2 → S2 F3C3 → S2 F3C4 (y se repite según glow_loops)
##
## Monitor: sheet vertical 64×128 → 4 frames de 64×32. Parpadea durante el brillo.

const SHEET_1_PATH := "res://Sprites/Others/Healing balls 1.png"
const SHEET_2_PATH := "res://Sprites/Others/Healing balls 2.png"
const MONITOR_PATH := "res://Sprites/Others/pokemoncenter_monitor.png"
const HEAL_ME_PATH := "res://Audio/ME/Pkmn healing.ogg"
const BALL_SFX_PATH := "res://Audio/SE/Battle catch click.ogg"

## Atlas 256×192: 4 columnas × 3 filas útiles.
## Ancho de celda 64; alto 48 (no 64: en sheet2 las 4 bolas cruzan y=64).
## La franja y=0..47 está vacía; la fila 1 empieza en y=48.
const CELL_W := 64
const CELL_H := 48
const ROW_ORIGIN_Y := 48
## Columnas 2..4 del atlas (1-based) = brillo.
const GLOW_COLUMNS_1BASED: Array[int] = [2, 3, 4]
const BALLS_SPRITE_NAME := "HealingBallsSprite"
const MONITOR_SPRITE_NAME := "HealingMonitorSprite"
const MONITOR_FRAME_W := 64
const MONITOR_FRAME_H := 32
const MONITOR_FRAME_COUNT := 4

## Vacío = evento que ejecuta el comando (p. ej. EventoCP). Opcional: otro evento ancla.
@export var machine_event_name: String = ""
## Offset de la animación de bolas relativo al evento ancla.
## Con EventoCP en el layout actual: (-48, -48).
@export var sprite_offset: Vector2 = Vector2(-48, -48)
## Offset de la animación del monitor (parpadeo) relativo al evento ancla.
@export var monitor_offset: Vector2 = Vector2(0, -64)
@export_range(0.05, 1.0, 0.01) var frame_duration: float = 0.12
@export_range(1, 12, 1) var glow_loops: int = 4
@export_range(0.0, 1.0, 0.01) var ball_appear_delay: float = 0.50

var _context: Node = null
var _sprite: Sprite2D = null
var _monitor_sprite: Sprite2D = null
var _monitor_frame: int = 0
var _monitor_dir: int = 1


func execute(context: Node) -> void:
	_context = context
	await _run_heal_sequence(context)
	_finish()


func _run_heal_sequence(context: Node) -> void:
	var party_count := _get_party_count()
	if party_count <= 0:
		push_warning("PokemonCenterHealCommand: party vacío; se omite visual")
		_heal_party()
		return

	var anchor := _resolve_anchor(context)
	if anchor == null:
		push_warning("PokemonCenterHealCommand: no se pudo resolver el evento ancla; se cura sin visual")
		_heal_party()
		return

	_sprite = _ensure_sprite(anchor, BALLS_SPRITE_NAME)
	# Evitar doble recorte si el nodo quedó de una versión anterior con region_rect.
	_sprite.region_enabled = false
	_sprite.region_rect = Rect2()
	_sprite.centered = true
	# Bias del atlas (independiente del sprite_offset del comando):
	# X -16 = padding izquierdo del sheet; Y +8 = compensación celda 64×48.
	_sprite.offset = Vector2(-16, 8)
	_sprite.position = sprite_offset
	_sprite.z_index = 10
	_sprite.visible = true

	_monitor_sprite = _ensure_sprite(anchor, MONITOR_SPRITE_NAME)
	_monitor_sprite.region_enabled = false
	_monitor_sprite.region_rect = Rect2()
	_monitor_sprite.centered = true
	# Bias del atlas (independiente del monitor_offset del comando).
	_monitor_sprite.offset = Vector2(16, -16)
	_monitor_sprite.position = monitor_offset
	_monitor_sprite.z_index = 5
	_monitor_sprite.visible = true
	_monitor_frame = 0
	_monitor_dir = 1
	_show_monitor_frame(0)

	var ball_sfx := load(BALL_SFX_PATH) as AudioStream

	# --- Aparición: fila 1..N, siempre columna 1 ---
	for balls in range(1, party_count + 1):
		var sheet_idx := 1 if balls <= 3 else 2
		var row_1based := balls if balls <= 3 else balls - 3
		if not _show_cell(sheet_idx, row_1based, 1):
			push_warning("PokemonCenterHealCommand: fallo celda sheet=%d fila=%d col=1" % [sheet_idx, row_1based])
			break
		print("PokemonCenterHealCommand: aparición sheet=%d fila=%d col=1 (bolas=%d)" % [sheet_idx, row_1based, balls])
		if ball_sfx:
			AudioManager.play_sfx(ball_sfx, "SFX")
		await context.get_tree().process_frame
		if ball_appear_delay > 0.0:
			await context.get_tree().create_timer(ball_appear_delay).timeout

	var heal_me := load(HEAL_ME_PATH) as AudioStream
	if heal_me:
		AudioManager.play_me(heal_me)

	# --- Brillo + parpadeo del monitor a la vez ---
	# Bolas: glow_loops × 3 columnas. Monitor: 2 frames por paso de bola
	# para completar 4 iluminaciones (pico en frame 4) en el mismo tiempo.
	var final_sheet := 1 if party_count <= 3 else 2
	var final_row := party_count if party_count <= 3 else party_count - 3
	var half_duration := frame_duration * 0.5
	for _loop in range(maxi(glow_loops, 1)):
		for col_1based in GLOW_COLUMNS_1BASED:
			_show_cell(final_sheet, final_row, col_1based)
			_advance_monitor_frame()
			if half_duration > 0.0:
				await context.get_tree().create_timer(half_duration).timeout
			_advance_monitor_frame()
			if half_duration > 0.0:
				await context.get_tree().create_timer(half_duration).timeout

	_heal_party()
	_show_cell(final_sheet, final_row, 1)
	_show_monitor_frame(0)
	if _sprite:
		_sprite.visible = false
	if _monitor_sprite:
		_monitor_sprite.visible = false
	_sprite = null
	_monitor_sprite = null


## sheet_idx 1|2, row/col 1-based según el sprite sheet.
func _show_cell(sheet_idx: int, row_1based: int, col_1based: int) -> bool:
	if _sprite == null:
		return false
	var path := SHEET_1_PATH if sheet_idx == 1 else SHEET_2_PATH
	var sheet := load(path) as Texture2D
	if sheet == null:
		push_warning("PokemonCenterHealCommand: no se pudo cargar %s" % path)
		return false

	var row0 := clampi(row_1based - 1, 0, 2)
	var col0 := clampi(col_1based - 1, 0, 3)

	# AtlasTexture nuevo cada vez para forzar redibujado al cambiar de fila.
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(
		col0 * CELL_W,
		ROW_ORIGIN_Y + row0 * CELL_H,
		CELL_W,
		CELL_H
	)
	_sprite.texture = atlas
	return true


func _advance_monitor_frame() -> void:
	# Ping-pong: 1→2→3→4→3→2→1→2→…
	_show_monitor_frame(_monitor_frame)
	var last := MONITOR_FRAME_COUNT - 1
	if _monitor_frame >= last:
		_monitor_dir = -1
	elif _monitor_frame <= 0:
		_monitor_dir = 1
	_monitor_frame += _monitor_dir


func _show_monitor_frame(frame_index: int) -> bool:
	if _monitor_sprite == null:
		return false
	var sheet := load(MONITOR_PATH) as Texture2D
	if sheet == null:
		push_warning("PokemonCenterHealCommand: no se pudo cargar %s" % MONITOR_PATH)
		return false
	var frame0 := clampi(frame_index, 0, MONITOR_FRAME_COUNT - 1)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, frame0 * MONITOR_FRAME_H, MONITOR_FRAME_W, MONITOR_FRAME_H)
	_monitor_sprite.texture = atlas
	return true


func _heal_party() -> void:
	if GameStateService == null:
		return
	var party = GameStateService.get_party()
	if party != null and party.has_method("heal_all"):
		party.heal_all()


func _get_party_count() -> int:
	if GameStateService == null:
		return 0
	var party = GameStateService.get_party()
	if party == null or not party.has_method("count"):
		return 0
	return clampi(int(party.count()), 0, 6)


func _ensure_sprite(anchor: Node2D, sprite_name: String) -> Sprite2D:
	var existing := anchor.get_node_or_null(sprite_name)
	if existing is Sprite2D:
		return existing as Sprite2D
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.visible = false
	sprite.centered = true
	anchor.add_child(sprite)
	return sprite


## Vacío → evento origen (source_event). Nombre → busca ese evento.
func _resolve_anchor(context: Node) -> Node2D:
	if machine_event_name.is_empty():
		if context is EventController and context.current_page:
			var source = context.current_page.source_event
			if source is Node2D:
				return source as Node2D
		return null
	return _find_event(context, machine_event_name)


func _find_event(context: Node, event_name: String) -> Node2D:
	if event_name.is_empty():
		return null
	var tree := context.get_tree()
	if tree == null:
		return null
	for event in tree.get_nodes_in_group("events"):
		if event.name == event_name and event is Node2D:
			return event as Node2D
	return _find_node_by_name_recursive(tree.root, event_name)


func _find_node_by_name_recursive(node: Node, event_name: String) -> Node2D:
	if node.name == event_name and node is Node2D:
		return node as Node2D
	for child in node.get_children():
		var found := _find_node_by_name_recursive(child, event_name)
		if found:
			return found
	return null


func _finish() -> void:
	if _context:
		_context.continue_execution()
		_context = null


func is_async() -> bool:
	return true


func is_safe_for_parallel() -> bool:
	return false
