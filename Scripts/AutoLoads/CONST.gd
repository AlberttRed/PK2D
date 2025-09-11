
extends Node

const GRID_SIZE = 32

const TEXT_SPEEDS = [0.1,0.15,0.2]

const OPTION_TEXT_FAST=0
const OPTION_TEXT_MEDIUM=1
const OPTION_TEXT_SLOW=2

const EVOL_LVL_UP=0
const EVOL_TRADE=1
const EVOL_STONE=2

const OPTION_BATTLE_ANIM_ON=0
const OPTION_BATTLE_ANIM_OFF=1

const OPTION_BATTLE_TYPE_SHIFT=0
const OPTION_BATTLE_TYPE_SET=1

const FacingInput = { 
	0: Vector2(-1, 0),
	1: Vector2(1, 0),
	2: Vector2(0, -1),
	3: Vector2(0, 1)
 }

const MoveInput = { 
	"left": Vector2(-1, 0),
	"right": Vector2(1, 0),
	"up": Vector2(0, -1),
	"down": Vector2(0, 1)
 }

enum InputDirections { LEFT, RIGHT, UP, DOWN }

const InputActions = { 
	0: "left",
	1: "right",
	2: "up",
	3: "down",
	4: "turn_left",
	5: "turn_right",
	6: "turn_up",
	7: "turn_down",
	8: "wait 0.25",
	9: "wait 0.50",
	10: "wait 1.00"
 }

const functions = {}

#·const Window_StyleBox = preload("res://ui/speech hgss 1.png")

const NaturesName = ["None", "Activa", "Afable", "Agitada", "Alegre", "Alocada", "Amable", "Audaz", "Cauta", "Dócil", "Firme", "Floja", "Fuerte", "Grosera", "Huraña", "Ingenua", "Mansa", "Miedosa", "Modesta", "Osada", "Pícara", "Plácida", "Rara", "Serena", "Seria", "Tímida"]
#
const Personality_Table = [ 
							[[[0, 5, 10, 15, 20, 25, 30],"Orgulloso de su fuerza."], [[1, 6, 11, 16, 21, 26, 31],"Le gusta revolverse."], [[2, 7, 12, 17, 22, 27],"A veces se enfada."], [[3, 8, 13, 18, 23, 28],"Le gusta luchar."], [[4, 9, 14, 19, 24, 29],"Tiene mal genio."]], # ATAQUE
							[[[0, 5, 10, 15, 20, 25, 30],"Cuerpo resistente."], [[1, 6, 11, 16, 21, 26, 31],"Es buen fajador."], [[2, 7, 12, 17, 22, 27],"Muy persistente."], [[3, 8, 13, 18, 23, 28],"Muy resistente."], [[4, 9, 14, 19, 24, 29],"Muy perseverante."]], # DEFENSA
							[[[0, 5, 10, 15, 20, 25, 30],"Extremadamente curioso."], [[1, 6, 11, 16, 21, 26, 31],"Le gusta hacer travesuras."], [[2, 7, 12, 17, 22, 27],"Muy astuto."], [[3, 8, 13, 18, 23, 28],"A menudo está en Babia."], [[4, 9, 14, 19, 24, 29],"Muy melindroso."]], # ATAQUE ESPECIAL
							[[[0, 5, 10, 15, 20, 25, 30],"Voluntarioso."], [[1, 6, 11, 16, 21, 26, 31],"Es algo orgulloso."], [[2, 7, 12, 17, 22, 27],"Muy insolente."], [[3, 8, 13, 18, 23, 28],"Odia perder."], [[4, 9, 14, 19, 24, 29],"Un poco cabezota."]],  # DEFENSA ESPECIAL
							[[[0, 5, 10, 15, 20, 25, 30],"Le gusta correr."], [[1, 6, 11, 16, 21, 26, 31],"Siempre tiene el oído alerta."], [[2, 7, 12, 17, 22, 27],"Impetuoso y bobo."], [[3, 8, 13, 18, 23, 28],"Es un poco payaso."], [[4, 9, 14, 19, 24, 29],"Huye rápido."]], # VELOCIDAD
							[], [],
							[[[0, 5, 10, 15, 20, 25, 30],"Le encanta comer."], [[1, 6, 11, 16, 21, 26, 31],"A menudo se duerme."], [[2, 7, 12, 17, 22, 27],"Duerme mucho."], [[3, 8, 13, 18, 23, 28],"Suele desordenar cosas."], [[4, 9, 14, 19, 24, 29],"Le gusta relajarse."]] # HP
						]

##							   None   Activa  Afable   Agitada Alegre Alocada Amable Audaz Cauta  Dócil  Firme  Floja  Fuerte Grosera Huraña  Ingenua  Mansa   Miedosa   Modesta   Osada   Pícara   Plácida   Rara   Serena   Seria   Tímida
const stat_effects_Natures = [ [], [1, 	1, 		1, 		1,		1,		1,		1,	  1.1,	1,		1,	  1.1,	 1,		 1,		1,		1.1,	 1,		 1,		0.9,	   0.9,		0.9,	1.1,	   1,		1,	  0.9,		1,		1], # ATAQUE
								[1, 	0.9, 	0.9, 	1.1,	1,		1,		0.9,   1,	1,		1,	   1,	1.1,	 1,		1,		0.9,	 1,		 1,		 1,			1,		1.1,	 1,		  1.1,		1,	   1,		1,		1], # DEFENSA
								[1, 	1, 		1.1, 	0.9,	0.9,	1.1,	1,	   1,	0.9,	1,	  0.9,	 1,		 1,		1,		1,		 1,		1.1,	 1,		   1.1,		 1,		 1,		   1,		1,	   1,		1,		1], # ATAQUE ESPECIAL
								[1, 	1, 		1, 		1,		1,		0.9,	1.1,   1,	1.1	,	1,	   1,	0.9,	 1,	   1.1,		1,		0.9,	 1,		 1,			1,		 1,		0.9,	   1,		1,	  1.1,		1,		1], # DEFENSA ESPECIAL
								[1, 	1.1, 	1, 		1,		1.1,	1,		1,	  0.9,	1,		1,	   1,	 1,		 1,	   0.9,		1,		1.1,	0.9,	1.1,		1,		 1,		 1,		  0.9,		1,	   1,		1,		1] ] # VELOCIDAD

