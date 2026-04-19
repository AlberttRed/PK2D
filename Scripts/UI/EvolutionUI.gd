extends Panel

class_name EvolutionUI

@onready var pokemon_sprite: Sprite2D = $PokemonSprite


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## Secuencia bloqueante: mensajes vía MessageBox global + animación mínima; no modifica el Pokémon (lo hace EvolutionController después).
func play_evolution_sequence(pokemon: Pokemon, target_data: PokemonData) -> void:
	visible = true
	var name_a: String = pokemon.get_display_name()
	_set_sprite_from_pokemon(pokemon)

	await DisplayManager.show_message("¿Qué? ¡%s está evolucionando!" % name_a, {
		"typingMode": MessageBox.TypingMode.INSTANT,
	})

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(pokemon_sprite, "scale", Vector2(1.12, 1.12), 0.35)
	tw.tween_property(pokemon_sprite, "modulate", Color(1.25, 1.25, 0.95, 1.0), 0.35)
	await tw.finished
	await get_tree().create_timer(0.15).timeout

	if target_data.battle_front_sprite != null:
		pokemon_sprite.texture = target_data.battle_front_sprite
	pokemon_sprite.scale = Vector2.ONE
	pokemon_sprite.modulate = Color.WHITE

	await DisplayManager.show_message(
		"¡Enhorabuena! ¡%s evolucionó a %s!" % [name_a, target_data.Name],
		{"typingMode": MessageBox.TypingMode.INSTANT},
	)

	visible = false


func _set_sprite_from_pokemon(pokemon: Pokemon) -> void:
	var t: Texture2D = pokemon.get_battle_front_sprite()
	if t != null:
		pokemon_sprite.texture = t
