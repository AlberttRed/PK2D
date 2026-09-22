@tool
extends EditorScript

## AB#832 — Rellena buy_price / sell_price de ítems típicos de mart (precios Gen 3 / FRLG).
## Convención: sell_price = buy_price / 2 (truncado). sell_price 0 = no vendible.
## Ejecutar: Editor → File → Run (con este script abierto).

const ITEMS_DIR := "res://Resources/Data/Items/"

## file_name → buy_price (sell = buy / 2)
const MART_BUY_PRICES := {
	"004 - Poké Ball.tres": 200,
	"003 - Super Ball.tres": 600,
	"002 - Ultra Ball.tres": 1200,
	"017 - Poción.tres": 300,
	"026 - Superpoción.tres": 700,
	"025 - Hiperpoción.tres": 1200,
	"024 - Poción Máxima.tres": 2500,
	"023 - Restaurar Todo.tres": 3000,
	"018 - Antídoto.tres": 100,
	"019 - Antiquemar.tres": 250,
	"020 - Antihielo.tres": 250,
	"021 - Despertar.tres": 250,
	"022 - Antiparalizador.tres": 200,
	"027 - Cura Total.tres": 600,
	"028 - Revivir.tres": 1500,
	"078 - Cuerda Huida.tres": 550,
	"079 - Repelente.tres": 350,
	"076 - Superrepelente.tres": 500,
	"077 - Repelente Máximo.tres": 700,
	"030 - Agua Fresca.tres": 200,
	"031 - Refresco.tres": 300,
	"032 - Limonada.tres": 350,
	"033 - Leche Mu-mu.tres": 500,
}


func _run() -> void:
	var updated := 0
	for file_name in MART_BUY_PRICES.keys():
		var buy: int = int(MART_BUY_PRICES[file_name])
		var sell: int = buy / 2
		updated += _patch_prices(str(file_name), buy, sell)
	print("[patch_item_mart_prices] Ítems actualizados: %d / %d" % [updated, MART_BUY_PRICES.size()])


func _patch_prices(file_name: String, buy: int, sell: int) -> int:
	var path := ITEMS_DIR + file_name
	var item_res: Resource = ResourceLoader.load(path)
	if item_res == null:
		push_warning("[patch_item_mart_prices] No se pudo cargar: %s" % path)
		return 0
	item_res.set("buy_price", buy)
	item_res.set("sell_price", sell)
	var err := ResourceSaver.save(item_res, path)
	if err != OK:
		push_warning("[patch_item_mart_prices] Error guardando %s (%d)" % [path, err])
		return 0
	return 1
