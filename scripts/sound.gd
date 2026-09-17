extends Node

## Every sound in the game, in one place, so a missing file is a quiet game
## rather than a crash. Files are dropped into assets/audio by the `sfx` tool,
## which also records where each one came from in SOURCES.md.

const CLIPS := {
	"shutter": "res://assets/audio/shutter.wav",
	"dial": "res://assets/audio/dial.wav",
	"ambience": "res://assets/audio/ambience.wav",
	"rooster": "res://assets/audio/rooster.wav",
}

var _players: Dictionary = {}
var _ambience: AudioStreamPlayer

func _ready() -> void:
	for key in CLIPS:
		var stream: AudioStream = load(CLIPS[key]) if ResourceLoader.exists(CLIPS[key]) else null
		if stream == null:
			continue
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = "Master"
		add_child(player)
		_players[key] = player
	_ambience = _players.get("ambience")
	if _ambience and _ambience.stream is AudioStreamWAV:
		(_ambience.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

func play(key: String, volume_db: float = 0.0) -> void:
	var player: AudioStreamPlayer = _players.get(key)
	if player == null:
		return
	player.volume_db = volume_db
	player.play()

func start_ambience() -> void:
	if _ambience and not _ambience.playing:
		_ambience.volume_db = -14.0
		_ambience.play()

func stop_ambience() -> void:
	if _ambience:
		_ambience.stop()

## The rooster goes off now and then rather than on a loop, because a kampung
## morning is mostly quiet and the crow is the thing that places it.
func crow_occasionally(delta: float) -> void:
	_crow_clock -= delta
	if _crow_clock <= 0.0:
		_crow_clock = randf_range(22.0, 48.0)
		play("rooster", -12.0)

var _crow_clock: float = 12.0
