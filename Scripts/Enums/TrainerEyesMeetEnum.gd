## Tema BGM "Trainers' Eyes Meet" (exclamación → combate).
class_name TrainerEyesMeetEnum

enum Values {
	INHERIT, ## Usar default de la clase (o fallback por TrainerClassEnum).
	BOY,
	GIRL,
	TEAM_ROCKET,
	NONE, ## Sin Eyes Meet (p. ej. líderes / rival por evento).
}


## Fallback por clase cuando TrainerClassData no define eyes_meet (o es INHERIT).
static func from_trainer_class(class_id: int) -> Values:
	match class_id:
		TrainerClassEnum.Values.LASS, \
		TrainerClassEnum.Values.LADY, \
		TrainerClassEnum.Values.BEAUTY, \
		TrainerClassEnum.Values.PICNICKER, \
		TrainerClassEnum.Values.SWIMMER_F, \
		TrainerClassEnum.Values.TWINS, \
		TrainerClassEnum.Values.COOLTRAINER_F, \
		TrainerClassEnum.Values.ACE_TRAINER_F, \
		TrainerClassEnum.Values.POKEFAN_F, \
		TrainerClassEnum.Values.PSYCHIC_F, \
		TrainerClassEnum.Values.HEX_MANIAC, \
		TrainerClassEnum.Values.CHANNELER, \
		TrainerClassEnum.Values.MEDIUM, \
		TrainerClassEnum.Values.BATTLE_GIRL, \
		TrainerClassEnum.Values.AROMA_LADY, \
		TrainerClassEnum.Values.ROCKET_GRUNT_F:
			return Values.GIRL
		TrainerClassEnum.Values.ROCKET_GRUNT_M, \
		TrainerClassEnum.Values.TEAM_ROCKET_BOSS:
			return Values.TEAM_ROCKET
		TrainerClassEnum.Values.GYM_LEADER_BROCK, \
		TrainerClassEnum.Values.GYM_LEADER_MISTY, \
		TrainerClassEnum.Values.GYM_LEADER_LT_SURGE, \
		TrainerClassEnum.Values.GYM_LEADER_ERIKA, \
		TrainerClassEnum.Values.GYM_LEADER_KOGA, \
		TrainerClassEnum.Values.GYM_LEADER_SABRINA, \
		TrainerClassEnum.Values.GYM_LEADER_BLAINE, \
		TrainerClassEnum.Values.GYM_LEADER_GIOVANNI, \
		TrainerClassEnum.Values.ELITE_FOUR_LORELEI, \
		TrainerClassEnum.Values.ELITE_FOUR_BRUNO, \
		TrainerClassEnum.Values.ELITE_FOUR_AGATHA, \
		TrainerClassEnum.Values.ELITE_FOUR_LANCE, \
		TrainerClassEnum.Values.CHAMPION_BLUE, \
		TrainerClassEnum.Values.RIVAL:
			return Values.NONE
		_:
			return Values.BOY