var AbilitiesName = ["None", "Hedor", "Llovizna", "Impulso", "Armadura batalla", "Robustez", "Humedad", "Flexibilidad", "Velo arena", "Electricidad estática", "Absorbe electricidad", "Absorbe agua", "Despiste", "Aclimatación", "Ojo compuesto", "Insomnio", "Cambio color", "Inmunidad", "Absorbe fuego", "Polvo escudo", "Ritmo propio", "Ventosas", "Intimidación", "Sombra trampa", "Piel tosca", "Superguarda", "Levitación", "Efecto espora", "Sincronía", "Cuerpo puro", "Cura natural", "Pararrayos", "Dicha", "Nado rápido", "Clorofila", "Iluminación", "Rastro", "Potencia", "Punto tóxico", "Foco interno", "Escudo magma", "Velo agua", "Imán", "Insonorizar", "Cura lluvia", "Chorro arena", "Presión", "Sebo", "Madrugar", "Cuerpo llama", "Fuga", "Vista lince", "Corte fuerte", "Recogida", "Ausente", "Entusiasmo", "Gran encanto", "Más", "Menos", "Predicción", "Viscosidad", "Mudar", "Agallas", "Escama especial", "Lodo líquido", "Espesura", "Mar llamas", "Torrente", "Enjambre", "Cabeza roca", "Sequía", "Trampa arena", "Espíritu vital", "Humo blanco", "Energía pura", "Caparazón", "Bucle aire", "Tumbos", "Electromotor", "Rivalidad", "Impasible", "Manto níveo", "Gula", "Irascible", "Liviano", "Ignífugo", "Simple", "Piel seca", "Descarga", "Puño férreo", "Antídoto", "Adaptable", "Encadenado", "Hidratación", "Poder solar", "Pies rápidos", "Normalidad", "Francotirador", "Muro mágico", "Indefenso", "Rezagado", "Experto", "Defensa hoja", "Zoquete", "Rompemoldes", "Afortunado", "Resquicio", "Anticipación", "Alerta", "Ignorante", "Cromolente", "Filtro", "Inicio lento", "Intrépido", "Colector", "Gélido", "Roca sólida", "Nevada", "Recogemiel", "Cacheo", "Audaz", "Multitipo", "Don floral", "Mal sueño", "Hurto", "Potencia bruta", "Respondón", "Nerviosismo", "Competitivo", "Flaqueza", "Cuerpo maldito", "Alma cura", "Compiescolta", "Armadura frágil", "Metal pesado", "Metal liviano", "Compensación", "Ímpetu tóxico", "Ímpetu ardiente", "Cosecha", "Telepatía", "Veleta", "Funda", "Toque tóxico", "Regeneración", "Sacapecho", "Ímpetu arena", "Piel milagro", "Cálculo final", "Ilusión", "Impostor", "Allanamiento", "Momia", "Autoestima", "Justiciero", "Cobardía", "Espejo mágico", "Herbívoro", "Bromista", "Poder arena", "Punta acero", "Modo Daruma", "Tinovictoria", "Turbollama", "Terravoltaje", "Alas vendaval", "Amor filial", "Antibalas", "Aura feérica", "Aura oscura", "Baba", "Cambio táctico", "Carrillo", "Garra dura", "Mandíbula fuerte", "Manto frondoso", "Megadisparador", "Mutatipo", "Pelaje recio", "Piel celeste", "Piel feérica", "Piel helada", "Prestidigitador", "Rompe aura", "Simbiosis", "Tenacidad", "Velo aroma", "Velo dulce", "Velo flor", "Mar del albor", "Tierra del ocaso", "Ráfaga delta", "Firmeza", "Huida", "Retirada", "Hidrorrefuerzo", "Ensañamiento", "Escudo Limitado", "Vigilante", "Pompa", "Acero Templado", "Cólera", "Quitanieves", "Remoto", "Voz Fluida", "Primer Auxilio", "Piel Eléctrica", "Cola Surf", "Banco", "Disfraz", "Fuerte Afecto", "Agrupamiento", "Corrosión", "Letargo Perenne", "Regia Presencia", "Revés", "Pareja de Baile", "Batería", "Peluche", "Cuerpo Vívido", "Coránima", "Rizos Rebeldes", "Receptor", "Reacción Química", "Ultraimpulso", "Sistema Alfa", "Electrogénesis", "Psicogénesis", "Nebulogénesis", "Herbogénesis", "Guardia Metálica", "Guardia Espectro", "Armadura Prisma"]
var AbilitiesDesc = ["None", "Aleja a Pokémon salvajes.", "Cambia el clima a lluvioso.", "Aumenta la velocidad en cada turno.", "Bloquea golpes críticos.", "Anula golpes fulminantes.", "Evita la autodestrucción.", "Evita la parálisis.", "Aumenta evasión con Tormenta Arena.", "Paraliza al mínimo contacto.", "Convierte electricidad en PS.", "Convierte agua en PS.", "Evita la atracción.", "Anula los efectos del clima.", "Aumenta la precisión de los ataques.", "Evita el quedarse dormido.", "Toma el tipo del movimiento rival.", "Evita el envenenamiento.", "Aumenta la fuerza de los movimientos tipo fuego si el Pokémon recibe uno en vez de daño.", "Evita efectos secundarios.", "Evita la confusión.", "Fija el cuerpo con firmeza.", "Baja el ataque del rival.", "Evita que el enemigo huya.", "Hiere al tacto.", "Solo afectan golpes super efectivos.", "No sufre ataques tipo tierra.", "Duerme, paraliza o envenena al contacto.", "Transmite problemas de estado.", "Evita que bajen las estadísticas.", "Se cura al salir a la batalla.", "Atrae ataques de tipo eléctrico.", "Promueve efectos secundarios.", "Con lluvia, sube la velocidad.", "Con sol, sube la velocidad.", "Facilita el encuentro con Pokémon salvajes.", "Copia la habilidad especial.", "Aumenta el ataque.", "Envenena al mínimo contacto.", "Evita el retroceso.", "Evita el congelamiento.", "Evita las quemaduras.", "Atrapa Pokémon de acero.", "Evita ataques de sonido.", "Sube PS cuando llueve.", "Crea una tormenta de arena.", "Baja los PP del enemigo.", "Protege del frío y calor.", "Despierta rápido al Pokémon.", "Quema al mínimo contacto.", "Facilita la huida.", "Evita que baje la precisión.", "Evita que baje el ataque.", "Puede tomar objetos.", "Interviene cada dos rondas.", "Cambia precisión por Ataque.", "enamora al mínimo contacto.", "Mejora con la habilidad Menos.", "Mejora con la habilidad Más.", "Cambia de forma con el clima.", "Evita el robo de objetos.", "Se cura mudando la piel.", "Sube el ataque si el Pokémon sufre un cambio de estado.", "Sube la defensa si sufre.", "Al robar PS, hiere.", "Sube ataques tipo planta.", "Sube ataques tipo fuego.", "Sube ataques tipo agua.", "Incrementa el poder de ataques tipo bicho.", "Evita el daño colateral causado por movimientos del usuario.", "Cambia el clima a soleado en batalla.", "Evita la huida.", "Evita el quedarse dormido.", "Evita que bajen las estadísticas.", "Sube el ataque.", "Bloquea golpes críticos.", "Anula los efectos del clima.", "Sube la evasión si el Pokémon está confuso.", "Aumenta la rapidez si es golpeado con un ataque tipo eléctrico.", "Sube el ataque si el rival es del mismo sexo.", "Sube la velocidad cada vez que el Pokémon retrocede.", "Más evasión con Granizo.", "Aumenta la rapidez del uso de las bayas equipadas.", "Potencia el ataque tras recibir un golpe crítico.", "Sube la velocidad al perder un objeto equipado.", "Reduce el poder de los ataques tipo fuego.", "Cambia las características de la forma más audaz.", "Pierde PS si hace calor. Los recupera con agua.", "Ajusta el poder acorde con la habilidad del rival.", "Aumenta el poder de los puños.", "Sube PS si el Pokémon está envenenado.", "Potencia los movimientos del mismo tipo.", "Incrementa la frecuencia de golpes en los ataques de golpeo múltiple.", "Cura los problemas de estado si está lloviendo.", "Aumenta el ataque esp. y baja PS con sol.", "Potencia la velocidad si hay problemas de estado.", "Todos los movimientos de este Pokémon son de tipo normal.", "Potencia los movimientos que se vuelven críticos.", "Al Pokémon solo le afectan ataques directos.", "El ataque del Pokémon y el del rival acertarán.", "El Pokémon se moverá en segundo lugar.", "Aumenta el poder de los ataques débiles.", "Previene problemas de estado con día soleado.", "El Pokémon no puede usar ningún objeto equipado.", "No importan las habilidades para usar movimientos.", "Aumenta la posibilidad de producir un ataque crítico.", "Daña al rival que le ha dado el golpe de gracia.", "Siente los ataques peligrosos del rival.", "Determina el ataque más potente del Pokémon rival.", "Ignora cualquier cambio en la habilidad del enemigo.", "Potencia los movimientos poco eficaces.", "Mitiga los movimientos super efectivos.", "Reduce el ataque y la velocidad.", "Permite golpear a los Pokémon de tipo fantasma.", "Atrae ataques de tipo agua lanzados a un Pokémon.", "Sube PS con Granizo.", "Reduce el poder de los ataques super efectivos del rival.", "El Pokémon invoca una tormenta de granizo.", "El Pokémon recoge miel de donde puede.", "El Pokémon puede ver el objeto equipado del rival.", "Aumenta el poder de los ataques que causan retroceso.", "Cambia con la tabla equipada.", "Aumenta el poder con día soleado.", "Reduce los PS del enemigo cuando duerme.", "Hace que el usuario robe el objeto del rival al mínimo contacto.", "Los efectos secundarios de los ataques no se cumplen, pero se hacen más fuertes.", "Los movimientos que suben estadísticas las bajan, y viceversa.", "Esta habilidad anula el uso de las bayas.", "Los efectos de esta habilidad hacen que si al usuario le reducen una característica, sube dos puntos de ataque.", "Si los PS restantes del Pokémon son inferiores al 50% de sus PS máximos, sus estadísticas se reducen.", "Todo aquel rival que golpee a un Pokémon con esta habilidad tiene un 30% de probabilidad de ver anulado temporalmente el uso del movimiento utilizado.", "Esta habilidad permite eliminar todos los problemas de estado de un compañero Pokémon en plena batalla.", "Esta habilidad le brinda un poco de protección ante ataques de aliados haciendo que el poseedor de esta habilidad reciba menos daño del normal.", "Cuando el Pokémon es golpeado con ataques físicos, su Defensa se reduce un nivel pero su Velocidad aumenta un nivel.", "Hace que el Pokémon pese el doble.", "Hace que el Pokémon pese la mitad", "Cuando el Pokémon tiene su PS al máximo, esta habilidad reduce el daño recibido del ataque rival.", "Incrementa el poder los ataques físicos cuando el usuario está envenenado.", "Incrementa el poder de sus ataques especiales cuando el Pokémon está quemado.", "El Pokémon puede utilizar la misma Baya de manera indefinida en batalla.", "Con esta habilidad, ataques como terremoto o explosión no afectaran al Pokémon.", "Provoca que una de las estadísticas del Pokémon se incremente en dos niveles mientras otra se reduce en uno.", "Esta habilidad hace que el usuario sea invulnerable a los cambios del clima.", "Los movimientos de contacto del poseedor tienen una probabilidad del 30% de envenenar al oponente", "Recupera un tercio de sus PS (HP) cuando lo regresas a su Pokeball en batalla.", "Evita que le bajen la defensa al Pokémon usuario.", "Esta habilidad aumenta la velocidad del Pokémon que la tiene cuando hay una tormenta de arena en plena batalla.", "Esta habilidad evita que el pokémon sea afectado por ataques que no hagan daño.", "Hace que los movimientos sean mas poderosos si son utilizados al último.", "Permite transformarse en otros Pokémon.", "El Pokémon se transforma automáticamente en el Pokémon rival al salir a la batalla. En batallas múltiples se transforma en uno de sus rivales al azar.", "Los ataques del usuario no se ven afectados por ataques como Protección o Detección.", "Su efecto consiste en transformar la habilidad del oponente en Momia cuando el usuario es atacado por un ataque físico o de contacto, lo que da como resultado que el Pokémon pierda su habilidad y le sea inútil la de momia pues no tiene alguna otra característica especial.", "Consiste en subir el ataque cuando debilitas a un rival.", "Es una habilidad que da inmunidad ante los ataques de tipo siniestro y sube el ataque al recibir uno.", "Incrementa la Velocidad del Pokémon al enfrentarse a determinados tipos de Pokémon contra los que presenta debilidad.", "Refleja el efecto de determinados movimientos modificadores.", "Esta habilidad anula los posibles daños que el Pokémon que la tenga pueda sufrir al recibir ataques de tipo planta y aumenta su ataque cuando son golpeados por movimientos de dicho tipo.", "Hace que los ataques de efectos tengan prioridad.", "Esta habilidad aumenta el poder de los ataques de tipo tierra, roca y acero cuando hay una tormenta de arena en plena batalla.", "Provoca daño al rival que haga contacto con este Pokémon.", "Permite al pokemon usuario cambiar de forma cuando tenga menos del 50 % de PS, revirtiendo el Ataque por el Ataque especial.", "Aumenta la precisión del Pokemon.", "Hace que las otras habilidades no tengan efecto.", "Hace que las otras habilidades no tengan efecto.", "Otorga prioridad +1 a los movimientos de tipo volador.", "Permite atacar dos veces en un mismo turno, un ataque de su cría y otro del propio Pokémon.", "Hace al usuario inmune a los siguientes movimientos: Bola Hielo, Bola voltio, Bomba ácida, Bomba fango, Bomba Germen, Bomba Huevo, Bomba Imán, Bomba Lodo, Bola Sombra, Desenrollar, Energibola, Esfera Aural, Giro Bola, Meteorobola, Onda Certera, Presa, Pulpocañón, Recurrente, Bomba ígnea ,", "Potencia los movimientos de tipo Hada de todos los Pokémon en el combate.", "Potencia los movimientos de tipo Siniestro de todos los Pokémon en el combate.", "Baja en un nivel la velocidad del Pokémon que use un movimiento de contacto contra el poseedor de la habilidad.", "Cambia la forma y las estadísticas del Pokémon dependiendo de sus movimientos.", "Cuando un Pokémon con esta habilidad se come una baya en combate, además de obtener el efecto habitual de esa baya, recuperará PS.", "Aumenta el poder de los ataques físicos de contacto.", "Aumenta la potencia de movimientos en los que se requiere morder, como triturar o mordisco.", "Aumenta la defensa especial del usuario si se usa el movimiento campo de hierba.", "Aumenta la potencia de movimientos de pulsos, como hidropulso y pulso umbrío, haciéndolos aún más devastadores.", "Cambia el tipo del Pokémon al del movimiento que va a usar.", "Reduce a la mitad el daño recibido por ataques físicos.", "Cambia el tipo de los movimientos de tipo normal por tipo volador.", "Cambia el tipo de los movimientos de tipo normal por tipo hada.", "Convierte los movimientos de tipo normal en tipo hielo.", "Permite al usuario robar el objeto del oponente.", "Invierte todas las habilidades de aura.", "Hace que el usuario sea capaz de pasar un objeto a un aliado.", "Si al usuario le reducen una característica, sube dos puntos de ataque especial.", "Protege a los aliados de movimientos que afecten a su mente, como atracción.", "Evita que los Pokémon aliados se duerman durante el combate.", "Evita que bajen las características de los Pokémon de tipo planta aliados.", "Cambia el clima a diluvio.", "Cambia el clima a sol abrasador en batalla", "Cambia el clima a turbulencias en batalla", "Aumenta la Defensa al ser alcanzado por un ataque.", "El Pokémon escapa cobardemente del campo de batalla cuando su PS cae a menos de 50%.", "Al sentir peligro, el Pokémon escapa del campo de batalla cuando su PS cae a menos de 50%.", "Aumenta mucho la defensa al ser alcanzado por un ataque tipo Agua.", "Los ataques del usuario siempre serán golpes críticos si el objetivo está envenenado.", "Al tener menos de 50% de sus PS el usuario cambia de forma y no es afectado por problemas de estado.", "Duplica el daño causado cuando el Pokémon objetivo acaba de ingresar al campo de batalla.", "Disminuye el daño causado al usuario por ataques tipo Fuego, previene quemaduras y duplica la potencia de los ataques tipo Agua.", "Aumenta la potencia de los movimientos tipo Acero.", "Aumenta el Ataque Especial cuando los PS del usuario disminuyen a menos del 50%.", "Aumenta la Velocidad del Pokémon en una ventisca.", "El Pokémon ataca sin hacer contacto con el rival.", "Todos los ataques que causen sonido se vuelven tipo Agua.", "Le da prioridad a los movimientos que restauran PS.", "Los ataques tipo Normal se vuelven tipo Eléctrico, aumentando su potencia en 30%.", "Duplica la velocidad del Pokémon al haber Campo Eléctrico.", "Si Wishiwashi tiene más del 25% de PS, cambia a su Forma Banco.", "Al salir al combate, el usuario tiene un sustituto que anulará todo el daño del primer ataque que reciba.", "Al derrotar un oponente, Greninja se transforma en Greninja-Ash.", "Zygarde cambia a su Forma Completa cuando sus PS caen a menos del 50%.", "El Pokémon puede envenenar a su objetivo incluso si es tipo Acero o Veneno.", "El Pokémon actúa como si estuviera dormido sin estarlo y es inmune a cualquier problema de estado.", "Previene que los Pokémon rivales puedan usar movimientos con prioridad.", "Cuando un Pokémon con esta habilidad es debilitado, ocasiona daño al Pokémon que lo atacó equivalente al PS que tenía antes de recibir el ataque.", "Cuando otro Pokémon utiliza un movimiento de danza, el usuario lo usará también inmediatamente después.", "Aumenta el poder de los ataques especiales de los aliados.", "Reduce a la mitad el daño recibido por ataques que hagan contacto, pero duplica el daño recibido por ataques tipo fuego.", "El Pokémon es inmune a todos los ataques de prioridad.", "Aumenta el Ataque Especial cada vez que un Pokémon cae debilitado.", "Disminuye la velocidad de los Pokémon que hagan contacto con el usuario.", "Copia la habilidad de un aliado caído.", "Copia la habilidad de un aliado caído.", "Aumenta su mejor stat cada vez que derrota un Pokémon.", "Cambia el tipo del Pokémon dependiendo del Disco que tenga equipado.", "Produce un Campo Eléctrico al entrar en batalla.", "Produce un Campo Psíquico al entrar en batalla.", "Produce un Campo de Niebla al entrar en batalla.", "Produce un Campo de Hierba al entrar en batalla.", "Previene que los stats del usuario puedan ser reducidos.", "Reduce el daño al usuario cuando tiene sus PS al máximo.", "Reduce el daño de los ataques súper efectivos ocasionados al usuario."]

