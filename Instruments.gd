"""
Var: playback
Type: AudioStreamPlayback (assigned at runtime)
Description:
	Runtime handle to the AudioStreamPlayer's stream playback object.
	Used to push mixed audio frames into the active audio stream via push_frame().
Notes:
	Set in _ready() using Player.get_stream_playback().
"""


"""
Var: Fs
Type: int or float (samples per second)
Description:
	Sample rate in samples per second obtained from the parent node.
Usage:
	Used throughout the module to convert durations to sample counts and to compute time-based increments.
Notes:
	Declared with @onready and expected to be provided by the parent node.
"""


"""
Var: s_per_sub
Type: float (seconds)
Description:
	Duration, in seconds, of a single subdivision (block) to be written to the AudioStreamPlayback each processing step.
Usage:
	Used to compute how many samples to push per processing cycle: Fs * s_per_sub.
Notes:
	Declared with @onready and expected to be provided by the parent node.
"""


"""
Var: Player
Type: AudioStreamPlayer (Node)
Description:
	Reference to the AudioStreamPlayer child node that plays the generated audio stream.
Usage:
	Player.play() is called in _ready(); its playback object is acquired via get_stream_playback().
Notes:
	Declared with @onready to point to $AudioStreamPlayer.
"""


"""
Var: Buffer
Type: Array[float]
Description:
	Circular (mix) buffer that accumulates generated sample data before it is pushed to the AudioStreamPlayback.
	Each element is a single-channel sample (float). The script writes Vector2.ONE * Buffer[i] when pushing frames,
	so values are duplicated to stereo on output.
Usage:
	Filled and rotated by the logic in receive_message(), instrument Play_* functions add mixed content into it.
Notes:
	Initialized in _ready() to hold Fs * 1 seconds worth of samples and filled with 0.0.
"""

extends Node2D

var playback

@onready var Fs = get_parent().Fs
@onready var s_per_sub = get_parent().s_per_sub
@onready var Player = $AudioStreamPlayer
@onready var Buffer_size = Fs * 1.0

var Buffer = []
var temps = 0.0

func _ready():
	"""
	Function: _ready()
	Description:
		Node lifecycle callback. Prepares the audio playback and the internal Buffer.
	Behavior:
		- Starts the AudioStreamPlayer (Player.play()).
		- Retrieves and stores the playback handle (playback).
		- Allocates and zero-fills Buffer to a default length (Fs * 1).
	Notes:
		Called automatically by Godot when the node enters the scene tree.
	Returns:
		void
	"""
	Player.play()
	playback = Player.get_stream_playback()
	Buffer.resize(Buffer_size)
	Buffer.fill(0.0)
	

func receive_message(message):
	"""
	Function: receive_message(message)
	Parameters:
		message (Array): An array of message objects/dictionaries. Each message is expected to contain at least:
			- Soundtype: String ("HiHat", "Kick", "Snare", "Square", "Bass", ...)
			- Duration: float (seconds)
			- Volume: float (0.0..1.0 or similar)
			- Frequency: float (for tone-based instruments, optional)
	Description:
		Message dispatcher that iterates over incoming messages, calls the appropriate Play_* routines to mix sounds
		into the Buffer, then pushes the next block of samples from Buffer into the AudioStreamPlayback and rotates Buffer.
	Behavior:
		- For each message in the array, calls the matching Play_* helper based on Soundtype.
		- After handling messages, pushes Fs * s_per_sub samples from Buffer into playback via push_frame(Vector2.ONE * sample).
		- Rotates Buffer forward by Fs * s_per_sub samples so new generated audio appears at the end of the buffer.
	Notes / Assumptions:
		- Messages must be arrays of objects with the expected fields; unknown Soundtype values are ignored (no explicit error handling).
		- Pushing uses a stereo Vector2 derived from a single-channel Buffer value (duplicated).
	Returns:
		void
	"""
	
	if message is Array:
		for m in message:
			if m != null:
				if m.Soundtype == "HiHat":
					Play_HiHat(m.Duration, m.Volume)

				elif m.Soundtype == "Kick":
					Play_Kick(m.Duration, m.Volume)
				
				elif m.Soundtype == "Snare":
					Play_Snare(m.Duration, m.Volume)
				
				elif m.Soundtype == "Square":
					Play_SquareWave(m.Duration, m.Frequency, m.Volume)

				elif m.Soundtype == "Bass":
					Play_Bass(m.Duration, m.Frequency, m.Volume)
				
				

		for i in range(Fs*s_per_sub):
			playback.push_frame(Vector2.ONE * Buffer[i])

		Buffer = rotate_array(Buffer, Fs*s_per_sub)
		# print(" %4.1f%% error" % abs(round(100 * ((Time.get_ticks_msec() - temps) - s_per_sub*1000) / (s_per_sub*1000.0))))  # affichage du delta temporel en ms
		temps = Time.get_ticks_msec()



