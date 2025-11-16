@icon("res://Scripts/musical-note.png")
## Classe contenant les données d'une note musicale.
##
## [member Instrument (string)] Pour quel instrument est cette note ? (ex : "drum", "synth", etc.)
## [br]
## [member Duration (float)] Durée de la note en secondes.
## [br]
## [member Soundtype (string)] Type de son (varie selon l'instrument : "sine", "square", "noise" pour un synthé, "kick", "snare" pour une batterie, etc.).
## [br]
## [member Frequency (float = 440.0)] Fréquence de la note (Hz).
## [br]
## [member Volume (float = 1.0)] Volume de la note (0.0 à 1.0).
## [br]
## Exemple d'utilisation :
##
## [code]var my_note = Note.new("synth", 0.5, 12.0, "sine", 0.8)[/code]
class_name Note

var Instrument: String          ## [Instrument (string)] Pour quel instrument est cette note ? (ex : "drum", "synth", etc.)     
var Duration: float             ## [Duration (float)] Durée de la note en secondes.
var Soundtype: String           ## [Soundtype (string)] Type de son (varie selon l'instrument : "sine", "square", "noise" pour un synthé, "kick", "snare" pour une batterie, etc.).
var Frequency: float = 440.0    ## [Frequency (float = 440.0)] Fréquence de la note (Hz).      
var Volume: float = 1.0         ## [Volume (float = 1.0)] Volume de la note (0.0 à 1.0).

func _init(_Instrument: String, _Duration: float, _SoundType: String, _Frequency: float = 440.0, _Volume: float = 1.0):
	Instrument = _Instrument
	Duration = _Duration
	Soundtype = _SoundType
	Frequency = _Frequency
	Volume = _Volume
	
