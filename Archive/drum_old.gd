extends Node2D

var playback

@onready var Fs = get_parent().Fs
@onready var Player = $AudioStreamPlayer

var Samples = []

func _ready():
	Player.play()
	playback = Player.get_stream_playback()

func Noise(duration):
	var n = int(duration * Fs)
	var out = []
	out.resize(n)
	for i in range(n):
		out[i] = randf()
	return out

func SineWave(duration, frequency=440.0):
	var n = int(duration * Fs)
	var out = range(n)
	for i in range(n):
		out[i] = sin(i * 2.0 * PI * frequency / Fs)       
	return out

func Chirp(duration, start_frequency=50.0, end_frequency=10.0, wave="sawtooth"):
	var n = int(duration * Fs)
	var out = range(n)
	if wave == "sine":
		for i in range(n):
			var t = float(i) / Fs
			var instantaneous_frequency = start_frequency + (end_frequency - start_frequency) * (t / duration)
			out[i] = sin(2.0 * PI * instantaneous_frequency * t)     
	if wave == "square":
		for i in range(n):
			var t = float(i) / Fs
			var instantaneous_frequency = start_frequency + (end_frequency - start_frequency) * (t / duration)
			out[i] = sign(sin(2.0 * PI * instantaneous_frequency * t))
	if wave == "sawtooth":
		for i in range(n):
			var t = float(i) / Fs
			var instantaneous_frequency = start_frequency + (end_frequency - start_frequency) * (t / duration)
			out[i] = 2.0 * (t * instantaneous_frequency - floor(0.5 + t * instantaneous_frequency))
			
	return out


func Play_HiHat(duration, volume = 1.0):
	var out = Noise(duration)
	if Samples.size() < out.size():
		Samples.resize(out.size())
	for i in range(out.size()):
		if Samples[i] == null:
			Samples[i] = 0.0
		out[i] *= exp(-3.0 * float(i) / Fs) * volume
		Samples[i] += out[i]
		# playback.push_frame(Vector2.ONE * out[i])

func Play_Kick(duration, volume = 1.0):
	var out = Chirp(duration)
	if Samples.size() < out.size():
		Samples.resize(out.size())
	for i in range(out.size()):
		if Samples[i] == null:
			Samples[i] = 0.0
		out[i] *= exp(-20.0 * float(i) / Fs) * volume
		Samples[i] += out[i]
		# playback.push_frame(Vector2.ONE * out[i])

func Play_Snare(duration, volume = 1.0):
	var out = Noise(duration)
	if Samples.size() < out.size():
		Samples.resize(out.size())
	for i in range(out.size()):
		if Samples[i] == null:
			Samples[i] = 0.0
		out[i] *= exp(-20.0 * float(i) / Fs) * volume
		Samples[i] += out[i]
		# playback.push_frame(Vector2.ONE * out[i])

func receive_message(message):
	if message.Soundtype == "HiHat":
		print("Playing ", message.Soundtype, " for ", message.Duration, " seconds")
		Play_HiHat(message.Duration, message.Volume)

	elif message.Soundtype == "Kick":
		print("Playing ", message.Soundtype, " for ", message.Duration, " seconds at ", message.Frequency, " Hz")
		Play_Kick(1, message.Volume)
	
	elif message.Soundtype == "Snare":
		print("Playing ", message.Soundtype, " for ", message.Duration, " seconds")
		Play_Snare(1, message.Volume)

	if Samples.size() > 60:
		for i in range(60):
			playback.push_frame(Vector2.ONE * Samples[0])
			Samples.remove_at(0)
	else:
		for i in range(Samples.size()):
			playback.push_frame(Vector2.ONE * Samples[0])
			Samples.remove_at(0)


		
