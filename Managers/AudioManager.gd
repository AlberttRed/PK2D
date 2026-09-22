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
const ME_OBTAIN_ITEM_PATH := "res://Audio/ME/Obtained an Item.ogg"
const ME_OBTAIN_KEY_ITEM_PATH := "res://Audio/ME/Obtained a Key Item.ogg"

const UI_SFX_CURSOR_PATH := "res://Audio/SE/GUI sel cursor.ogg"
const UI_SFX_MENU_OPEN_PATH := "res://Audio/SE/GUI menu open.ogg"
const UI_SFX_POKEDEX_OPEN_PATH := "res://Audio/SE/GUI pokedex open.ogg"
const UI_SFX_SUMMARY_CHANGE_PAGE_PATH := "res://Audio/SE/GUI summary change page.ogg"
const UI_SFX_USE_ITEM_IN_PARTY_PATH := "res://Audio/SE/Use item in party.ogg"
const UI_SFX_PC_ACCESS_PATH := "res://Audio/SE/PC access.ogg"
const UI_SFX_PC_CLOSE_PATH := "res://Audio/SE/PC close.ogg"
const UI_SFX_MART_REGISTER_PATH := "res://Audio/SE/register_noise.ogg"
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

## Overworld (#821): ledge, bump, MOs. Surf BGM/SFX opcionales hasta que existan los assets.
const OVERWORLD_SFX_PLAYER_JUMP_PATH := "res://Audio/SE/Player jump.ogg"
const OVERWORLD_SFX_PLAYER_BUMP_PATH := "res://Audio/SE/Player bump.ogg"
const OVERWORLD_SFX_CUT_PATH := "res://Audio/SE/Cut.ogg"
const OVERWORLD_SFX_STRENGTH_PUSH_PATH := "res://Audio/SE/Strength push.ogg"
const OVERWORLD_SFX_ROCK_SMASH_PATH := "res://Audio/SE/Rock Smash.ogg"
const OVERWORLD_SFX_SURF_PATH := "res://Audio/SE/Surf.ogg"
const OVERWORLD_SFX_EXCLAIM_PATH := "res://Audio/SE/Exclaim.ogg"
const OVERWORLD_BGM_SURFING_PATH := "res://Audio/BGM/Surfing.ogg"
const OVERWORLD_BGM_SURFING_FADE := 0.5
const EYES_MEET_BGM_BOY_PATH := "res://Audio/BGM/Trainers' Eyes Meet (Boy).ogg"
const EYES_MEET_BGM_GIRL_PATH := "res://Audio/BGM/Trainers' Eyes Meet (Girl).ogg"
const EYES_MEET_BGM_ROCKET_PATH := "res://Audio/BGM/Trainers' Eyes Meet (Team Rocket).ogg"
const EYES_MEET_BGM_FADE := 0.25

@onready var _bgm_player_a: AudioStreamPlayer = $BGMPlayerA
@onready var _bgm_player_b: AudioStreamPlayer = $BGMPlayerB
@onready var _sfx_pool: Node = $SFXPool
@onready var _exp_gain_player: AudioStreamPlayer = $ExpGainPlayer
@onready var _me_player: AudioStreamPlayer = $MEPlayer

var _active_bgm_player: AudioStreamPlayer
var _inactive_bgm_player: AudioStreamPlayer
var _current_bgm_stream: AudioStream = null
var _bgm_tween: Tween = null
## Stream pendiente tras un fade-out secuencial (estilo Gen 3: fade out → play hard).
var _pending_bgm_stream: AudioStream = null
var _pending_bgm_loop: bool = true
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next_index: int = 0
## Evita reiniciar la fanfare de victoria varias veces en el mismo combate.
var _battle_victory_started: bool = false
var _me_finished_cb: Callable = Callable()
## Hold de BGM de evento: sobrevive warps y se restaura tras combate hasta StopBGM.
var _event_bgm_held: bool = false
var _held_event_bgm: AudioStream = null
var _held_event_bgm_loop: bool = true
## Refcount: BGM en pausa mientras suena un ME/SFX de jingle (PlaySound, obtain item…).
var _jingle_pause_refcount: int = 0
var _me_holds_jingle_pause: bool = false


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


