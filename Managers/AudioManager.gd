extends Node
class_name AudioManager

## AudioManager - Gestión centralizada de BGM y SFX bajo Main (sin autoload).
## Acceso global vía AudioManager.play_bgm() / AudioManager.instance.

static var instance: AudioManager = null

const BUS_MASTER := "Master"
const BUS_BGM := "BGM"
const BUS_SFX := "SFX"
const BUS_UI := "UI"

const SFX_POOL_SIZE := 6
const BGM_BUS_VOLUME_DB := 0.0
const SILENT_DB := -80.0
const BGM_FADE_TRANS := Tween.TRANS_SINE
const BGM_FADE_EASE := Tween.EASE_IN_OUT

const BATTLE_BGM_WILD_PATH := "res://Audio/BGM/Battle (Wild Pokémon) Cut.ogg"
const BATTLE_BGM_TRAINER_PATH := "res://Audio/BGM/Battle (Trainer) Cut.ogg"
const BATTLE_BGM_GYM_PATH := "res://Audio/BGM/Battle (Gym Leader) Cut.ogg"
const BATTLE_VICTORY_BGM_WILD_PATH := "res://Audio/BGM/Victory (Wild Pokémon) Cut.ogg"
const BATTLE_VICTORY_BGM_TRAINER_PATH := "res://Audio/BGM/Victory (Trainer) Cut.ogg"
const BATTLE_VICTORY_BGM_GYM_PATH := "res://Audio/BGM/Victory (Gym Leader) Cut.ogg"
const BATTLE_ME_CAPTURE_SUCCESS_PATH := "res://Audio/ME/Battle capture success.ogg"
const BATTLE_EXIT_BGM_FADE := 0.35

const UI_SFX_CURSOR_PATH := "res://Audio/SE/GUI sel cursor.ogg"
const UI_SFX_MENU_OPEN_PATH := "res://Audio/SE/GUI menu open.ogg"
const UI_SFX_POKEDEX_OPEN_PATH := "res://Audio/SE/GUI pokedex open.ogg"
const UI_SFX_SUMMARY_CHANGE_PAGE_PATH := "res://Audio/SE/GUI summary change page.ogg"
const UI_SFX_USE_ITEM_IN_PARTY_PATH := "res://Audio/SE/Use item in party.ogg"
const BATTLE_SFX_FLEE_PATH := "res://Audio/SE/Battle flee.ogg"
## El .ogg de huida viene muy bajo frente al resto de SFX de batalla.
const BATTLE_SFX_FLEE_VOLUME_DB := 10.0
## Balanceos y click de captura exitosa vienen más bajos que throw/drop.
const BATTLE_SFX_BALL_SHAKE_VOLUME_DB := 10.0
const BATTLE_SFX_CATCH_CLICK_VOLUME_DB := 10.0
## El rip de level-up viene más bajo que throw/damage; mismo criterio que flee/catch.
const BATTLE_SFX_LEVEL_UP_VOLUME_DB := 10.0
const BATTLE_SFX_DAMAGE_WEAK_PATH := "res://Audio/SE/Battle damage weak.ogg"
const BATTLE_SFX_DAMAGE_NORMAL_PATH := "res://Audio/SE/Battle damage normal.ogg"
const BATTLE_SFX_DAMAGE_SUPER_PATH := "res://Audio/SE/Battle damage super.ogg"
const BATTLE_SFX_THROW_PATH := "res://Audio/SE/Battle throw.ogg"
const BATTLE_SFX_BALL_DROP_PATH := "res://Audio/SE/Battle ball drop.ogg"
const BATTLE_SFX_RECALL_PATH := "res://Audio/SE/Battle recall.ogg"
const BATTLE_SFX_JUMP_TO_BALL_PATH := "res://Audio/SE/Battle jump to ball.ogg"
const BATTLE_SFX_BALL_HIT_PATH := "res://Audio/SE/Battle ball hit.ogg"
const BATTLE_SFX_BALL_SHAKE_PATH := "res://Audio/SE/Battle ball shake.ogg"
const BATTLE_SFX_CATCH_CLICK_PATH := "res://Audio/SE/Battle catch click.ogg"
const BATTLE_SFX_STAT_INCREASE_PATH := "res://Audio/SE/Anim/increase.ogg"
const BATTLE_SFX_STAT_DECREASE_PATH := "res://Audio/SE/Anim/decrease.ogg"
const BATTLE_SFX_EXP_GAIN_PATH := "res://Audio/SE/Pkmn exp gain.ogg"
const BATTLE_SFX_EXP_FULL_PATH := "res://Audio/SE/Pkmn exp full.ogg"
const BATTLE_SFX_LEVEL_UP_PATH := "res://Audio/SE/Pkmn level up.ogg"
const BATTLE_SFX_FAINT_PATH := "res://Audio/SE/Pkmn faint.ogg"
const BATTLE_SFX_HEAL_HP_RESTORE_PATH := "res://Audio/SE/In-Battle Heal HP Restore.ogg"
## Rip GBA de curación suele venir más bajo que throw/damage.
const BATTLE_SFX_HEAL_HP_RESTORE_VOLUME_DB := 10.0

