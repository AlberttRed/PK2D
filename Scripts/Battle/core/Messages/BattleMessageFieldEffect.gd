class_name BattleMessageFieldEffect
extends RefCounted


func get_start_field_effect_message(effect_id: int, side_name: String = "tu lado") -> Dictionary:
    var msg:String = ""
    match effect_id:
        MovesEnum.Values.REFLECT:
            msg = "¡Reflejo protege %s!" % side_name
        MovesEnum.Values.LIGHT_SCREEN:
            msg = "¡Pantalla de Luz protege %s!" % side_name
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


func get_end_field_effect_message(effect_id: int, side_name: String = "tu lado") -> Dictionary:
    var msg:String = ""
    match effect_id:
        MovesEnum.Values.REFLECT:
            msg = "¡Reflejo en %s desapareció!" % side_name
        MovesEnum.Values.LIGHT_SCREEN:
            msg = "¡Pantalla de Luz en %s desapareció!" % side_name
        MovesEnum.Values.SAFEGUARD:
            msg = "¡Velo Sagrado en %s se desvaneció!" % side_name
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


func get_already_active_field_effect_message(effect_id: int, side_name: String = "tu lado") -> Dictionary:
    var msg:String = ""
    match effect_id:
        MovesEnum.Values.REFLECT:
            msg = "¡Pero Reflejo ya protege %s!" % side_name
        MovesEnum.Values.LIGHT_SCREEN:
            msg = "¡Pero Pantalla de Luz ya protege %s!" % side_name
        MovesEnum.Values.SAFEGUARD:
            msg = "¡Pero Velo Sagrado ya protege %s!" % side_name
        MovesEnum.Values.MIST:
            msg = "¡Pero ya hay Neblina en %s!" % side_name
        # MovesEnum.Values.AURORA_VEIL:  # No existe en MovesEnum actual
        #     msg = "¡Pero Velo Aurora ya protege %s!" % side_name
        MovesEnum.Values.TAILWIND:
            msg = "¡Pero Viento Afín ya sopla a favor de %s!" % side_name
        MovesEnum.Values.SPIKES:
            msg = "¡Pero ya hay Púas en %s!" % side_name
        MovesEnum.Values.STEALTH_ROCK:
            msg = "¡Pero ya hay Trampa Rocas en %s!" % side_name
        MovesEnum.Values.STICKY_WEB:
            msg = "¡Pero ya hay Red Viscosa en %s!" % side_name
        _:
            push_warning("Invalid FieldEffect on get_already_active_field_effect_message()")
            return {}
    
    return { "type": "wait", "text": msg, "wait_time": 1.0 }