## Estilo Gen 3: la BGM actual hace fade-out; la nueva entra a volumen pleno al terminar.
static func fade_out_then_play_bgm(stream: AudioStream, fade_out: float = 1.0, loop: bool = true) -> void:
	if instance == null:
		push_error("AudioManager: No hay instancia disponible")
		return
	instance._fade_out_then_play_bgm(stream, fade_out, loop)


## Reproduce un SFX en el pool. Devuelve el player usado (o null) para poder esperar a `finished`.
## Si pause_bgm=true, pausa la BGM y la reanuda al terminar el SFX (p. ej. PlaySoundCommand).
static func play_sfx(stream: AudioStream, bus: String = BUS_SFX, volume_db: float = 0.0, pause_bgm: bool = false) -> AudioStreamPlayer:
	if instance == null:
		push_error("AudioManager: No hay instancia disponible")
		return null
	return instance._play_sfx(stream, bus, volume_db, pause_bgm)


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


## ME genérico (no corta la BGM). Fire-and-forget.
static func play_me(stream: AudioStream) -> void:
	if instance == null:
		push_error("AudioManager: No hay instancia disponible")
		return
	instance._play_me(stream)


## Fanfare al obtener ítem (Gen 3): key item vs resto.
static func play_obtain_item_me(is_key_item: bool = false) -> void:
	if instance == null:
		push_error("AudioManager: No hay instancia disponible")
		return
	var path := ME_OBTAIN_KEY_ITEM_PATH if is_key_item else ME_OBTAIN_ITEM_PATH
	var stream := instance._load_audio_stream(path)
	if stream == null:
		return
	instance._play_me(stream)


static func is_bgm_playing() -> bool:
	if instance == null:
		return false
	return instance._is_bgm_playing()


## Activa el hold de BGM de evento (PlayBGM con persist_across_maps).
static func set_event_bgm_hold(stream: AudioStream, loop: bool = true) -> void:
	if instance == null:
		push_error("AudioManager: No hay instancia disponible")
		return
	if stream == null:
		push_warning("AudioManager: set_event_bgm_hold recibió stream nulo")
		return
	instance._event_bgm_held = true
	instance._held_event_bgm = stream
	instance._held_event_bgm_loop = loop


## Libera el hold (StopBGM / PlayBGM sin persist).
static func clear_event_bgm_hold() -> void:
	if instance == null:
		return
	instance._event_bgm_held = false
	instance._held_event_bgm = null
	instance._held_event_bgm_loop = true


static func is_event_bgm_held() -> bool:
	if instance == null:
		return false
	return instance._event_bgm_held and instance._held_event_bgm != null


## Reponer BGM del hold (p. ej. post-combate). No-op si ya suena el mismo stream.
static func resume_held_event_bgm(fade_in: float = 0.0) -> void:
	if instance == null:
		push_error("AudioManager: No hay instancia disponible")
		return
	if not is_event_bgm_held():
		return
	instance._play_bgm(instance._held_event_bgm, fade_in, instance._held_event_bgm_loop)


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


## Acceso al sistema de almacenamiento (menú PC de BILL → cajas).
static func play_ui_pc_access() -> void:
	_play_ui_sfx(UI_SFX_PC_ACCESS_PATH)


## Cierre del almacenamiento (máscara computer al salir del PC).
static func play_ui_pc_close() -> void:
	_play_ui_sfx(UI_SFX_PC_CLOSE_PATH)


## Caja registradora FRLG (compra/venta en tienda).
static func play_ui_mart_register() -> void:
	_play_ui_sfx(UI_SFX_MART_REGISTER_PATH)


## Salto de ledge / hop genérico de overworld.
static func play_overworld_player_jump() -> void:
	_play_overworld_sfx(OVERWORLD_SFX_PLAYER_JUMP_PATH)


## Choque contra pared / obstáculo (bump).
static func play_overworld_player_bump() -> void:
	_play_overworld_sfx(OVERWORLD_SFX_PLAYER_BUMP_PATH)


static func play_overworld_cut() -> void:
	_play_overworld_sfx(OVERWORLD_SFX_CUT_PATH)