const DIRECTIONS = {
	"LEFT": 0,
	"RIGHT": 1,
	"UP": 2,
	"DOWN": 3
}

const OPPOSITE_DIRECTIONS = {
	"RIGHT": 0,
	"LEFT": 1,
	"DOWN": 2,
	"UP": 3
}

enum MOVE_COMMANDS { LEFT, RIGHT, UP, DOWN, TURN_LEFT, TURN_RIGHT, TURN_UP, TURN_DOWN, WAIT025, WAIT050, WAIT1 }

class EVENT:
	
	enum TYPE {
		NPC,
		EVENT
	}
	#const NPC = 0
	#const EVENT = 1

enum BATTLER_TYPES {
	TRAINER,
	WILD_POKEMON
}

enum STATUS {
	NONE = -1,
	OK, 
	SLEEP,
	POISON,
	BURN,
	PARALYSIS,
	FROZEN,
	FAINTED,
	POKERUS
}

class BATTLE:
	# HP bar colors
	const  HPCOLORGREEN = Color("#18c020")#Color(24,192,32)
	const  HPCOLORYELLOW = Color("#f8b000")#Color(248,176,0)
	const  HPCOLORRED = Color("#f85828")#Color(248,88,40)
	
	# Exp bar color
	const EXPCOLORBASE = Color("#4890f8")#Color(72,144,248)
	
	const SINGLE_BALL_POS = Vector2(58, -96)
	const BACK_BALL_POS = Vector2(116, -36)
	const FRONT_SINGLE_BALL_POS = Vector2(126, 60)
	#const DOUBLE2_BALL_POS = Vector2(90, -80)
	
	const SHADOW_SPRITE_POS = Vector2(0, 80) # Si la imatge és 190x190, s'hi suma 16
	#	const FRONT_SINGLE_SPRITE_POS = Vector2(128, -16)
	const FRONT_SINGLE_SPRITE_POS = Vector2(128, 30)#-32 per 190x190, -16 per 160x160     SI HA DE SUMAR EL DOBLE DEL VALOR BattlerEnemyY DE L ESSENTIALS
	const FRONT_POKEMONA_SPRITE_POS = Vector2(176, -16)#-32 per 190x190, -16 per 160x160     SI HA DE SUMAR EL DOBLE DEL VALOR BattlerEnemyY DE L ESSENTIALS
	const FRONT_POKEMONB_SPRITE_POS = Vector2(96, -32)#-48 per 190x190, -32 per 160x160     SI HA DE SUMAR EL DOBLE DEL VALOR BattlerEnemyY DE L ESSENTIALS
	
	const BACK_SINGLE_SPRITE_POS = Vector2(256, -16)   #SI HA DE SUMAR EL DOBLE DEL VALOR BattlerPlayerY DE L ESSENTIALS ??
	const BACK_POKEMONA_SPRITE_POS = Vector2(208, -16)   #SI HA DE SUMAR EL DOBLE DEL VALOR BattlerPlayerY DE L ESSENTIALS ??
	const BACK_POKEMONB_SPRITE_POS = Vector2(288, 0)   #SI HA DE SUMAR EL DOBLE DEL VALOR BattlerPlayerY DE L ESSENTIALS ??

	
	const BACK_SINGLE_TRAINER_POS = Vector2(262,-16) #Vector2(256,-16) 
	const BACK_DOUBLE1_TRAINER_POS = Vector2(-144,-80) 
	const BACK_DOUBLE2_TRAINER_POS = Vector2(224,-80) 
	
	const FRONT_SINGLE_TRAINER_POS = Vector2(122, 8)#Vector2(64,-58) 
	const FRONT_DOUBLE1_TRAINER_POS = Vector2(38, -58)
	const FRONT_DOUBLE2_TRAINER_POS = Vector2(84, -58)
	
	const PLAYER_BASE_INITIALPOSITION = Vector2(476,240)
	const PLAYER_BASE_FINALPOSITION = Vector2(-128,240)
	const ENEMY_BASE_INITIALPOSITION = Vector2(-252,112)
	const ENEMY_BASE_FINALPOSITION = Vector2(256,112)
	#-244
	const SINGLE_PLAYERHPBAR_A_INITIALPOSITION = Vector2(770, -3)
	const SINGLE_PLAYERHPBAR_A_FINALPOSITION = Vector2(526, -3)
	const SINGLE_ENEMYHPBAR_A_INITIALPOSITION = Vector2(-386, -45)
	const SINGLE_ENEMYHPBAR_A_FINALPOSITION = Vector2(-144, -45)
	
	const SINGLE_PLAYERPARTY_INITIALPOSITION = Vector2(562, 230)
	const SINGLE_ENEMYPARTY_INITIALPOSITION = Vector2(270, 105)
	const SINGLE_PLAYERBASE_INITIALPOSITION = Vector2(-148, 240)
	const SINGLE_ENEMYBASE_INITIALPOSITION = Vector2(257, 111)
	
	const SINGLE_BACK_SLOT = 0
	const DOUBLE_BACK_SLOT_1 = 1
	const DOUBLE_BACK_SLOT_2 = 2
	const SINGLE_FRONT_SLOT = 3
	const DOUBLE_FRONT_SLOT_1 = 4
	const DOUBLE_FRONT_SLOT_2 = 5
	#