func rotate_array(arr: Array, offset: int) -> Array:
	"""
	Function: rotate_array(arr: Array, offset: int) -> Array
	Parameters:
		arr (Array): Source array to rotate/shift.
		offset (int): Integer offset applied when selecting source indices for the result.
	Description:
		Produces a new array of the same size where the element at index i is taken from arr[i + offset] if that index is in bounds;
		otherwise the element is set to 0.0.
	Behavior:
		- Allocates a result array sized to match arr.
		- For each destination index i, computes src_index = i + offset.
		- If src_index is within [0, size-1], copies arr[src_index], else fills 0.0.
	Use cases:
		- Used by receive_message() to advance/rotate the mixing buffer after samples are consumed/pushed.
	Notes:
		- The function returns a new Array and does not mutate the input arr.
		- If arr.size() == 0, returns a duplicate of arr.
	Returns:
		Array: New shifted/rotated array with zero padding for out-of-range indices.
	"""
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


func Noise(duration):
	"""
	Function: Noise(duration)
	Parameters:
		duration (float): Duration in seconds of noise to generate.
	Description:
		Generates a white-noise array of length int(duration * Fs) with random values in the range [0.0, 1.0).
	Usage:
		Commonly used as the basis for hi-hat/snare noise components and mixed with tonal elements.
	Notes:
		- Relies on global Fs for sample-rate conversion.
		- Random distribution is uniform from randf().
	Returns:
		Array[float]: Array of noise samples.
	"""
	var n = int(duration * Fs)
	var out = []
	out.resize(n)
	for i in range(n):
		out[i] = randf()
	return out

func SineWave(duration, frequency=440.0):
	"""
	Function: SineWave(duration, frequency=440.0)
	Parameters:
		duration (float): Seconds of audio to generate.
		frequency (float): Frequency in Hz (default 440.0).
	Description:
		Generates a sinusoidal tone sampled at Fs for the given duration and frequency.
	Behavior:
		- Produces n = int(duration * Fs) samples using sin(2 * PI * f * t).
	Returns:
		Array[float]: Array of sine wave samples.
	Notes:
		- Phase starts at 0 for sample i = 0.
	"""
	var n = int(duration * Fs)
	var out = range(n)
	for i in range(n):
		out[i] = sin(i * 2.0 * PI * frequency / Fs)       
	return out

func Chirp(duration, start_frequency=50.0, end_frequency=10.0, wave="sawtooth", volume=1.0):
	"""
	Function: Chirp(duration, start_frequency=50.0, end_frequency=10.0, wave="sawtooth", volume=1.0)
	Parameters:
		duration (float): Duration in seconds.
		start_frequency (float): Frequency at t = 0.
		end_frequency (float): Frequency at t = duration.
		wave (String): Type of instantaneous waveform. Supported: "sine", "square", "sawtooth" (default "sawtooth").
		volume (float): Amplitude multiplier applied to the generated samples.
	Description:
		Generates a frequency-modulated signal (linear chirp) whose instantaneous frequency linearly interpolates
		from start_frequency to end_frequency over the duration. The instantaneous waveform per sample depends on the
		'wave' parameter:
		- "sine": sin(2π * f_inst * t)
		- "square": sign(sin(2π * f_inst * t))
		- "sawtooth": a sawtooth approximation using a fractional part expression.
	Behavior:
		- Computes time t = i / Fs for each sample and uses linear interpolation for instantaneous_frequency.
		- Applies volume scaling to the output samples.
	Returns:
		Array[float]: Array of chirp samples (length int(duration * Fs)).
	Notes:
		- For long durations or high frequencies, aliasing may occur since no anti-aliasing is applied.
	"""
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

func Decay(duration, tau=1.0):
	"""
	Function: Decay(duration, tau=1.0)
	Parameters:
		duration (float): Total duration in seconds.
		tau (float): Time constant (in seconds) controlling decay rate (default 1.0).
	Description:
		Produces a normalized exponential decay envelope of length n = int(duration * Fs).
		The envelope is normalized so the first sample equals 1.0 and the tail is scaled to avoid offset bias.
	Formula:
		out[i] = (1 - i/n)**(tau)
	Usage:
		Used as amplitude envelopes for instrument hits (hi-hat, kick, etc.).
	Returns:
		Array[float]: Decay envelope samples, starting at 1.0 and falling toward 0.0.
	Notes:
		- When tau is high the decay is fast; for small tau it is slow; If tau = 1.0 decay is linear.
	"""
	var n = int(duration * Fs)
	var out = range(n)
	for i in range(n):
		out[i] = (1 - (i+1)/float(n))**(tau)
	return out

