extends Node
const MyData = preload("res://Scripts/Note.gd")						## Preload de la classe Note pour créer des notes musicales

@export_group("Lien aux nodes")

@export var Clock: Node = get_parent()				## (Node) Clock Node that send the message every sub_times, and give value like Fs, tempo, etc...
@export var AudioPlayer: AudioStreamPlayer			## (Node AudioStreamPlayer) Node qui joue le son généré

@export_group("Buffer")
@export var Buffer_duration: float = 1.0			## Durée du buffer (secondes)

@export_group("Metrique (-1 is Clock value)")
@export var measure_length : int = -1				## Temps par mesure (-1 is Clock value)
@export var subs_div : int = -1						## Subdivisions par temps (-1 is Clock value)

@export_group("Tuning (-1 is Clock value)")
@export var fondamental : float = -1.0				## Fréquence fondamentale (-1 is Clock value)

@export_group("Volumes des instruments")
@export var vol_drum_kick : float = 0.8			## Volume du kick (entre 0.0 et 1.0)
@export var vol_drum_snare : float = 0.4		## Volume de la snare (entre 0.0 et 1.0)
@export var vol_drum_hihat : float = 0.3		## Volume du hihat (entre 0.0 et 1.0)
@export var vol_lead : float = 0.3				## Volume du lead (entre 0.0 et 1.0)
@export var vol_bass : float = 0.3				## Volume de la basse (entre 0.0 et 1.0)

@export_group("Visualisation and Debug")
@export var metric_plot: bool = false			## If true, this will plot every subdiv and note

@onready var Fs : float = Clock.Fs								## Fréquence d'échantillonage du parent (48000 Hz par défaut)
@onready var Buffer_size : int = round(Fs * Buffer_duration)	## Taille du buffer (1 seconde d'audio)
@onready var sub_div_pm: float = Clock.sub_div_pm				## sub div par minute du parent
@onready var s_per_sub : float = 60.0 / sub_div_pm				## secondes par subdivision
@onready var gamme : Array = Clock.gamme						## gamme en demi-tons par rapport à la fondamentale (0 = Fondamentale = La) du parent


var semitone_ratio : float = pow(2.0, 1.0 / 12.0)				## ratio de fréquence entre deux demi-tons consécutifs

var note: float = 0												## note choisie dans gamme au hasard


var Buffer: Array = []											## (array) Buffer circulaire contenant les échantillons audio générés
var playback: AudioStreamPlayback								## (AudioStreamPlayback) Handle de playback pour envoyer les échantillons audio

var total_subs : int											## subdivisions totales par mesure
var spb : float													## secondes par temps

var Sound_To_Render: Array = [null, null, null, null, null]		## [Drum_Kick, Drum_Snare, Drum_HiHat, Bass_Note, Lead_Note] Array contenant le message envoyé aux instruments

var Bass_Groove = false								## Booléen pour déterminer si la basse joue sur le temps ou pas

var Drum_Kick: Note 								## Note de kick
var Drum_Snare: Note								## Note de snare
var Drum_HiHat: Note								## Note de hihat
var Lead_Note: Note									## Note de lead
var Bass_Note: Note									## Note de basse

var j: int = 0										## Indice de la subdivision actuelle normalisé sur la metrique de l'instrument

func _ready():
	assert(!AudioPlayer == null, "No AudioPlayer defined for this Instrument")		## Stop si l'audio player n'a pas été définie
	
	# Applique la valeur de la clock si param = -1
	if measure_length == -1:
		measure_length = Clock.measure_length
	if subs_div == -1:
		subs_div = Clock.subs_div	
	if fondamental == -1:
		fondamental = Clock.fondamental
		
	total_subs = measure_length * subs_div			# update total_subs value							
	
	
	Drum_Kick = Note.new("Drum", 0.4, "Kick", 440.0, vol_drum_kick)													## Note de kick
	Drum_Snare = Note.new("Drum", 0.15, "Snare", 440.0, vol_drum_snare)												## Note de snare
	Drum_HiHat = Note.new("Drum", 0.4, "HiHat", 440.0, vol_drum_hihat)												## Note de hihat
	Lead_Note = Note.new("Synth", s_per_sub, "Square", fondamental * pow(2.0, note/12.0), vol_lead)			## Note de lead
	Bass_Note = Note.new("Bass", s_per_sub*(subs_div-1), "Bass", fondamental * pow(2.0, note/12.0)/2, vol_bass)		## Note de basse
	
	# Start playing the AudioPlayer, and prepare the Buffer Array
	AudioPlayer.play()
	playback = AudioPlayer.get_stream_playback()			
	Buffer.resize(Buffer_size)
	Buffer.fill(0.0)
	
	