@onready var _bgm_player_a: AudioStreamPlayer = $BGMPlayerA
@onready var _bgm_player_b: AudioStreamPlayer = $BGMPlayerB
@onready var _sfx_pool: Node = $SFXPool
@onready var _exp_gain_player: AudioStreamPlayer = $ExpGainPlayer
@onready var _me_player: AudioStreamPlayer = $MEPlayer

var _active_bgm_player: AudioStreamPlayer
var _inactive_bgm_player: AudioStreamPlayer
var _current_bgm_stream: AudioStream = null
var _bgm_tween: Tween = null
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next_index: int = 0
## Evita reiniciar la fanfare de victoria varias veces en el mismo combate.
var _battle_victory_started: bool = false
var _me_finished_cb: Callable = Callable()


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_active_bgm_player = _bgm_player_a
	_inactive_bgm_player = _bgm_player_b
	_setup_sfx_pool()


# === API PÚBLICA ESTÁTICA ===

static func play_bgm(stream: AudioStream, fade_in: float = 0.0, loop: bool = true) -> void:
	if instance == null:
		push_error("AudioManager: No hay instancia disponible")
		return
	instance._play_bgm(stream, fade_in, loop)


static func stop_bgm(fade_out: float = 0.0) -> void:
	if instance == null:
		push_error("AudioManager: No hay instancia disponible")
		return
	instance._stop_bgm(fade_out)


static func crossfade_bgm(stream: AudioStream, duration: float = 1.0, loop: bool = true) -> void:
	if instance == null:
		push_error("AudioManager: No hay instancia disponible")
		return
	instance._crossfade_bgm(stream, duration, loop)


static func play_sfx(stream: AudioStream, bus: String = BUS_SFX, volume_db: float = 0.0) -> void:
	if instance == null:
		push_error("AudioManager: No hay instancia disponible")
		return
	instance._play_sfx(stream, bus, volume_db)


static func set_bus_volume(bus_name: String, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("AudioManager: Bus '%s' no encontrado" % bus_name)
		return
	var linear_value := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_value) if linear_value > 0.0 else SILENT_DB)


static func play_battle_bgm(rules: BattleRules, enemy_participants: Array) -> void:
	if instance == null:
		push_error("AudioManager: No hay instancia disponible")
		return
	instance._play_battle_bgm(rules, enemy_participants)


## Victoria de combate (wild / trainer / gym). No-op si ya se inició en este combate.
static func play_battle_victory_bgm(rules: BattleRules, enemy_participants: Array = []) -> void:
	if instance == null:
		push_error("AudioManager: No hay instancia disponible")
		return
	instance._play_battle_victory_bgm(rules, enemy_participants)


## ME de captura exitosa; al terminar arranca automáticamente Victory (Wild).
## No espera: el diálogo puede continuar mientras suena.
static func play_battle_capture_success_me() -> void:
	if instance == null:
		push_error("AudioManager: No hay instancia disponible")
		return
	instance._play_battle_capture_success_me()


static func is_bgm_playing() -> bool:
	if instance == null:
		return false
	return instance._is_bgm_playing()