#enum BATTLE_MODES {
	#NONE,
	#SINGLE,
	#DOUBLE,
	#TRIPLE
#}

enum BATTLE_SIDES {
	NONE,
	PLAYER,
	ENEMY
}
	
	


enum BATTLE_ACTIONS {
	LUCHAR,
	POKEMON,
	MOCHILA,
	HUIR,
	NONE = -1
}

enum BATTLE_STAGES {
	SELECT_ACTION,
	DO_ACTION
}
	
class BATTLE_BACKGROUNDS:

	const FIELD = 0
	const FOREST = 1
	const CAVE = 2
	const CAVEDARK = 3
	const CHAMPION = 4
	const ELITEA = 5
	const ELITEB = 6
	const ELITEC = 7
	const ELITED = 8
	const INDOORA = 9
	const INDOORB = 10
	const INDOORC = 11
	const MOUNTAIN = 12
	const SNOW = 13
	const UNDERWATER = 14
	const WATER = 15
	
enum DAMAGE_CLASS {
	
	ESTADO = 1,
	FISICO = 2,
	ESPECIAL = 3	
	
	
}
	
#enum WEATHER {
	#NONE,
	#SOLEADO = 1,
	#SOL_ABRASADOR = 2,
	#LLUVIOSO = 3,
	#DILUVIO = 4,
	#TORM_ARENA = 5,
	#GRANIZO = 6,
	#NIEBLA = 7,
	#TURBULENCIAS = 8,
	#LLUVIA_DIAMANTES = 9
