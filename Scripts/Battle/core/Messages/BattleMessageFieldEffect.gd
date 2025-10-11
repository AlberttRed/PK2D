class_name BattleMessageFieldEffect
extends RefCounted


func get_start_field_effect_message(effect_id: int, side: BattleSide = null) -> Dictionary:
    var side_name := "de alguien"
    if side != null:
        side_name = "de tu equipo" if side.type == BattleSide.Types.PLAYER else "del equipo rival"
    var msg:String = ""
    match effect_id:
        MovesEnum.Values.REFLECT:
            msg = "¡Reflejo subió la %s %s!" % [StatsEnum.get_display_name(StatsEnum.Values.DEFENSE), side_name] #Validado HGSS
        MovesEnum.Values.LIGHT_SCREEN:
            msg = "¡Pantalla de Luz subió la %s %s!" % [StatsEnum.get_display_name(StatsEnum.Values.SP_DEFENSE), side_name]
        MovesEnum.Values.SAFEGUARD:
            msg = "¡Velo Sagrado protege %s!" % side_name
        MovesEnum.Values.MIST:
            msg = "¡Neblina protege a los Pokémon de %s!" % side_name
        # MovesEnum.Values.AURORA_VEIL:  # No existe en MovesEnum actual
        #     msg = "¡Velo Aurora protege %s!" % side_name
        MovesEnum.Values.TAILWIND:
            msg = "¡Viento Afín sopla a favor de %s!" % side_name
        MovesEnum.Values.SPIKES:
            msg = "¡Púas fueron esparcidas en %s!" % side_name
        MovesEnum.Values.STEALTH_ROCK:
            msg = "¡Trampa Rocas rodea %s!" % side_name
        MovesEnum.Values.STICKY_WEB:
            msg = "¡Red Viscosa se extendió en %s!" % side_name
        _:
            push_warning("Invalid FieldEffect on get_start_field_effect_message()")
            return {}
    
    return { "type": "wait", "text": msg, "wait_time": 1.2 }


func get_end_field_effect_message(effect_id: int, side: BattleSide = null) -> Dictionary:
    var side_name := "tu equipo"
    if side != null:
        side_name = "tu equipo" if side.type == BattleSide.Types.PLAYER else "el equipo rival"
    var msg:String = ""
    match effect_id:
        MovesEnum.Values.REFLECT:
            msg = "¡Reflejo no funciona en %s!" % side_name #Validado HGSS
        MovesEnum.Values.LIGHT_SCREEN:
            msg = "¡Pantalla de Luz no funciona en %s!" % side_name
        MovesEnum.Values.SAFEGUARD:
            msg = "¡Velo Sagrado no funciona en %s!" % side_name
        MovesEnum.Values.MIST:
            msg = "¡La neblina en %s se disipó!" % side_name
        #MovesEnum.Values.AURORA_VEIL:  # No existe en MovesEnum actual
        #     msg = "¡Velo Aurora en %s desapareció!" % side_name
        MovesEnum.Values.TAILWIND:
            msg = "¡Viento Afín de %s amainó!" % side_name
        MovesEnum.Values.SPIKES:
            msg = "¡Las Púas en %s han sido removidas!" % side_name
        MovesEnum.Values.STEALTH_ROCK:
            msg = "¡Trampa Rocas en %s se desactivó!" % side_name
        MovesEnum.Values.STICKY_WEB:
            msg = "¡La Red Viscosa en %s se retiró!" % side_name
        _:
            push_warning("Invalid FieldEffect on get_end_field_effect_message()")
            return {}
    
    return { "type": "wait", "text": msg, "wait_time": 1.0 }


func get_already_active_field_effect_message() -> Dictionary:
    return { "type": "wait", "text": "¡Pero falló!", "wait_time": 1.0 }