static func resolve_map_bgm_fade(map_fade: float) -> float:
	if instance == null:
		return map_fade
	if instance._is_battle_bgm_playing():
		return minf(map_fade, BATTLE_EXIT_BGM_FADE)
	return map_fade


## SFX de menú (estilo Gen 3: un solo sonido para cursor, confirmar y cancelar).
static func play_ui_cursor() -> void:
	_play_ui_sfx(UI_SFX_CURSOR_PATH)


static func play_ui_menu_open() -> void:
	_play_ui_sfx(UI_SFX_MENU_OPEN_PATH)


static func play_ui_select() -> void:
	play_ui_cursor()


static func play_ui_cancel() -> void:
	play_ui_cursor()


static func play_ui_pokedex_open() -> void:
	_play_ui_sfx(UI_SFX_POKEDEX_OPEN_PATH)


static func play_ui_change_page() -> void:
	_play_ui_sfx(UI_SFX_SUMMARY_CHANGE_PAGE_PATH)


## Usar objeto sobre un Pokémon desde el equipo (poción, antídoto, etc.).
static func play_ui_use_item_in_party() -> void:
	_play_ui_sfx(UI_SFX_USE_ITEM_IN_PARTY_PATH)


static func play_battle_flee() -> void:
	_play_battle_sfx(BATTLE_SFX_FLEE_PATH, BATTLE_SFX_FLEE_VOLUME_DB)


## Sonido de efectividad de tipos al impactar (Gen 3: antes del hit animation).
static func play_battle_damage_effectiveness(effectiveness: float) -> void:
	if effectiveness <= 0.0:
		return
	var path := BATTLE_SFX_DAMAGE_NORMAL_PATH
	if effectiveness > 1.0:
		path = BATTLE_SFX_DAMAGE_SUPER_PATH
	elif effectiveness < 1.0:
		path = BATTLE_SFX_DAMAGE_WEAK_PATH
	_play_battle_sfx(path)


static func play_battle_throw() -> void:
	_play_battle_sfx(BATTLE_SFX_THROW_PATH)


static func play_battle_ball_drop() -> void:
	_play_battle_sfx(BATTLE_SFX_BALL_DROP_PATH)


static func play_battle_recall() -> void:
	_play_battle_sfx(BATTLE_SFX_RECALL_PATH)


static func play_battle_jump_to_ball() -> void:
	_play_battle_sfx(BATTLE_SFX_JUMP_TO_BALL_PATH)


static func play_battle_ball_hit() -> void:
	_play_battle_sfx(BATTLE_SFX_BALL_HIT_PATH)


static func play_battle_ball_shake() -> void:
	_play_battle_sfx(BATTLE_SFX_BALL_SHAKE_PATH, BATTLE_SFX_BALL_SHAKE_VOLUME_DB)


static func play_battle_catch_click() -> void:
	_play_battle_sfx(BATTLE_SFX_CATCH_CLICK_PATH, BATTLE_SFX_CATCH_CLICK_VOLUME_DB)


static func play_battle_stat_increase() -> void:
	_play_battle_sfx(BATTLE_SFX_STAT_INCREASE_PATH)


static func play_battle_stat_decrease() -> void:
	_play_battle_sfx(BATTLE_SFX_STAT_DECREASE_PATH)


## Sonido continuo mientras sube la barra EXP; se corta al terminar la animación (Gen 3).
static func play_battle_exp_gain() -> void:
	if instance == null:
		return
	instance._play_battle_exp_gain()


static func stop_battle_exp_gain() -> void:
	if instance == null:
		return
	instance._stop_battle_exp_gain()


## Al llenar un segmento de EXP justo antes de subir de nivel.
static func play_battle_exp_full() -> void:
	_play_battle_sfx(BATTLE_SFX_EXP_FULL_PATH)


static func play_battle_level_up() -> void:
	_play_battle_sfx(BATTLE_SFX_LEVEL_UP_PATH, BATTLE_SFX_LEVEL_UP_VOLUME_DB)


static func play_battle_faint() -> void:
	_play_battle_sfx(BATTLE_SFX_FAINT_PATH)


## Curación de PS en combate (barra HP / animación de heal).
static func play_battle_heal_hp_restore() -> void:
	_play_battle_sfx(BATTLE_SFX_HEAL_HP_RESTORE_PATH, BATTLE_SFX_HEAL_HP_RESTORE_VOLUME_DB)