#}
	#
#enum TARGETS {
	#NONE,
	#ESPECIFICO, # El Target es selecciona automáticament segons el moviment, son casos especials. Ex: Maldición, Contraataque En cas de combat doble, no fa seleccionar res
	#YO_PRIMERO, # Cas especial per l atac Yo Primero. Es selecciona el pokemon individualment, com un atac normal.
	#ALIADO, # L atac va dirigit per força l aliat del pokemon que executa l atac. Si no té aliat l'atac fallarà. Ex: Refuerzo En cas de combat doble, no fa seleccionar res
	#BASE_PLAYER, # Efecta a la BASE/FIELD. L'atac afecta a tots els pkmn q estàn a la mateixa base que el pkmn atacant. El target serà el mateix pokemon atacant i el seu aliat. Ex: Pantalla Luz En cas de combat doble, no fa seleccionar res
	#USER_OR_ALLY, # El jugador podrà seleccionar l'objectiu entre el propi pokemon atacant i l'aliat. Només un dels dos. En cas de combat doble, fa seleccionar entre el pokemon i l'aliat. En els enemics no deixa.
	#BASE_ENEMY, # Efecta a la BASE/FIELD. A la inversa que el BASE_PLAYER, l atac afectarà a TOTS els pokemons q estiguin la base rival. Ex: Púas En cas de combat doble, no fa seleccionar res
	#USER, #Efecte a l'usuari. Només es pot seleccionar el pokemon que fa l'atac. Ex: Danza espada En cas de combat doble, no fa seleccionar res
	#RANDOM_ENEMY, #Efecte a un dels dos pokemons enemics aleatoriament. No pots seleccionar quin. Ex: Combate En cas de combat doble, no fa seleccionar res
	#ALL_OTHER, #L'atac efecte a tots els pokemons sobre el camp de batalla menys l'atacant. Inclós els aliats. Ex: Surf. En cas de combat doble, no fa seleccionar res
	#SELECCIONAR, #El jugador selecciona individualment un pokemon, com qualsevol atac normal. Ex: Placaje #El jugador selecciona individualment un pokemon, com qualsevol atac normal. Ex: Placaje  En cas de combat doble, pot seleccionar els dos enemics i l'aliat. Si només queda un enemic (aliat i altre enemic morts), tambe et fa seleccioanr igualment, encara q nomes en qeu
	#ENEMIES, #L'atac afecta a tots els pokemons rivals. Ex: Malicioso  En cas de combat doble, no fa seleccionar res
	#ALL_FIELD, # Afecta al FIELD. Afecta al camp de batalla, per tant a tots els pokemons en combat, inclós l'atacant. Exemple: Tormenta Arena, Danza lluvia..  En cas de combat doble, no fa seleccionar res
	#PLAYERS, # Al revés que ENEMIES, afecta directament al pokemon atacant i aliats, pero no als enemics. Ex: Campana Cura  En cas de combat doble, no fa seleccionar res
	#ALL_POKEMON # Afecta directament a tots els pokemons en combat. Ex: Canto Mortal  En cas de combat doble, no fa seleccionar res