## Quand le node reçoit un message (array de Notes), il génère le son correspondant dans le buffer et envoie certain echantillons du buffer au player.
func receive_message(message):	
	
	Sound_To_Render = [null, null, null, null, null]
	Drum_Kick.Volume = vol_drum_kick
	Drum_Snare.Volume = vol_drum_snare
	Drum_HiHat.Volume = vol_drum_hihat
	Lead_Note.Volume = vol_lead
	Bass_Note.Volume = vol_bass
	
	note = message[1]
	j = message[0] % total_subs
	
	if metric_plot :
		if j == 0 :
			print("      New ",measure_length, "X", subs_div, " Measure")
		if j % subs_div == 0 :
			print("--- ", j+1,"/",total_subs, " | ", note, " semi-tone")
		else : 
			print("    ", j+1,"/",total_subs, " | ", note, " semi-tone")
	

		
	if (int(j / float(subs_div))) % 2 == 0 and j % subs_div == 0 :	
		Sound_To_Render[0] = Drum_Kick

		Bass_Groove = randi_range(0, 1)
		if !Bass_Groove :
			Bass_Note.Frequency = fondamental * pow(2.0, note/12.0)/2
			Sound_To_Render[3] = Bass_Note 

	elif (int(j / float(subs_div))) % 2 == 1 and j % subs_div == 0 :
		Sound_To_Render[1] = Drum_Snare

		if Bass_Groove :
			Bass_Note.Frequency = fondamental * pow(2.0, note/12.0)/2
			Sound_To_Render[3] = Bass_Note

		Bass_Groove = int(randf_range(0, 5)/5)

	elif j% 1 == 0:
		Sound_To_Render[2] = Drum_HiHat
	
	if randf() >= 0.3 :
		Lead_Note.Frequency = fondamental * pow(2.0, note/12.0)
		# Lead_Note.Volume = randf()*vol_lead
		Sound_To_Render[4] = Lead_Note
	
	for m in Sound_To_Render:
		if m != null:
			if m.Soundtype == "HiHat":
				Play_HiHat(m.Duration, m.Volume)

			elif m.Soundtype == "Kick":
				Play_Kick(m.Duration, m.Volume)
			
			elif m.Soundtype == "Snare":
				Play_Snare(m.Duration, m.Volume)
			
			elif m.Soundtype == "Square" and m.Volume != 0.0:
				Play_SquareWave(m.Duration, m.Frequency, m.Volume)

			elif m.Soundtype == "Bass":
				Play_Bass(m.Duration, m.Frequency, m.Volume)
			
			
	for i in range(Fs*s_per_sub+1):
		playback.push_frame(Vector2.ONE * Buffer[i])
	Buffer = rotate_array(Buffer, round(Fs*s_per_sub))







## Rotate (shift) to the left an array by a given integer offset, filling out-of-bounds indices with 0.0.
## [br]
## [br][param arr: Array] Input array to be rotated.
## [br][param offset: int] Number of positions to rotate the array to the left
func rotate_array(arr: Array, offset: int) -> Array:					
	var size = arr.size()
	if size == 0:
		return arr.duplicate()

	var result := []
	result.resize(size)
	for i in size:
		var src_index = i + offset
		if src_index >= 0 and src_index < size:
			result[i] = arr[src_index]
		else:
			result[i] = 0.0
	return result

## Generates a WhiteNoise array of given duration (s).
## [br]
## [br][param duration: float] Duration of the sound (seconds).
func WhiteNoise(duration: float) -> Array:
	var n = int(duration * Fs)
	var out = []
	out.resize(n)
	for i in range(n):
		out[i] = randf()
	return out

