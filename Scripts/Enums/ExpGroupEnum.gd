class_name ExpGroupEnum

## Grupos de crecimiento / curvas de experiencia. Valores 1–6 = `PokemonData.growth_rate_id`.
enum Values {
	SLOW = 1,
	MEDIUM,
	FAST,
	MEDIUM_SLOW,
	ERRATIC,
	FLUCTUATING,
}


static func from_growth_rate_id(raw: int) -> Values:
	if raw < int(Values.SLOW) or raw > int(Values.FLUCTUATING):
		return Values.MEDIUM
	return raw as Values