#
#}

const BATTLE_STAGE_MULT_STATS = { 
	6 : 4.0,
	5 : 3.5,
	4 : 3.0,
	3 : 2.5,
	2 : 2.0,
	1 : 1.5,
	0 : 1.0,
	-1 : 0.66,
	-2 : 0.5,
	-3 : 0.4,
	-4 : 0.33,
	-5 : 0.28,
	-6 : 0.25,
	}
#Aquesta es la taula de la precisió, en el cas de la evasió, l'ordre s'inverteix
const BATTLE_STAGE_MULT_EVACC = {
	6 : 3.0,
	5 : 2.66,
	4 : 2.33,
	3 : 2.0,
	2 : 1.66,
	1 : 1.33,
	0 : 1.00,
	-1 : 0.75,
	-2 : 0.6,
	-3 : 0.5,
	-4 : 0.43,
	-5 : 0.375,
	-6 : 0.33,
}
#Taula que indica la probabilitat de fer un crític segons l'stage (battleCriticalMod) del pokemon
const BATTLE_STAGE_MULT_CRITICAL = {
	4 : 50.0,
	3 : 33.3,
	2 : 25.0,
	1 : 12.5,
	0 : 6.25,
}

#class MOVE_EFFECTS:
	
class TYPES:
	const NONE = 0
	const NORMAL = 1
	const FIGHTING = 2
	const FLYING = 3
	const POISONO = 4
	const GROUND = 5
	const ROCK = 6
	const BUG = 7
	const GHOST = 8
	const STEEL = 9
	const FIRE = 10
	const WATER = 11
	const GRASS = 12
	const ELECTRIC = 13
	const PSYCHIC = 14
	const ICE = 15
	const DRAGON = 16
	const DARK = 17
	const FAIRY = 18