## Generates a sine wave of given duration (s) and frequency (Hz).
## [br]
## [br][param duration: float] Duration of the sound (seconds).
## [br][param frequency: float = 440.0] Frequency of the sine wave (Hz).
func SineWave(duration: float, frequency: float = 440.0) -> Array:
	var n = int(duration * Fs)
	var out = range(n)
	for i in range(n):
		out[i] = sin(i * 2.0 * PI * frequency / Fs)       
	return out

## Generates a linear chirp from start_frequency to end_frequency over the given duration.
## [br]
## possible wavetype: "sine", "square", "sawtooth".
## [br][param duration: float] Duration of the sound (seconds).
## [br][param start_frequency: float = 50.0] Starting frequency (Hz).
## [br][param end_frequency: float = 10.0] Ending frequency (Hz).
## [br][param wave: String="sawtooth"] Waveform type between ("sine", "square", "sawtooth").
## [br][param volume: float=1.0] Amplitude multiplier (between 0.0 and 1.0).
func Chirp(duration: float, start_frequency : float=50.0, end_frequency: float=10.0, wave: String="sawtooth", volume: float=1.0) -> Array:
	var n = int(duration * Fs)
	var out = range(n)
	if wave == "sine":
		for i in range(n):
			var t = float(i) / Fs
			var instantaneous_frequency = start_frequency + (end_frequency - start_frequency) * (t / duration)
			out[i] = sin(2.0 * PI * instantaneous_frequency * t) * volume     
	if wave == "square":
		for i in range(n):
			var t = float(i) / Fs
			var instantaneous_frequency = start_frequency + (end_frequency - start_frequency) * (t / duration)
			out[i] = sign(sin(2.0 * PI * instantaneous_frequency * t)) * volume  
	if wave == "sawtooth":
		for i in range(n):
			var t = float(i) / Fs
			var instantaneous_frequency = start_frequency + (end_frequency - start_frequency) * (t / duration)
			out[i] = 2.0 * (t * instantaneous_frequency - floor(0.5 + t * instantaneous_frequency)) * volume  
	return out

## Generates an exponential decay envelope going from 1 to 0 of given duration (s) and time constant tau .
## [br]
## Higher tau values produce a faster decay (tau > 0).
## [br]
## [br][param duration: float] Duration of the envelope (seconds).
## [br][param tau: float = 1.0] Time constant controlling the decay rate [b](must be tau > 0)[/b].
## [br][param revert: bool = false] If true, generates an envelope going from 0 to 1 instead.
func Decay(duration: float, tau: float=1.0, revert: bool=false) -> Array:
	var n = int(duration * Fs)
	var out = range(n)
	if revert:
		for i in range(n):
			out[n-(i+1)] 	= (1 - (i+1)/float(n))**(tau)
	else:
		for i in range(n):
			out[i] 			= (1 - (i+1)/float(n))**(tau)
	return out

## Adds two numeric arrays element-wise of [b]same size[/b]
## [br]
## [br][param arr1: Array] First input.
## [br][param arr2: Array] Second input.
func add_arrays(arr1: Array, arr2: Array) -> Array:
	var result = []
	for i in range(arr1.size()):
		result.append(arr1[i] + arr2[i])
	return result

## Multiplies two numeric arrays element-wise of [b]same size[/b]
## [br]
## [br][param arr1: Array] First input.
## [br][param arr2: Array] Second input.
func multiply_array(arr1: Array, arr2: Array) -> Array:
	var result = []
	for i in range(arr1.size()):
		result.append(arr1[i] * arr2[i])
	return result

## Applies a simple one-pole IIR low-pass filter to the input samples.
## [br]
## [br][param samples: Array] Input of samples to be filtered.
## [br][param cutoff_hz: float] Cutoff frequency of the low-pass filter (Hz).
func lowpass_iir(samples: Array, cutoff_hz: float) -> Array:
	"""
		- rc = 1 / (2π * cutoff_hz)
		- dt = 1 / Fs
		- alpha = dt / (rc + dt)
		- y[n] = y[n-1] + alpha * (x[n] - y[n-1])
	"""
	var rc = 1.0 / (2.0 * PI * cutoff_hz)
	var dt = 1.0 / Fs
	var alpha = dt / (rc + dt)
	
	var output = []
	var last = samples[0]
	for s in samples:
		last = last + alpha * (s - last)
		output.append(last)
	return output

