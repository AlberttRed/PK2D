class_name BattleBagChoice
extends BattleChoice

# Identificador del objeto a usar (`DatabaseService`).
var item_id: int = -1

## Inyectado desde `BattleUI` al elegir MOCHILA (necesario para `ItemUseContext` / handlers).
var battle_controller: BattleController = null

## Índice en `player_side.pokemonParty` del Pokémon sobre el que aplica el ítem (-1 = convención por defecto, el que declaró la acción).
var target_party_slot: int = -1

## Objetivo enemigo en runtime (p. ej. Poké Ball); opcional.
var enemy_target_battle_pokemon: BattlePokemon = null


## Pokémon al que aplica el efecto en combate (aliado u oponente según el ítem).
func resolve_item_target_battle_pokemon() -> BattlePokemon:
	if enemy_target_battle_pokemon != null:
		return enemy_target_battle_pokemon
	if battle_controller == null:
		return pokemon
	if target_party_slot >= 0:
		# `target_party_slot` viene del PartyUI global (overworld ordering).
		# En combate, `player_side.pokemonParty` puede no coincidir 1:1 por índice.
		var player_party: Array = GameStateService.get_player_party()
		if target_party_slot < player_party.size():
			var selected_base: Pokemon = player_party[target_party_slot] as Pokemon
			if selected_base != null and battle_controller.player_side != null:
				for bp: BattlePokemon in battle_controller.player_side.pokemonParty:
					if bp != null and bp.base_data == selected_base:
						return bp
		var battle_party: Array = battle_controller.player_side.pokemonParty
		if target_party_slot < battle_party.size():
			return battle_party[target_party_slot] as BattlePokemon
	return pokemon

func get_priority() -> int:
	# En juegos oficiales, usar objeto suele resolverse antes que los movimientos
	return 6

func is_blocking_action() -> bool:
	# Por defecto, usar objetos NO bloquea (pociones, bayas, etc.)
	# TODO: Poké Balls → true (bloquean secuencia de turno).
	return false

func resolve() -> Array[BattleHandler]:
	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	var handler: BattleHandler = BattleUnsupportedItemHandler.new(self, item_data)
	if item_data != null and item_data.category != null and item_data.category.has_method("create_handler"):
		handler = item_data.category.create_handler(self, item_data)
	return [handler]