enum HEAL_TYPE {
	MOVE,
	ITEM
}

enum MOVE_CATEGORIES {
	DAMAGE, #Moviments que "únicament" provoquen mal Ex: Placaje, Golpe Karate, Pistola Agua etc. 
	AILMENT, # Moviments que "únicament" canvien l'status del pokemon rival. Ex: Onda Trueno, Somnífero... Cal tenir en compte que aqui també inclou atacs que provoquen confusió, o atacs com drenadoras.
	CHANGE_STATS, # Moviments que "únicament" fan pujar stats de l'user o baixar stats del rival Ex: Danza Espada, Gruñido, Malicioso... Cal tenir en compte que aquí també inclou atacs que afecten a l'evasió i precisió, com Ataque Arena.
	HEAL, # Moviments que ´únicament" curen. Exemple: Batido, Síntesis, Recuperación
	DAMAGE_AILMENT, # Moviments que a part de provocar mal, també poden canviar l'status del pokemon rival. Ex: Picotzao ven., Puño fuego... Cal tenir en compte que aquí també inclou atacs que a part de fer mal poden confondre, com Confusión.
	SWAGGER, # Moviments que no provoquen mal, però que modifiquen l'status i els stats del rival. Només son 4 moviments. Ex: Contoneo, que fa pujar els stats del rival, pero també el confón.
	DAMAGE_LOWER, # Moviments que a part de provocar mal, també baixen els stats del rival. Ex: Psíquico, que a part de fer mal té un 10% de possibilitats de baixar la defensa especial
	DAMAGE_RAISE, # Moviments que a part de provocar mal, també pugen els stats de l'user. Ex: Ala de Acero, que a part de fer mal té un 10% de possibilitats de pujar la defensa de l'usuari
	DAMAGE_HEAL, # Moviments que resten vida al rival i curen a l'usuari. Ex: Absorber, Megagotar...
	OHKO, # Moviments que maten d'un sol cop.  Ex: Fisura, Perforador, Guillotina...
	WHOLE_FIELD, # Moviments que afecten a tot el camp del combat. Ex: Tormenta arena, Dia soleado...
	FIELD, # Moviment que afecta tots els pokemons d'un dels dos sides de la batalla. Ex: Velo Sagrado, Pantalla Luz, Púas...
	FORCE_SWITCH, # Moviments que provoquen un canvi de pokemon del rival. Ex: Rugido
	UNIQUE # Moviments que tenen cosos especials, perque son únics. Hi ha més de 100 moviments. Ex: Transformación, Sustituto, Maldición...
}