static func play_pokemon_cry(pokemon: Pokemon) -> void:
	if instance == null or pokemon == null or pokemon.base == null:
		return
	_play_cry_at_path(pokemon.base.get_cry_path())


static func play_pokemon_cry_from_data(data: PokemonData) -> void:
	if instance == null or data == null:
		return
	_play_cry_at_path(data.get_cry_path())


static func _play_cry_at_path(path: String) -> void:
	if instance == null or path.is_empty():
		return
	var stream := instance._load_audio_stream(path)
	if stream != null:
		play_sfx(stream, BUS_SFX)


static func _play_ui_sfx(path: String) -> void:
	if instance == null:
		return
	var stream := instance._load_audio_stream(path)
	if stream != null:
		play_sfx(stream, BUS_UI)


static func _play_battle_sfx(path: String, volume_db: float = 0.0) -> void:
	if instance == null or path.is_empty():
		return
	var stream := instance._load_audio_stream(path)
	if stream != null:
		play_sfx(stream, BUS_SFX, volume_db)


func _play_battle_exp_gain() -> void:
	if _exp_gain_player == null:
		return
	var stream := _load_audio_stream(BATTLE_SFX_EXP_GAIN_PATH)
	if stream == null:
		return
	_exp_gain_player.stream = stream
	_exp_gain_player.volume_db = 0.0
	_exp_gain_player.play()


func _stop_battle_exp_gain() -> void:
	if _exp_gain_player != null and _exp_gain_player.playing:
		_exp_gain_player.stop()


# === BGM ===

func _play_battle_bgm(rules: BattleRules, enemy_participants: Array) -> void:
	_battle_victory_started = false
	_stop_me()
	var stream := _resolve_battle_bgm(rules, enemy_participants)
	if stream == null:
		push_warning("AudioManager: No hay BGM de batalla configurada para este combate")
		return
	_play_bgm(stream, 0.0, true)


func _play_battle_victory_bgm(rules: BattleRules, enemy_participants: Array) -> void:
	if _battle_victory_started:
		return
	_battle_victory_started = true
	_stop_me()
	var stream := _resolve_battle_victory_bgm(rules, enemy_participants)
	if stream == null:
		push_warning("AudioManager: No hay BGM de victoria configurada")
		return
	# Corte inmediato del tema de combate (como en los originales).
	_play_bgm(stream, 0.0, true)


func _play_battle_capture_success_me() -> void:
	var stream := _load_audio_stream(BATTLE_ME_CAPTURE_SUCCESS_PATH)
	if stream == null:
		# Sin ME: pasar directo a victoria salvaje.
		_play_battle_victory_bgm(null, [])
		return
	_stop_bgm(0.0)
	_stop_me()
	_me_finished_cb = Callable(self, "_on_capture_success_me_finished")
	if not _me_player.finished.is_connected(_on_me_player_finished):
		_me_player.finished.connect(_on_me_player_finished)
	_me_player.stream = _prepare_bgm_stream(stream, false)
	_me_player.volume_db = BGM_BUS_VOLUME_DB
	_me_player.play()


func _on_capture_success_me_finished() -> void:
	# Tras el jingle de captura: victoria salvaje (Gen 3/4).
	_play_battle_victory_bgm(null, [])


func _on_me_player_finished() -> void:
	var cb := _me_finished_cb
	_me_finished_cb = Callable()
	if cb.is_valid():
		cb.call()


func _stop_me() -> void:
	_me_finished_cb = Callable()
	if _me_player == null:
		return
	if _me_player.playing:
		_me_player.stop()


func _resolve_battle_bgm(rules: BattleRules, enemy_participants: Array) -> AudioStream:
	if rules != null and rules.type == BattleRules.BattleTypes.WILD:
		return _load_audio_stream(BATTLE_BGM_WILD_PATH)

	for participant in enemy_participants:
		if participant is BattleParticipant and TrainerClassEnum.is_gym_leader(participant.trainer_class_id):
			return _load_audio_stream(BATTLE_BGM_GYM_PATH)

	if rules != null and rules.type == BattleRules.BattleTypes.TRAINER:
		return _load_audio_stream(BATTLE_BGM_TRAINER_PATH)

	return _load_audio_stream(BATTLE_BGM_WILD_PATH)


