@tool
@icon("res://Scripts/guitar_emote.png")

class_name Musical_Instrument extends Node

### Ce code détermine ce que fait le node quand il est créé et autres

### Ce code contient les var est paramètres du node
@export_group("Node Clock (parent at first)")
@export var Clock = get_parent()							## Clock Node that send message and give important data like Fs, bpm, etc...

@export_group("Audio Player")
@export var AudioPlayer: AudioStreamPlayer					## (Node AudioStreamPlayer) Node qui joue le son généré

@export_group("Buffer")
@export var Buffer_duration : float = 1.0					## Durée du buffer (s)

@onready var Fs : int = Clock.Fs							## Fréquence d'échantillonage de la clock (48000 Hz par défaut)
@onready var s_per_sub = Clock.s_per_sub					## (float) Secondes par subdivision de la clock
var Buffer = []												## (array) Buffer circulaire contenant les échantillons audio générés
var Buffer_size = Fs * Buffer_duration						## Taille du buffer en samples (int)

var playback												## (AudioStreamPlayback) Handle de playback pour envoyer les échantillons audio

func _ready() -> void:
	AudioPlayer.play()
	playback = AudioPlayer.get_stream_playback()			
	Buffer.resize(Buffer_size)
	Buffer.fill(0.0)

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
	var out = lowpass_iir(add_arrays(Chirp(duration, 40.0, 10.0, "sawtooth", 1.0), WhiteNoise(duration)), 200.0)
	var out_bis = lowpass_iir(add_arrays(WhiteNoise(duration), WhiteNoise(duration)), 1000.0)
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
	var out = WhiteNoise(duration)
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
	var out = lowpass_iir(Chirp(duration, frequency, frequency, "square", 1.0), 5000.0)
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
	var out = lowpass_iir(Chirp(duration, frequency, frequency, "sawtooth", 1.0), 5000.0)
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
