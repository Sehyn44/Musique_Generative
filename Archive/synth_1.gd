extends Node2D

var Buffer = []

var playback

@onready var Fs = get_parent().Fs
@onready var s_per_sub = get_parent().s_per_sub
@onready var Player = $AudioStreamPlayer


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




func Play_Square(duration, freq, volume = 1.0):
	var out = Chirp(duration, freq, freq)
	if Buffer.size() < out.size():
		Buffer.resize(out.size())
	for i in range(out.size()):
		if Buffer[i] == null:
			Buffer[i] = 0.0
		out[i] *= exp(-20.0 * float(i) / Fs) * volume
		Buffer[i] += out[i]
		#Kickplayback.push_frame(Vector2.ONE * out[i])


func receive_message(message):
	if message is Array:
		print("Synth1 received array message with ", message.size(), " elements")
		for m in message:
			if m.Soundtype == "Square":
				#print("Playing ", message.Soundtype, " for ", message.Duration, " seconds")
				Play_Square(m.Duration, m.Frequency, m.Volume)



		if Buffer.size() > int(s_per_sub * Fs):
			for i in range(int(s_per_sub * Fs)):
				playback.push_frame(Vector2.ONE * Buffer[0])
				Buffer.remove_at(0)
		else:
			for i in range(Buffer.size()):
				playback.push_frame(Vector2.ONE * Buffer[0])
				Buffer.remove_at(0)

	

		