func add_arrays(arr1: Array, arr2: Array) -> Array:
	"""
	Function: add_arrays(arr1: Array, arr2: Array) -> Array
	Parameters:
		arr1 (Array): First numeric array.
		arr2 (Array): Second numeric array (should be the same length as arr1).
	Description:
		Returns a new array where each element is the element-wise sum arr1[i] + arr2[i].
	Assumptions / Warnings:
		- The implementation assumes arr1 and arr2 have at least arr1.size() elements; no explicit bounds checking is performed.
	Returns:
		Array[float]: Element-wise sum of arr1 and arr2.
	"""
	var result = []
	for i in range(arr1.size()):
		result.append(arr1[i] + arr2[i])
	return result

func multiply_array(arr1: Array, arr2: Array) -> Array:
	"""
	Function: multiply_array(arr: Array, scalar: float) -> Array
	Parameters:
		arr1 (Array): Input numeric array.
		arr2 (Array): Input numeric array.
		both arrays should be the same length.
	Description:
		Returns a new array where each element is arr1[i] * arr2[i].
	Returns:
		Array[float]: Scaled array.
	"""
	var result = []
	for i in range(arr1.size()):
		result.append(arr1[i] * arr2[i])
	return result

func lowpass_iir(samples: Array, cutoff_hz: float) -> Array:
	"""
	Function: lowpass_iir(samples: Array, cutoff_hz: float) -> Array
	Parameters:
		samples (Array): Input sample array (single-channel floats).
		cutoff_hz (float): Cutoff frequency in Hz for the one-pole IIR low-pass filter.
	Description:
		Applies a simple single-pole IIR low-pass filter to the input samples and returns the filtered result.
	Filter details:
		- rc = 1 / (2π * cutoff_hz)
		- dt = 1 / Fs
		- alpha = dt / (rc + dt)
		- y[n] = y[n-1] + alpha * (x[n] - y[n-1])
	Behavior:
		- The filter is causal and initialized with last = samples[0].
	Returns:
		Array[float]: Filtered output samples.
	Notes:
		- For cutoff_hz <= 0 the behavior is undefined; avoid invalid cutoff values.
		- Uses global Fs for dt.
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


func Play_HiHat(duration, volume = 1.0):
	"""
	Function: Play_HiHat(duration, volume = 1.0)
	Parameters:
		duration (float): Duration in seconds of the hi-hat hit.
		volume (float): Amplitude multiplier.
	Description:
		Synthesizes a hi-hat sound by:
		- Generating white noise for the requested duration.
		- Applying a high-cut lowpass filter (cutoff ≈ 10000 Hz).
		- Applying a fast exponential decay envelope (tau ≈ 16.0 s).
		- Mixing the resulting samples into the beginning of the Buffer (or up to Buffer size).
	Behavior:
		- If the generated sample array is longer than Buffer, only Buffer.size() samples are mixed; otherwise all samples are mixed.
	Returns:
		void (mixes into global Buffer)
	Notes:
		- The hi-hat uses noise as its primary component and a short decay to simulate percussive metallic timbre.
	"""
	var out = lowpass_iir(Noise(duration), 10000.0)
	var decay = Decay(duration, 16.0)

	if Buffer.size() < out.size():
		for i in range(Buffer.size()):
			out[i] *= decay[i] * volume
			Buffer[i] += out[i]
	else :
		for i in range(out.size()):
			out[i] *= decay[i] * volume
			Buffer[i] += out[i]

func Play_Kick(duration, volume = 1.0):
	"""
	Function: Play_Kick(duration, volume = 1.0)
	Parameters:
		duration (float): Duration in seconds of the kick hit.
		volume (float): Amplitude multiplier.
	Description:
		Synthesizes a kick drum by:
		- Generating a low-frequency sawtooth chirp from ~40 Hz down to ~10 Hz (adds pitch sweep).
		- Adding noise to give transient/body.
		- Applying a lowpass filter (cutoff ≈ 200 Hz) to focus energy in the low frequencies.
		- Applying an exponential decay envelope (tau ≈ 4.5 s).
		- Mixing the resulting samples into the Buffer.
	Behavior:
		- If generated output is longer than Buffer, mixes only up to Buffer.size(); otherwise mixes all generated samples.
	Returns:
		void (mixes into global Buffer)
	Notes:
		- The kick is band-limited by the lowpass filter to reduce high-frequency content.
	"""
	var out = lowpass_iir(add_arrays(Chirp(duration, 40.0, 10.0, "sawtooth", 1.0), Noise(duration)), 200.0)
	var decay = Decay(duration, 4.5)

	if Buffer.size() < out.size():
		for i in range(Buffer.size()):
			out[i] *= decay[i] * volume
			Buffer[i] += out[i]
	else :
		for i in range(out.size()):
			out[i] *= decay[i] * volume
			Buffer[i] += out[i]

func Play_Snare(duration, volume = 1.0):
	"""
	Function: Play_Snare(duration, volume = 1.0)
	Parameters:
		duration (float): Duration in seconds of the snare hit.
		volume (float): Amplitude multiplier.
	Description:
		Synthesizes a snare by:
		- Generating white noise for the requested duration.
		- Applying an exponential decay envelope (default tau from Decay, 1.5 s if not overridden).
		- Mixing the decayed noise into Buffer as the snare's noisy component.
	Behavior:
		- Uses the same Buffer-size checks as other Play_* functions to avoid out-of-range writes.
	Returns:
		void (mixes into global Buffer)
	Notes:
		- This simple snare implementation is purely noise-based; no tonal body is added here.
	"""
	var out = Noise(duration)
	var decay = Decay(duration, 1.5)

	if Buffer.size() < out.size():
		for i in range(Buffer.size()):
			out[i] *= decay[i] * volume
			Buffer[i] += out[i]
	else :
		for i in range(out.size()):
			out[i] *= decay[i] * volume
			Buffer[i] += out[i]

func Play_SquareWave(duration, frequency, volume = 1.0):
	"""
	Function: Play_SquareWave(duration, frequency, volume = 1.0)
	Parameters:
	duration (float): Duration in seconds.
	frequency (float): Fundamental frequency in Hz.
	volume (float): Amplitude multiplier.
	Description:
	Synthesizes a square-wave-like tone by:
	- Generating a chirp with identical start and end frequency and wave type "square" to produce a steady square wave.
	- Applying a lowpass filter with cutoff ≈ 5000 Hz to reduce harsh harmonics.
	- Applying a slow exponential decay envelope (tau = 1.0 s) to shape amplitude over time.
	- Mixing the result into Buffer.
	Behavior:
	- If the generated output is longer than Buffer, mixes only up to Buffer.size(); otherwise mixes all generated samples.
	Returns:
	void (mixes into global Buffer)
	Notes:
	- The square wave is approximated via sign(sin()) and then low-passed to smooth the waveform.
	- Long tau produces a sustained note unless duration is short.
	"""
	var out = lowpass_iir(Chirp(duration, frequency, frequency, "square", 1.0), 5000.0)
	var out_bis = lowpass_iir(Chirp(duration, 4.02*frequency, 4*frequency, "square", 1.0), 5000.0)
	var decay = Decay(duration, 1.0)

	if Buffer.size() < out.size():
		for i in range(Buffer.size()):
			out[i] *= decay[i] * volume * out_bis[i]
			Buffer[i] += out[i]
	else :
		for i in range(out.size()):
			out[i] *= decay[i] * volume * out_bis[i]
			Buffer[i] += out[i]

func Play_Bass(duration, frequency, volume = 1.0):
	"""
	Function: Play_Bass(duration, frequency, volume = 1.0)
	Parameters:
		duration (float): Duration in seconds.
		frequency (float): Fundamental frequency in Hz.
		volume (float): Amplitude multiplier.
	Description:
		Synthesizes a bass tone by:
		- Generating a sawtooth chirp with constant frequency equal to the given frequency.
		- Applying a lowpass filter with cutoff ≈ 5000 Hz.
		- Applying an exponential decay envelope (tau = 1.0 s).
		- Mixing the resulting samples into Buffer.
	Behavior:
		- If generated output is longer than Buffer, mixes only up to Buffer.size(); otherwise mixes all generated samples.
	Notes / Potential Issue:
		- The implementation multiplies each sample by decay[0] (the first envelope sample) rather than decay[i].
		This will apply a constant scaling instead of a per-sample envelope. It is likely intended to use decay[i].
	Returns:
		void (mixes into global Buffer)
	"""
	var out = lowpass_iir(Chirp(duration, frequency, frequency, "sawtooth", 1.0), 5000.0)
	var out_bis = lowpass_iir(Chirp(duration, 2*frequency, 1.995*frequency, "square", 1), 5000.0)
	var decay = Decay(duration, 1.0)

	if Buffer.size() < out.size():
		for i in range(Buffer.size()):
			out[i] *= decay[0] * volume * out_bis[i]
			Buffer[i] += out[i]
	else :
		for i in range(out.size()):
			out[i] *= decay[0] * volume * out_bis[i]
			Buffer[i] += out[i]


	

		
