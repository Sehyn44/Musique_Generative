extends Node

# Le node horloge envoie un message aux Instruments toute les "subdivision" (sub_section)
# Une metrique est définie de base dans l'horloge (mesure, et facon de compter les subdivision, ex: 4*4 ou 3*7, etc...)
# Mais chaque instrument peut avoir sa propre façon de compter les mesures pour jouer avec le décalage

@onready var Instrument = $Instrument								## Node Instruments qui joue les notes reçues

@export_group("Fréquence d'échantillonnage")
@export var Fs : int = 48000										## Fréquence d'échantillonage (48000 Hz par défaut)

@export_group("Metrique et Tempo")	## La métrique est construite de la facon suivante : 1 mesure = measure_length x temps et 1 mesure = subs_div x subdivision
## Exemple, pour les valeurs de bases, une mesure contient 4 temps, et chaque temps contient 6 subdivisions, et les subdivisions sont jouée au rythme de 400/min
@export var sub_div_pm : float = 400  								## sub div par minute
@export var measure_length : int = 4								## Temps par mesure
@export var subs_div: int = 6										## Subdivisions par temps

@export_group("Fréquence fondamentale")
@export var fondamental : float = 110.0								## Fréquence fondamentale (La2 = 110 Hz par défaut)

@onready var total_subs = measure_length * subs_div					## subdivisions totales par mesure
@onready var s_per_sub : float = 60.0 / sub_div_pm					## secondes par subdivision

var gamme: Array = [0, 2, 4, 5, 7, 9, 11]							## gamme en demi-tons par rapport à la fondamentale (0 = Fondamentale = La)

var markov_weighted = {												## Matrice de transition pondérée pour la génération de mélodies (voir chaine de markov)
	gamme[0]: {gamme[0]: 1.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré I
	gamme[1]: {gamme[0]: 2.0, gamme[1]: 1.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré II
	gamme[2]: {gamme[0]: 2.0, gamme[1]: 2.0, gamme[2]: 1.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré III
	gamme[3]: {gamme[0]: 3.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 1.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré IV
	gamme[4]: {gamme[0]: 3.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 1.0, gamme[5]: 2.0, gamme[6]: 2.0},	# degré V
	gamme[5]: {gamme[0]: 4.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 1.0, gamme[6]: 2.0},	# degré VI
	gamme[6]: {gamme[0]: 4.0, gamme[1]: 2.0, gamme[2]: 3.0, gamme[3]: 2.0, gamme[4]: 2.0, gamme[5]: 2.0, gamme[6]: 1.0},	# degré VII
}

var note = 0														## Note en demi-ton par rapport à la fondamentale jouée sur se temp
var iteration : int = 0												## Indice de la subdivision, par de 0 à l'infini si le projet ne s'arrete pas


func _ready():
	# Normalize weights so each row sums to 1.0
	for key in markov_weighted:
		var total = 0.0
		for value in markov_weighted[key].values():
			total += value
		for note_proba in markov_weighted[key]:
			markov_weighted[key][note_proba] /= total
	'''
	for bidule in markov_weighted:
		print("From note ", bidule, " to:")

		for truc in markov_weighted[bidule]:
			print("   note ", truc, " with weight ", snapped(markov_weighted[bidule][truc], 0.01)*100, "%")
	'''
	
	await get_tree().create_timer(0.1).timeout 			# Délai avant de lancer la boucle

	while true:											# Tout les subdivision, Horloge envoie un message aux instruments contenant l'indice de la subdivision ainsi que la note jouée
		note = next_note_weighted(note)

		Instrument.receive_message([iteration, note])
		iteration = iteration + 1

		await get_tree().create_timer(s_per_sub).timeout




## Renvoie la note suivante (en demi-tons par rapport à la fonda) en fonction de la note précédente selon une matrice de transition pondérée
## [br]
## [br][param prev_note: int] Note précédente (en demi-tons par rapport à la fondamentale).
func next_note_weighted(prev_note: int) -> int:			
	if not markov_weighted.has(prev_note):
		return gamme.pick_random()
	
	var choices = markov_weighted[prev_note]
	var r = randf()
	var acc = 0.0
	for note in choices.keys():
		acc += choices[note]
		if r <= acc:
			return note
	return choices.keys().back()  # fallback
