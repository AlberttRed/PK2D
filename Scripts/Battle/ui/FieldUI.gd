extends Control

class_name FieldUI
	
func get_player_spots_for_mode(mode: int) -> Array[BattleSpot]:
	match mode:
		BattleRules.BattleModes.SINGLE:
			return [$PlayerBase/PokemonSpotA]
		BattleRules.BattleModes.DOUBLE:
			return [$PlayerBase/PokemonSpotA, $PlayerBase/PokemonSpotB]
	return []

func get_enemy_spots_for_mode(mode: int) -> Array[BattleSpot]:
	match mode:
		BattleRules.BattleModes.SINGLE:
			return [$EnemyBase/PokemonSpotA]
		BattleRules.BattleModes.DOUBLE:
			return [$EnemyBase/PokemonSpotA, $EnemyBase/PokemonSpotB]
	return []

func get_all_spots_for_mode(mode: int) -> Array[BattleSpot]:
	return get_player_spots_for_mode(mode) + get_enemy_spots_for_mode(mode)


func get_player_spot(index: int) -> BattleSpot:
	match index:
		0: return $PlayerBase/PokemonSpotA
		1: return $PlayerBase/PokemonSpotB
		_: return null
		
func get_enemy_spot(index: int) -> BattleSpot:
	match index:
		0: return $EnemyBase/PokemonSpotA
		1: return $EnemyBase/PokemonSpotB
		_: return null

func position_battlespots_for_mode(mode: int) -> void:
	var p_base = $PlayerBase
	var e_base = $EnemyBase

	match mode:
		BattleRules.BattleModes.SINGLE:
			# Player side
			$PlayerBase/PokemonSpotA.global_position = $PlayerBase/Positions/SpotA_Single.global_position
			$PlayerBase/PokemonSpotB.visible = false  # Solo se usa uno en modo SINGLE

			# Enemy side
			$EnemyBase/PokemonSpotA.global_position = $EnemyBase/Positions/SpotA_Single.global_position
			$EnemyBase/PokemonSpotB.visible = false

		BattleRules.BattleModes.DOUBLE:
			# Player side
			$PlayerBase/PokemonSpotA.global_position = $PlayerBase/Positions/SpotA_Double.global_position
			$PlayerBase/PokemonSpotB.global_position = $PlayerBase/Positions/SpotB_Double.global_position
			$PlayerBase/PokemonSpotB.visible = true

			# Enemy side
			$EnemyBase/PokemonSpotA.global_position = $EnemyBase/Positions/SpotA_Double.global_position
			$EnemyBase/PokemonSpotB.global_position = $EnemyBase/Positions/SpotB_Double.global_position
			$EnemyBase/PokemonSpotB.visible = true

		_:
			push_warning("Combate no compatible: usando modo SINGLE por defecto")
			$PlayerBase/PokemonSpotA.global_position = $PlayerBase/Positions/SpotA_Single.global_position
			$PlayerBase/PokemonSpotA.global_position = $EnemyBase/Positions/SpotA_Single.global_position

# Ordena el z_indez de cada BattleSpot para que se vean en el orden correcto en pantalla
func apply_z_order_for_mode(mode: int) -> void:
	match mode:
		BattleRules.BattleModes.SINGLE:
			# En combate individual, solo SpotA está activo y debe estar por encima
			$PlayerBase/PokemonSpotA.z_index = 1
			$PlayerBase/PokemonSpotB.z_index = 0
			$EnemyBase/PokemonSpotA.z_index = 1
			$EnemyBase/PokemonSpotB.z_index = 0

		BattleRules.BattleModes.DOUBLE:
			# En combate doble, en player el SpotA debe estar por detrás, y en enemy por delante (más "cerca" de cámara)
			$PlayerBase/PokemonSpotA.z_index = 1
			$PlayerBase/PokemonSpotB.z_index = 2
			$EnemyBase/PokemonSpotA.z_index = 2
			$EnemyBase/PokemonSpotB.z_index = 1

		_:
			push_warning("Modo de combate no soportado para orden de Z")