func _resolve_battle_victory_bgm(rules: BattleRules, enemy_participants: Array) -> AudioStream:
	if rules != null and rules.type == BattleRules.BattleTypes.WILD:
		return _load_audio_stream(BATTLE_VICTORY_BGM_WILD_PATH)

	for participant in enemy_participants:
		if participant is BattleParticipant and TrainerClassEnum.is_gym_leader(participant.trainer_class_id):
			return _load_audio_stream(BATTLE_VICTORY_BGM_GYM_PATH)

	if rules != null and rules.type == BattleRules.BattleTypes.TRAINER:
		return _load_audio_stream(BATTLE_VICTORY_BGM_TRAINER_PATH)

	# Captura / fallback: victoria salvaje.
	return _load_audio_stream(BATTLE_VICTORY_BGM_WILD_PATH)


func _load_audio_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: No se pudo cargar audio: %s" % path)
	return stream


func _play_bgm(stream: AudioStream, fade_in: float, loop: bool) -> void:
	if stream == null:
		push_warning("AudioManager: play_bgm recibió stream nulo")
		return
	if _is_same_bgm(stream) and _active_bgm_player.playing:
		return

	_kill_bgm_tween()
	var prepared := _prepare_bgm_stream(stream, loop)
	_current_bgm_stream = stream

	_active_bgm_player.stop()
	_active_bgm_player.volume_db = BGM_BUS_VOLUME_DB

	_inactive_bgm_player.stop()
	_inactive_bgm_player.stream = prepared
	_inactive_bgm_player.volume_db = BGM_BUS_VOLUME_DB if fade_in <= 0.0 else SILENT_DB
	_inactive_bgm_player.play()

	_swap_bgm_players()

	if fade_in > 0.0:
		_bgm_tween = create_tween()
		_tween_player_volume(_active_bgm_player, BGM_BUS_VOLUME_DB, fade_in, _bgm_tween)
	else:
		_active_bgm_player.volume_db = BGM_BUS_VOLUME_DB


func _stop_bgm(fade_out: float) -> void:
	_stop_me()
	if not _active_bgm_player.playing and _current_bgm_stream == null:
		return

	_kill_bgm_tween()
	_current_bgm_stream = null

	if fade_out <= 0.0:
		_active_bgm_player.stop()
		_active_bgm_player.volume_db = BGM_BUS_VOLUME_DB
		_inactive_bgm_player.stop()
		_inactive_bgm_player.volume_db = BGM_BUS_VOLUME_DB
		return

	_bgm_tween = create_tween()
	_tween_player_volume(_active_bgm_player, SILENT_DB, fade_out, _bgm_tween)
	_bgm_tween.tween_callback(_on_bgm_fade_out_finished)


func _crossfade_bgm(stream: AudioStream, duration: float, loop: bool) -> void:
	if stream == null:
		push_warning("AudioManager: crossfade_bgm recibió stream nulo")
		return
	if _is_same_bgm(stream) and _active_bgm_player.playing:
		return

	_kill_bgm_tween()
	var prepared := _prepare_bgm_stream(stream, loop)
	_current_bgm_stream = stream

	_inactive_bgm_player.stop()
	_inactive_bgm_player.stream = prepared
	_inactive_bgm_player.volume_db = SILENT_DB
	_inactive_bgm_player.play()

	var fade_duration := maxf(duration, 0.0)
	if fade_duration <= 0.0:
		_active_bgm_player.stop()
		_active_bgm_player.volume_db = BGM_BUS_VOLUME_DB
		_inactive_bgm_player.volume_db = BGM_BUS_VOLUME_DB
		_swap_bgm_players()
		return

	_bgm_tween = create_tween().set_parallel(true)
	_tween_player_volume(_active_bgm_player, SILENT_DB, fade_duration, _bgm_tween)
	_tween_player_volume(_inactive_bgm_player, BGM_BUS_VOLUME_DB, fade_duration, _bgm_tween)
	_bgm_tween.chain().tween_callback(_on_crossfade_finished)