static func play_overworld_strength_push() -> void:
	_play_overworld_sfx(OVERWORLD_SFX_STRENGTH_PUSH_PATH)


static func play_overworld_rock_smash() -> void:
	_play_overworld_sfx(OVERWORLD_SFX_ROCK_SMASH_PATH)


## Splash al entrar/salir del agua (opcional: no avisa si falta el archivo).
static func play_overworld_surf() -> void:
	_play_overworld_sfx(OVERWORLD_SFX_SURF_PATH, false)


## Exclamación al detectar un entrenador (!).
static func play_overworld_exclaim() -> void:
	_play_overworld_sfx(OVERWORLD_SFX_EXCLAIM_PATH)


## BGM de Surf. No hace nada si aún no está el asset en Audio/BGM/Surfing.ogg.
static func play_surfing_bgm(fade: float = OVERWORLD_BGM_SURFING_FADE) -> void:
	if instance == null:
		return
	if not ResourceLoader.exists(OVERWORLD_BGM_SURFING_PATH):
		return
	var stream := instance._load_audio_stream(OVERWORLD_BGM_SURFING_PATH)
	if stream == null:
		return
	if fade <= 0.0 or not is_bgm_playing():
		play_bgm(stream, 0.0)
	else:
		fade_out_then_play_bgm(stream, fade)


## BGM desde la exclamación del entrenador hasta el combate.
static func play_eyes_meet_bgm(theme: TrainerEyesMeetEnum.Values, fade: float = EYES_MEET_BGM_FADE) -> void:
	if instance == null:
		return
	var path := _eyes_meet_path(theme)
	if path.is_empty():
		return
	var stream := instance._load_audio_stream(path)
	if stream == null:
		return
	if fade <= 0.0 or not is_bgm_playing():
		play_bgm(stream, 0.0)
	else:
		fade_out_then_play_bgm(stream, fade)


static func _eyes_meet_path(theme: TrainerEyesMeetEnum.Values) -> String:
	match theme:
		TrainerEyesMeetEnum.Values.BOY:
			return EYES_MEET_BGM_BOY_PATH
		TrainerEyesMeetEnum.Values.GIRL:
			return EYES_MEET_BGM_GIRL_PATH
		TrainerEyesMeetEnum.Values.TEAM_ROCKET:
			return EYES_MEET_BGM_ROCKET_PATH
		_:
			return ""


static func _play_overworld_sfx(path: String, warn_if_missing: bool = true) -> void:
	if instance == null or path.is_empty():
		return
	if not ResourceLoader.exists(path):
		if warn_if_missing:
			push_warning("AudioManager: Falta SFX overworld: %s" % path)
		return
	var stream := instance._load_audio_stream(path)
	if stream != null:
		play_sfx(stream, BUS_SFX)


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


## ME overworld / UI: pausa la BGM y la reanuda al terminar.
func _play_me(stream: AudioStream) -> void:
	if stream == null:
		push_warning("AudioManager: play_me recibió stream nulo")
		return
	_stop_me()
	_acquire_jingle_pause()
	_me_holds_jingle_pause = true
	if not _me_player.finished.is_connected(_on_me_player_finished):
		_me_player.finished.connect(_on_me_player_finished)
	_me_player.stream = _prepare_bgm_stream(stream, false)
	_me_player.volume_db = BGM_BUS_VOLUME_DB
	_me_player.play()


func _on_capture_success_me_finished() -> void:
	# Tras el jingle de captura: victoria salvaje (Gen 3/4).
	_play_battle_victory_bgm(null, [])


func _on_me_player_finished() -> void:
	_release_me_jingle_pause()
	var cb := _me_finished_cb
	_me_finished_cb = Callable()
	if cb.is_valid():
		cb.call()


func _stop_me() -> void:
	_me_finished_cb = Callable()
	_release_me_jingle_pause()
	if _me_player == null:
		return
	if _me_player.playing:
		_me_player.stop()


func _release_me_jingle_pause() -> void:
	if not _me_holds_jingle_pause:
		return
	_me_holds_jingle_pause = false
	_release_jingle_pause()


