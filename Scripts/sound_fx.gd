extends RefCounted
class_name SpacehaulSFX

# Shared SFX helper. Most sounds are short one-shots, while sounds such as
# explosions can opt into a shared non-stacking voice so simultaneous gameplay
# events never sum the same sample into an unexpectedly loud peak.
const SOUND_PATHS := {
	"primary": "res://Audio/SFX/primary.wav",
	"secondary": "res://Audio/SFX/secondary.wav",
	"boost": "res://Audio/SFX/boost.wav",
	"player_hurt": "res://Audio/SFX/player_hurt.wav",
	"enemy_hit": "res://Audio/SFX/enemy_hit.wav",
	"enemy_die": "res://Audio/SFX/enemy_die.wav",
	"salvage": "res://Audio/SFX/salvage.wav",
	"level": "res://Audio/SFX/level.wav",
	"warning": "res://Audio/SFX/warning.wav",
	"enemy_shot": "res://Audio/SFX/enemy_shot.wav",
	"explosion": "res://Audio/SFX/explosion_8bit.wav",
}

static func _load_stream(sound_name: String) -> AudioStream:
	if not SOUND_PATHS.has(sound_name):
		return null
	return load(String(SOUND_PATHS[sound_name])) as AudioStream

static func _resolve_host(parent: Node) -> Node:
	if parent == null or not is_instance_valid(parent):
		return null
	var tree := parent.get_tree()
	if tree != null and tree.current_scene != null:
		return tree.current_scene
	return parent

static func play(parent: Node, sound_name: String, volume_db: float = -8.0, pitch_scale: float = 1.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var stream := _load_stream(sound_name)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch_scale, 0.25, 4.0)
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

static func play_nonstacking(
	parent: Node,
	sound_name: String,
	volume_db: float = -8.0,
	pitch_scale: float = 1.0,
	min_retrigger_ms: int = 90
) -> void:
	# Reuse one AudioStreamPlayer per sound. Calling play() on this player can
	# retrigger the sound, but it cannot create a second simultaneous copy. The
	# tiny retrigger gate also collapses several explosions created on one frame
	# into one audible impact while every visual explosion still appears.
	var host := _resolve_host(parent)
	if host == null:
		return
	var stream := _load_stream(sound_name)
	if stream == null:
		return

	var player_name := "__SpacehaulSFX_%s" % sound_name
	var player := host.get_node_or_null(NodePath(player_name)) as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = player_name
		host.add_child(player)

	var now_msec := Time.get_ticks_msec()
	var last_msec := int(player.get_meta("last_play_msec", -1000000))
	if player.playing and now_msec - last_msec < maxi(0, min_retrigger_ms):
		return

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch_scale, 0.25, 4.0)
	player.set_meta("last_play_msec", now_msec)
	player.play()

static func play_explosion(parent: Node, volume_db: float = -10.5, pitch_scale: float = 1.0) -> void:
	play_nonstacking(parent, "explosion", volume_db, pitch_scale, 95)
