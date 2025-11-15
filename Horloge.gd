extends Node2D

@onready var Instruments = $Instruments
const MyData = preload("res://Note.gd")
const Fs = 48000								# (Hz)


##### Valeurs à changer pour modifier le rythme #####
const bpm = 80  								# (battements par minute)
const measure_length = 4						# (battements par mesure)
const subs_div = 6								# (subdivisions par battement)

const total_subs = measure_length * subs_div	# (subdivisions totales par mesure)

const spb = 60.0 / bpm							# (secondes par battement)
const s_per_sub = spb / subs_div				# (secondes par subdivision)

var fondamental = 110.0
var semitone_ratio = pow(2.0, 1.0 / 12.0)

var gamme = [0, 1, 4, 5, 7, 8, 10]	# gamme en demi-tons par rapport à la fondamentale (0 = Fondamentale = La)
var note = 0

var markov_weighted = {							# {0: 0.0, 2: 0.0, 3: 0.0, 5: 0.0, 7: 0.0, 8: 0.0, 10: 0.0}
gamme[0]: {gamme[0]: 0.1, gamme[1]: 0.1, gamme[2]: 0.3, gamme[3]: 0.1, gamme[4]: 0.1, gamme[5]: 0.2, gamme[6]: 0.1},	# degré I
gamme[1]: {gamme[0]: 0.2, gamme[1]: 0.1, gamme[2]: 0.3, gamme[3]: 0.1, gamme[4]: 0.1, gamme[5]: 0.2, gamme[6]: 0.1},	# degré II
gamme[2]: {gamme[0]: 0.2, gamme[1]: 0.1, gamme[2]: 0.3, gamme[3]: 0.1, gamme[4]: 0.1, gamme[5]: 0.2, gamme[6]: 0.1},	# degré III
gamme[3]: {gamme[0]: 0.3, gamme[1]: 0.1, gamme[2]: 0.3, gamme[3]: 0.1, gamme[4]: 0.1, gamme[5]: 0.2, gamme[6]: 0.1},	# degré IV
gamme[4]: {gamme[0]: 0.3, gamme[1]: 0.1, gamme[2]: 0.3, gamme[3]: 0.1, gamme[4]: 0.1, gamme[5]: 0.2, gamme[6]: 0.1},	# degré V
gamme[5]: {gamme[0]: 0.4, gamme[1]: 0.1, gamme[2]: 0.3, gamme[3]: 0.1, gamme[4]: 0.2, gamme[5]: 0.1, gamme[6]: 0.1},	# degré VI
gamme[6]: {gamme[0]: 0.4, gamme[1]: 0.1, gamme[2]: 0.3, gamme[3]: 0.1, gamme[4]: 0.1, gamme[5]: 0.2, gamme[6]: 0.1},	# degré VII
}

var message = [null, null, null, null, null]

func _ready():

	var Drum_Kick = Note.new("Drum", 0.4, "Kick", 440.0, 0.8)
	var Drum_Snare = Note.new("Drum", 0.15, "Snare", 440.0, 0.4)
	var Drum_HiHat = Note.new("Drum", 0.4, "HiHat", 440.0, 0.3)

	var Lead_Note = Note.new("Synth", s_per_sub, "Square", fondamental * pow(2.0, note/12.0), randf()*0.3)

	var Bass_Note = Note.new("Bass", s_per_sub*(subs_div-1), "Bass", fondamental * pow(2.0, note/12.0)/2, 0.3)
	var Bass_Groove = false

	print(markov_weighted)	
	for bidule in markov_weighted:
		print("From note ", bidule, " to:")

		for truc in markov_weighted[bidule]:
			print("   note ", truc, " with weight ", markov_weighted[bidule][truc])

		Bass_Note.Volume = 0.3

	while true:		
		print("###### Nouvelle mesure ",measure_length, " X ",subs_div ," ######")		
		for j in range(total_subs):	
			
			# note = gamme.pick_random() + 12 * int(randi_range(0, 1))
			
			message = [null, null, null, null, null]
			note = next_note_weighted(note)


			if j % subs_div == 0:
				print("- Temps ",(1+j / subs_div), " | Subdiv ", 1+j % subs_div)
			else:
				print("  Temps ",(1+j / subs_div), " | Subdiv ", 1+j % subs_div)
				
			if (j / subs_div) % 2 == 0 and j % subs_div == 0 :	
				message[0] = Drum_Kick

				Bass_Groove = randi_range(0, 1)
				if !Bass_Groove :
					Bass_Note.Frequency = fondamental * pow(2.0, note/12.0)/2
					message[3] = Bass_Note 

			elif (j / subs_div) % 2 == 1 and j % subs_div == 0 :
				message[1] = Drum_Snare

				if Bass_Groove :
					Bass_Note.Frequency = fondamental * pow(2.0, note/12.0)/2
					message[3] = Bass_Note

				Bass_Groove = round(randf_range(0, 3)/3)

			if j% 1 == 0:
				message[2] = Drum_HiHat
			

			Lead_Note.Frequency = fondamental * pow(2.0, note/12.0)
			Lead_Note.Volume = randf()*0.3
			message[4] = Lead_Note

			Instruments.receive_message(message)

			await get_tree().create_timer(s_per_sub).timeout
			
			

			

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

			

			
		
		