func _acquire_jingle_pause() -> void:
	if _jingle_pause_refcount == 0:
		_set_bgm_stream_paused(true)
	_jingle_pause_refcount += 1


func _release_jingle_pause() -> void:
	if _jingle_pause_refcount <= 0:
		return
	_jingle_pause_refcount -= 1
	if _jingle_pause_refcount == 0:
		_set_bgm_stream_paused(false)


func _clear_jingle_pause() -> void:
	_jingle_pause_refcount = 0
	_me_holds_jingle_pause = false
	_set_bgm_stream_paused(false)


func _set_bgm_stream_paused(paused: bool) -> void:
	for player in [_active_bgm_player, _inactive_bgm_player]:
		if player == null:
			continue
		if paused:
			if player.playing:
				player.stream_paused = true
		else:
			player.stream_paused = false


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

	_pending_bgm_stream = null
	_kill_bgm_tween()
	_clear_jingle_pause()
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
	_pending_bgm_stream = null
	_clear_jingle_pause()
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


## Fade-out de la actual; al terminar arranca la nueva sin fade-in (Gen 3 / mapas).
func _fade_out_then_play_bgm(stream: AudioStream, fade_out: float, loop: bool) -> void:
	if stream == null:
		push_warning("AudioManager: fade_out_then_play_bgm recibió stream nulo")
		return
	if _is_same_bgm(stream) and _active_bgm_player.playing:
		return

	_kill_bgm_tween()
	_pending_bgm_stream = stream
	_pending_bgm_loop = loop

	var duration := maxf(fade_out, 0.0)
	if duration <= 0.0 or not _active_bgm_player.playing:
		_pending_bgm_stream = null
		_play_bgm(stream, 0.0, loop)
		return

	_bgm_tween = create_tween()
	_tween_player_volume(_active_bgm_player, SILENT_DB, duration, _bgm_tween)
	_bgm_tween.tween_callback(_on_fade_out_then_play_finished)


func _on_fade_out_then_play_finished() -> void:
	_active_bgm_player.stop()
	_active_bgm_player.volume_db = BGM_BUS_VOLUME_DB
	_inactive_bgm_player.stop()
	_inactive_bgm_player.volume_db = BGM_BUS_VOLUME_DB
	_bgm_tween = null

	var next_stream := _pending_bgm_stream
	var next_loop := _pending_bgm_loop
	_pending_bgm_stream = null
	_current_bgm_stream = null

	if next_stream != null:
		_play_bgm(next_stream, 0.0, next_loop)


func _crossfade_bgm(stream: AudioStream, duration: float, loop: bool) -> void:
	if stream == null:
		push_warning("AudioManager: crossfade_bgm recibió stream nulo")
		return
	if _is_same_bgm(stream) and _active_bgm_player.playing:
		return

	_pending_bgm_stream = null
	_kill_bgm_tween()
	_clear_jingle_pause()
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


func _play_sfx(stream: AudioStream, bus: String, volume_db: float = 0.0, pause_bgm: bool = false) -> AudioStreamPlayer:
	if stream == null:
		push_warning("AudioManager: play_sfx recibió stream nulo")
		return null
	if _sfx_players.is_empty():
		push_warning("AudioManager: Pool de SFX vacío")
		return null

	var resolved_bus := bus if AudioServer.get_bus_index(bus) >= 0 else BUS_SFX
	var player := _get_available_sfx_player()
	_release_sfx_jingle_pause_if_held(player)
	player.bus = resolved_bus
	player.volume_db = volume_db
	player.stream = stream
	if pause_bgm:
		_acquire_jingle_pause()
		player.set_meta("pauses_bgm", true)
		player.finished.connect(_on_sfx_jingle_finished.bind(player), CONNECT_ONE_SHOT)
	player.play()
	return player


func _on_sfx_jingle_finished(player: AudioStreamPlayer) -> void:
	_release_sfx_jingle_pause_if_held(player)


func _release_sfx_jingle_pause_if_held(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if not player.has_meta("pauses_bgm") or not bool(player.get_meta("pauses_bgm")):
		return
	player.set_meta("pauses_bgm", false)
	_release_jingle_pause()


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
