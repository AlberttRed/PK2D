## Clase base para datos estáticos de items
## Representa los datos de catálogo de cada objeto del juego
## Similar a PokemonData y MoveData, contiene únicamente información estática
extends Resource
class_name ItemData

# ============================================================================
# AC-02: Identidad y datos básicos
# ============================================================================

## Identificador único del item
@export var id: int = 0

## Nombre interno (para referencias en código)
@export var internal_name: String = ""

## Nombre visible (para mostrar en UI)
@export var display_name: String = ""

## Descripción del item
@export_multiline var description: String = ""

## Icono del item (AtlasTexture)
@export var icon: AtlasTexture = null

# ============================================================================
# AC-03: Clasificación del item
# ============================================================================

## Bolsillo del Bag donde se almacena
## IMPORTANTE: El orden debe coincidir con ItemEnums.Pocket (ITEMS=1, MEDICINE=2, BALLS=3, etc.)
## @export_enum asigna valores 0,1,2,3... pero nuestro enum empieza en 1, así que añadimos un placeholder
@export_enum("None", "Items", "Medicine", "Balls", "TM/HM", "Berries", "Key Items", "Machines", "Battle Items") var pocket: int = ItemEnums.Pocket.ITEMS

## Tipo lógico del item
@export_enum("Generic", "Heal HP", "Heal PP", "Cure Status", "Revive", "Poké Ball", "TM/HM", "Held", "Key", "Evolution", "Stat Boost", "Repel", "Berry") var kind: int = ItemEnums.Kind.GENERIC

## ID de categoría de PokeAPI (`item-category/{id}`) para trazabilidad y mapeos automáticos.
@export_enum(
	"Unknown:0",
	"Stat Boosts:1",
	"Effort Drop:2",
	"Medicine:3",
	"Other:4",
	"In a Pinch:5",
	"Picky Healing:6",
	"Type Protection:7",
	"Baking Only:8",
	"Collectibles:9",
	"Evolution:10",
	"Spelunking:11",
	"Held Items:12",
	"Choice:13",
	"Effort Training:14",
	"Bad Held Items:15",
	"Training:16",
	"Plates:17",
	"Species Specific:18",
	"Type Enhancement:19",
	"Event Items:20",
	"Gameplay:21",
	"Plot Advancement:22",
	"Unused:23",
	"Loot:24",
	"All Mail:25",
	"Vitamins:26",
	"Healing:27",
	"PP Recovery:28",
	"Status Cures:29",
	"Revival:30",
	"Mulch:31",
	"Special Balls:32",
	"Standard Balls:33",
	"Dex Completion:34",
	"Scarves:35",
	"All Machines:36",
	"Flutes:37",
	"Apricorn Balls:38",
	"Apricorn Box:39",
	"Data Cards:40",
	"Jewels:41",
	"Miracle Shooter:42",
	"Mega Stones:43",
	"Memories:44"
) var item_category_id: int = 0

## Categoría de batalla que resuelve qué `BattleItemHandler` usar para este ítem.
@export var category: Resource = null

# ============================================================================
# AC-04: Reglas de uso por contexto
# ============================================================================

## Contextos donde puede usarse el item (bitwise: OVERWORLD | PARTY_MENU | BATTLE)
## Por defecto: solo overworld
## Nota: Usa flags para poder combinar contextos (ej: OVERWORLD | PARTY_MENU)
@export_flags("Overworld", "Party Menu", "Battle") var allowed_contexts: int = ItemEnums.UseContext.OVERWORLD

## Tipo de objetivo requerido
@export_enum("None", "Pokémon", "Party Slot", "Move Slot", "Party") var target_type: int = ItemEnums.TargetType.NONE

## Si el item es consumible (se consume al usarse)
@export var is_consumable: bool = true

## Límite de stack (cantidad máxima que se puede apilar)
## 0 o negativo = sin límite, 1 = key item (no apilable)
@export var stack_limit: int = 99

# ============================================================================
# AC-05: Hook a lógica de efecto
# ============================================================================

## Referencia al efecto que ejecuta la lógica del item
## La ejecución real se delega a este objeto
@export var effect: ItemEffect = null

# ============================================================================
# Métodos helper
# ============================================================================

## Verifica si el item puede usarse en un contexto dado
func can_use_in_context(context: ItemEnums.UseContext) -> bool:
	return ItemEnums.has_context(allowed_contexts, context)

## Verifica si requiere un objetivo específico
func requires_target() -> bool:
	return target_type != ItemEnums.TargetType.NONE

## Verifica si es un key item (no consumible y stack_limit = 1)
func is_key_item() -> bool:
	return stack_limit == 1 and not is_consumable

## Obtiene el nombre para mostrar (fallback a display_name o internal_name)
func get_display_name() -> String:
	if display_name != "":
		return display_name
	if internal_name != "":
		return internal_name.capitalize()
	return "Item #%d" % id

## Imprime información del item (útil para debugging)
func print_info() -> void:
	var title := "%s (ID %d)" % [get_display_name(), id]
	var contexts_str := ""
	if can_use_in_context(ItemEnums.UseContext.OVERWORLD):
		contexts_str += "OVERWORLD "
	if can_use_in_context(ItemEnums.UseContext.PARTY_MENU):
		contexts_str += "PARTY_MENU "
	if can_use_in_context(ItemEnums.UseContext.BATTLE):
		contexts_str += "BATTLE "

	print("[Item] %s | Pocket: %d | Kind: %d | Contexts: [%s] | Consumible: %s" % [
		title,
		pocket,
		kind,
		contexts_str.strip_edges(),
		is_consumable
	])