class MOVES:
	const CORTE = 15
	const SURF = 57
	const FUERZA = 70

class MEDALS:
	const ROCA = "Roca"
	const CASCADA = "Cascada"
	const TRUENO = "Trueno"
	const ARCOIRIS = "Arcoíris"
	const ALMA = "Alma"
	const PANTANO = "Pantano"
	const VOLCAN = "Volcán"
	const TIERRA = "Tierra"
	
enum GENEROS {
	NON_SELECTED,
	MACHO,
	HEMBRA,
	SIN_GENERO
}

class NATURES:
	const NONE = 0
	const ACTIVA = 1
	const AFABLE = 2
	const AGITADA = 3
	const ALEGRE = 4
	const ALOCADA = 5
	const AMABLE = 6
	const AUDAZ = 7
	const CAUTA = 8
	const DOCIL = 9
	const FIRME = 10
	const FLOJA = 11
	const FUERTE = 12
	const GROSERA = 13
	const HURANA = 14
	const INGENUA = 15
	const MANSA = 16
	const MIEDOSA = 17
	const MODESTA = 18
	const OSADA = 19
	const PICARA = 20
	const PLACIDA = 21
	const RARA = 22
	const SERENA = 23
	const SERIA = 24
	const TIMIDA = 25
	
enum STATS {
	HP = 0,
	ATA = 1,
	DEF = 2,
	ATAESP = 3,
	DEFESP = 4,
	VEL = 5,
	ACC = 6,	#PRECISIÓ
	EVA = 7,  	#EVASIÓ
}

class ITEM_CATEGORIES:
	const STAT_BOOSTS = 1
	const EFFORT_DROP = 2
	const MEDICINE = 3
	const OTHER = 4
	const IN_A_PINCH = 5
	const PICKY_HEALING = 6
	const TYPE_PROTECTION = 7
	const BAKING_ONLY = 8
	const COLLECTIBLES = 9
	const EVOLUTION = 10
	const SPELUNKING = 11
	const HELD_ITEMS = 12
	const CHOICE = 13
	const EFFORT_TRAINING = 14
	const BAD_HELD_ITEMS = 15
	const TRAINING = 16
	const PLATES = 17
	const SPECIES_SPECIFIC = 18
	const TYPE_ENHANCEMENT = 19
	const EVENT_ITEMS = 20
	const GAMEPLAY = 21
	const PLOT_ADVANCEMENT = 22
	const UNUSED = 23
	const LOOT = 24
	const ALL_MAIL = 25
	const VITAMINS = 26
	const HEALING = 27
	const PP_RECOVERY = 28
	const REVIVAL = 29
	const STATUS_CURES = 30
	const MULCH = 32
	const SPECIAL_BALLS = 33
	const STANDARD_BALLS = 34
	const DEX_COMPLETION = 35
	const SCARVES = 36
	const ALL_MACHINES = 37
	const FLUTES = 38
	const APRICORN_BALLS = 39
	const APRICORN_BOX = 40
	const DATA_CARDS = 41
	const JEWELS = 42
	const MIRACLE_SHOOTER = 43
	const MEGA_STONES = 44
	const MEMORIES = 45

class BAG_POCKETS:
	const ITEMS = 1
	const MEDICINE = 2
	const POKE_BALLS = 3
	const TMS_AND_HMS = 4
	const BERRIES = 5
	const MAIL = 6
	const BATTLE_ITEMS = 7
	const KEY_ITEMS = 8
	
enum ENCOUNTER_METHODS {
	NONE,
	LAND,
	LAND_MORNING,
	LAND_DAY,
	LAND_NIGHT,
	WATER,
	CAVE,
	BUG_CONTEST,
	ROCK_SMASH,
	OLD_ROD,
	GOOD_ROD,
	SUPER_ROD,
	HEADBUTT_LOW,
	HEADBUTT_HIGH
}
class TILE_TYPE:
	const NONE = 0
	const ENCOUNTER = 1
	const SURF = 2
	const LEDGE = 3


enum EXPERIENCE_GROUP {SLOW = 1, MEDIUM, FAST, MEDIUM_SLOW, ERRATIC, FLUCTUATING}
#class EXPERIENCE_GROUP:
	#const SLOW = 1
	#const MEDIUM = 2
	#const FAST = 3
	#const MEDIUM_SLOW = 4
	#const ERRATIC = 5
	#const FLUCTUATING = 6
	
func ready():
	# Initialization here
	pass
