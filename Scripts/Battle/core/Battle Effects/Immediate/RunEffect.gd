class_name RunEffect
extends ImmediateBattleEffect

var side: BattleSide
var can_escape: bool
var succeeded: bool = false

func _init(_side: BattleSide, _can_escape: bool):
    side = _side
    can_escape = _can_escape

func apply():
    if not can_escape:
        return
    
    # Calcular probabilidad de escape basada en velocidad
    succeeded = _calculate_escape_success()
    
    if succeeded:
        side.escapedBattle = true

func _calculate_escape_success() -> bool:
    # Fórmula simplificada basada en los juegos oficiales
    var user_speed = side.get_active_pokemons()[0].get_speed() if not side.get_active_pokemons().is_empty() else 100
    var opponent_speed = side.opponent_side.get_active_pokemons()[0].get_speed() if side.opponent_side and not side.opponent_side.get_active_pokemons().is_empty() else 100
    
    # Fórmula básica: si el usuario es más rápido, tiene 100% de éxito
    # Si es más lento, tiene una probabilidad basada en la diferencia de velocidad
    if user_speed >= opponent_speed:
        return true
    
    # Probabilidad basada en la diferencia de velocidad
    var speed_ratio = float(user_speed) / float(opponent_speed)
    var escape_chance = speed_ratio * 0.5 + 0.3  # Entre 30% y 80%
    
    return randf() < escape_chance

func visualize(ui):
    var who = side.to_string() if side else "(?)"
    var is_trainer_battle = not can_escape
    
    await ui.show_escape_message(who, is_trainer_battle, succeeded)