func _on_crossfade_finished() -> void:
	_active_bgm_player.stop()
	_active_bgm_player.volume_db = BGM_BUS_VOLUME_DB
	_swap_bgm_players()
	_bgm_tween = null


func _on_bgm_fade_out_finished() -> void:
	_active_bgm_player.stop()
	_active_bgm_player.volume_db = BGM_BUS_VOLUME_DB
	_inactive_bgm_player.stop()
	_inactive_bgm_player.volume_db = BGM_BUS_VOLUME_DB
	_bgm_tween = null


func _swap_bgm_players() -> void:
	var temp := _active_bgm_player
	_active_bgm_player = _inactive_bgm_player
	_inactive_bgm_player = temp


func _kill_bgm_tween() -> void:
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = null


func _tween_player_volume(
	player: AudioStreamPlayer,
	target_db: float,
	duration: float,
	tween: Tween
) -> void:
	var volume_tween := tween.tween_property(player, "volume_db", target_db, duration)
	volume_tween.set_trans(BGM_FADE_TRANS)
	volume_tween.set_ease(BGM_FADE_EASE)


func _is_bgm_playing() -> bool:
	if _current_bgm_stream == null:
		return false
	return _active_bgm_player.playing or _inactive_bgm_player.playing


func _is_battle_bgm_playing() -> bool:
	if not _is_bgm_playing() or _current_bgm_stream == null:
		return false
	var path := _current_bgm_stream.resource_path
	if path.is_empty():
		return false
	return path.contains("/Battle (") or path.contains("/Victory (")


func _is_same_bgm(stream: AudioStream) -> bool:
	if _current_bgm_stream == null:
		return false
	if stream == _current_bgm_stream:
		return true
	var new_path := stream.resource_path
	var current_path := _current_bgm_stream.resource_path
	return not new_path.is_empty() and new_path == current_path


func _prepare_bgm_stream(stream: AudioStream, loop: bool) -> AudioStream:
	if not loop:
		return stream
	# Loop / loop_offset vienen del import del .ogg (Inspector → Import).
	if stream is AudioStreamOggVorbis:
		if stream.loop:
			return stream
		var duplicated := stream.duplicate() as AudioStreamOggVorbis
		duplicated.loop = true
		duplicated.loop_offset = stream.loop_offset
		return duplicated
	if stream is AudioStreamMP3:
		if stream.loop:
			return stream
		var duplicated_mp3 := stream.duplicate() as AudioStreamMP3
		duplicated_mp3.loop = true
		duplicated_mp3.loop_offset = stream.loop_offset
		return duplicated_mp3
	if stream is AudioStreamWAV:
		var duplicated_wav := stream.duplicate() as AudioStreamWAV
		duplicated_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return duplicated_wav
	return stream


# === SFX ===

func _setup_sfx_pool() -> void:
	_sfx_players.clear()
	for child in _sfx_pool.get_children():
		if child is AudioStreamPlayer:
			var player := child as AudioStreamPlayer
			player.process_mode = Node.PROCESS_MODE_ALWAYS
			_sfx_players.append(player)


func _play_sfx(stream: AudioStream, bus: String, volume_db: float = 0.0) -> void:
	if stream == null:
		push_warning("AudioManager: play_sfx recibió stream nulo")
		return
	if _sfx_players.is_empty():
		push_warning("AudioManager: Pool de SFX vacío")
		return

	var resolved_bus := bus if AudioServer.get_bus_index(bus) >= 0 else BUS_SFX
	var player := _get_available_sfx_player()
	player.bus = resolved_bus
	player.volume_db = volume_db
	player.stream = stream
	player.play()


func _get_available_sfx_player() -> AudioStreamPlayer:
	for i in SFX_POOL_SIZE:
		var index := (_sfx_next_index + i) % _sfx_players.size()
		var candidate := _sfx_players[index]
		if not candidate.playing:
			_sfx_next_index = (index + 1) % _sfx_players.size()
			return candidate

	var fallback := _sfx_players[_sfx_next_index]
	_sfx_next_index = (_sfx_next_index + 1) % _sfx_players.size()
	return fallback
