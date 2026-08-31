extends SceneTree

## Headless: godot --headless --path . --script res://Scripts/Tools/run_import_battler_metrics.gd

const POKEMON_DIR := "res://Resources/Data/Pokemon"
const POKEMON_TXT_PATH := "/home/kerrmind/Godot/Docs Projecte/pokemon.txt"
const METRICS_TXT_PATH := "/home/kerrmind/Godot/Docs Projecte/pokemon_metrics.txt"
const START_ID: int = 1
const END_ID: int = 151


func _initialize() -> void:
	var summary := ImportPokemonBattlerMetricsCore.run(
		POKEMON_TXT_PATH,
		METRICS_TXT_PATH,
		POKEMON_DIR,
		START_ID,
		END_ID,
		false
	)
	print(summary.format_report())
	quit(0 if summary.errors == 0 else 1)