## Compute hi-hat sound and mix into Buffer
## [br]
## [br][param duration: float] Duration  of the sound (seconds).
## [br][param volume: float = 1.0] Amplitude multiplier (between 0.0 and 1.0).
func Play_HiHat(duration: float, volume: float = 1.0) -> void:
	var out = lowpass_iir(WhiteNoise(duration), 10000.0)
	var decay = Decay(duration, 16.0)

	if Buffer.size() < out.size():
		for i in range(Buffer.size()):
			out[i] *= decay[i] * volume
			Buffer[i] += out[i]
	else :
		for i in range(out.size()):
			out[i] *= decay[i] * volume
			Buffer[i] += out[i]

## Compute kick sound and mix into Buffer
## [br]
## [br][param duration: float] Duration of the sound (seconds).
## [br][param volume: float = 1.0] Amplitude multiplier (between 0.0 and 1.0).
func Play_Kick(duration: float, volume: float = 1.0) -> void:
	var out = lowpass_iir(add_arrays(Chirp(duration, 40.0, 10.0, "sawtooth", 1.0), WhiteNoise(duration)), 400.0)
	var out_bis = lowpass_iir(Chirp(duration, 30.0, 10.0, "square", 1.0), 1000.0)
	var decay = Decay(duration, 4.5)

	if Buffer.size() < out.size():
		for i in range(Buffer.size()):
			out[i] *= decay[i] * volume * out_bis[i]
			Buffer[i] += out[i]
	else :
		for i in range(out.size()):
			out[i] *= decay[i] * volume * out_bis[i]
			Buffer[i] += out[i]

## Compute snare sound and mix into Buffer
## [br]
## [br][param duration: float] Duration of the sound (seconds).
## [br][param volume: float = 1.0] Amplitude multiplier (between 0.0 and 1.0).
func Play_Snare(duration: float, volume: float = 1.0) -> void:
	var out = add_arrays(WhiteNoise(duration), Chirp(duration, 300.0, 200.0, "square", 0.1))
	var decay = Decay(duration, 1.5)

	if Buffer.size() < out.size():
		for i in range(Buffer.size()):
			out[i] *= decay[i] * volume
			Buffer[i] += out[i]
	else :
		for i in range(out.size()):
			out[i] *= decay[i] * volume
			Buffer[i] += out[i]

## Compute squarewave lead sound and mix into Buffer
## [br]
## [br][param duration: float] Duration of the sound (seconds).
## [br][param frequency: float] Fundamental frequency (Hz).
## [br][param volume: float = 1.0] Amplitude multiplier (between 0.0 and 1.0).
func Play_SquareWave(duration: float, frequency: float, volume: float = 1.0) -> void:
	var out = lowpass_iir(Chirp(duration, frequency, frequency, "square", 1.0), 10000.0)
	var out_bis = lowpass_iir(Chirp(duration, 4.05*frequency, 4*frequency, "square", 1.0), 5000.0)
	var decay = Decay(duration, 2, false)

	if Buffer.size() < out.size():
		for i in range(Buffer.size()):
			out[i] *= decay[i] * volume * out_bis[i]
			Buffer[i] += out[i]
	else :
		for i in range(out.size()):
			out[i] *= decay[i] * volume * out_bis[i]
			Buffer[i] += out[i]

## Compute bass sound and mix into Buffer
## [br]
## [br][param duration: float] Duration of the sound (seconds).
## [br][param frequency: float] Fundamental frequency (Hz).
## [br][param volume: float = 1.0] Amplitude multiplier (between 0.0 and 1.0).
func Play_Bass(duration: float, frequency: float, volume: float = 1.0) -> void:
	var out = lowpass_iir(Chirp(duration, 0.99*frequency, frequency, "sawtooth", 1.0), 10000.0)
	var out_bis = lowpass_iir(Chirp(duration, 1.990*frequency, 2.01*frequency, "square", 1), 5000.0)
	var decay = Decay(duration, 1)

	if Buffer.size() < out.size():
		for i in range(Buffer.size()):
			out[i] *= decay[i] * volume * out_bis[i]
			Buffer[i] += out[i]
	else :
		for i in range(out.size()):
			out[i] *= decay[i] * volume * out_bis[i]
			Buffer[i] += out[i]


	

		
