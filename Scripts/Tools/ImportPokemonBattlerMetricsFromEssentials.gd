@tool
extends EditorScript

## Importa en PokemonData (Gen 1):
## - `battlerAltitude` desde BES `pokemon.txt` (`BattlerAltitude` ×2, como Essentials)
## - `shadow_size` / `shadow_x` desde v21 `pokemon_metrics.txt`
##
## No importa FrontSprite, BackSprite, BattlerPlayerY ni BattlerEnemyY.
##
## Ejecución: abrir script -> Archivo -> Ejecutar.
## O headless: godot --headless --path . --script res://Scripts/Tools/run_import_battler_metrics.gd

const POKEMON_DIR := "res://Resources/Data/Pokemon"
const POKEMON_TXT_PATH := "/home/kerrmind/Godot/Docs Projecte/pokemon.txt"
const METRICS_TXT_PATH := "/home/kerrmind/Godot/Docs Projecte/pokemon_metrics.txt"
const START_ID: int = 1
const END_ID: int = 151
const DRY_RUN: bool = false

const SPECIAL_INTERNAL_TO_PBS := {
	"nidoran-f": "NIDORANfE",
	"nidoran-m": "NIDORANmA",
	"farfetchd": "FARFETCHD",
	"mr-mime": "MRMIME",
}


func _run() -> void:
	var summary := ImportPokemonBattlerMetricsCore.run(
		POKEMON_TXT_PATH,
		METRICS_TXT_PATH,
		POKEMON_DIR,
		START_ID,
		END_ID,
		DRY_RUN
	)
	print(summary.format_report())
	EditorInterface.get_resource_filesystem().scan()
