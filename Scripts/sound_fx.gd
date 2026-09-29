extends RefCounted
class_name SpacehaulSFX

# Shared SFX helper. One-shots are hosted by the current scene rather than by
# the gameplay node that triggered them. This prevents a source enemy/projectile
# being freed from cutting its sound short, and PROCESS_MODE_ALWAYS lets a sound
# that already started finish cleanly if the game pauses on the same frame.
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

# Dense swarm events can legitimately happen many times on one frame. Playing
# every copy simultaneously makes them sound like false/repeating triggers, so
# collapse only near-simultaneous copies while preserving later distinct events.
const BURST_RETRIGGER_MS := {
	"enemy_hit": 45,
	"enemy_die": 70,
	"enemy_shot": 55,
	"salvage": 35,
}

static func _load_stream(sound_name: String) -> AudioStream:
	if not SOUND_PATHS.has(sound_name):
		return null
	return load(String(SOUND_PATHS[sound_name])) as AudioStream

static func _resolve_host(parent: Node) -> Node:
	if parent == null or not is_instance_valid(parent):
		return null
	var tree := parent.get_tree()
	if tree != null and tree.current_scene != null and is_instance_valid(tree.current_scene):
		if not tree.current_scene.is_queued_for_deletion():
			return tree.current_scene
	if parent.is_inside_tree() and not parent.is_queued_for_deletion():
		return parent
	return null

static func _play_nonstacking_on_host(
	host: Node,
	sound_name: String,
	stream: AudioStream,
	volume_db: float,
	pitch_scale: float,
	min_retrigger_ms: int
) -> void:
	if host == null or not is_instance_valid(host):
		return

	var player_name := "__SpacehaulSFX_%s" % sound_name
	var player := host.get_node_or_null(NodePath(player_name)) as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = player_name
		# A sound that has already been triggered should finish even if gameplay is
		# paused immediately afterward (level-up, game over, deck transfer).
		player.process_mode = Node.PROCESS_MODE_ALWAYS
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

static func play(parent: Node, sound_name: String, volume_db: float = -8.0, pitch_scale: float = 1.0) -> void:
	var host := _resolve_host(parent)
	if host == null:
		return
	var stream := _load_stream(sound_name)
	if stream == null:
		return

	if BURST_RETRIGGER_MS.has(sound_name):
		_play_nonstacking_on_host(
			host,
			sound_name,
			stream,
			volume_db,
			pitch_scale,
			int(BURST_RETRIGGER_MS[sound_name])
		)
		return

	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch_scale, 0.25, 4.0)
	host.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

# Explicit alias for UI/transition call sites. All one-shots already use an
# always-processing scene host, so this mainly documents intent at the caller.
static func play_ui(parent: Node, sound_name: String, volume_db: float = -8.0, pitch_scale: float = 1.0) -> void:
	play(parent, sound_name, volume_db, pitch_scale)

static func play_nonstacking(
	parent: Node,
	sound_name: String,
	volume_db: float = -8.0,
	pitch_scale: float = 1.0,
	min_retrigger_ms: int = 90
) -> void:
	var host := _resolve_host(parent)
	if host == null:
		return
	var stream := _load_stream(sound_name)
	if stream == null:
		return
	_play_nonstacking_on_host(
		host,
		sound_name,
		stream,
		volume_db,
		pitch_scale,
		min_retrigger_ms
	)

static func play_explosion(parent: Node, volume_db: float = -10.5, pitch_scale: float = 1.0) -> void:
	play_nonstacking(parent, "explosion", volume_db, pitch_scale, 95)
