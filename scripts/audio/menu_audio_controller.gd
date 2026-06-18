class_name MenuAudioController
extends Node

const DEFAULT_INSTANCE_NAME: StringName = &"MenuAudio"
const DEFAULT_MUSIC_STREAM: AudioStream = preload("res://assets/audio/music/race_loop_arcade_drift.mp3")

@export var menu_music_stream: AudioStream = DEFAULT_MUSIC_STREAM
@export var hover_stream: AudioStream = null
@export var click_stream: AudioStream = null
@export var music_bus: StringName = &"Master"
@export var sfx_bus: StringName = &"Master"
@export_range(-48.0, 6.0, 0.1) var music_volume_db: float = -17.5
@export_range(-48.0, 6.0, 0.1) var hover_volume_db: float = -18.0
@export_range(-48.0, 6.0, 0.1) var click_volume_db: float = -12.0
@export_range(0.0, 2.0, 0.01) var default_music_fade_seconds: float = 0.55
@export_range(0.01, 2.0, 0.01) var ui_pitch_variation: float = 0.04

var _music_player: AudioStreamPlayer = null
var _hover_player: AudioStreamPlayer = null
var _click_player: AudioStreamPlayer = null
var _music_tween: Tween = null
var _bound_roots: Array[NodePath] = []


static func resolve(context: Node) -> MenuAudioController:
	if context == null:
		return null

	var tree := context.get_tree()
	if tree == null:
		return null

	for autoload_name: String in [String(DEFAULT_INSTANCE_NAME), "MenuAudioController"]:
		var autoload_instance := context.get_node_or_null("/root/%s" % autoload_name) as MenuAudioController
		if autoload_instance != null:
			return autoload_instance

	var root := tree.root
	var existing := root.get_node_or_null(String(DEFAULT_INSTANCE_NAME)) as MenuAudioController
	if existing != null:
		return existing

	var controller: Node = load("res://scripts/audio/menu_audio_controller.gd").new()
	controller.name = DEFAULT_INSTANCE_NAME
	root.add_child(controller)
	return controller as MenuAudioController


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_players()


func play_menu_music(fade_seconds: float = -1.0) -> void:
	_ensure_players()
	if _music_player == null or menu_music_stream == null:
		return

	_music_player.stream = menu_music_stream
	_music_player.bus = String(music_bus)
	_set_stream_loop(_music_player.stream, true)

	var fade_time := default_music_fade_seconds if fade_seconds < 0.0 else fade_seconds
	if fade_time <= 0.0:
		_music_player.volume_db = music_volume_db
		if not _music_player.playing:
			_music_player.play()
		return

	if _music_tween != null:
		_music_tween.kill()
	if not _music_player.playing:
		_music_player.volume_db = -60.0
		_music_player.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", music_volume_db, fade_time)


func stop_menu_music(fade_seconds: float = -1.0) -> void:
	if _music_player == null or not _music_player.playing:
		return

	var fade_time := default_music_fade_seconds if fade_seconds < 0.0 else fade_seconds
	if _music_tween != null:
		_music_tween.kill()
	if fade_time <= 0.0:
		_music_player.stop()
		return

	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -60.0, fade_time)
	_music_tween.tween_callback(Callable(_music_player, "stop"))


func play_hover() -> void:
	_play_ui_sfx(_hover_player, hover_stream, hover_volume_db, 1.0)


func play_click() -> void:
	_play_ui_sfx(_click_player, click_stream, click_volume_db, 1.0)


func bind_buttons(root: Node) -> void:
	if root == null:
		return

	var root_path := root.get_path()
	if not _bound_roots.has(root_path):
		_bound_roots.append(root_path)
		var child_entered_callable := Callable(self, "_on_bound_root_child_entered_tree")
		if not root.child_entered_tree.is_connected(child_entered_callable):
			root.child_entered_tree.connect(child_entered_callable)

	_bind_buttons_recursive(root)


func bind_button(button: BaseButton) -> void:
	if button == null:
		return

	var hover_callable := Callable(self, "play_hover")
	if not button.mouse_entered.is_connected(hover_callable):
		button.mouse_entered.connect(hover_callable)
	if not button.focus_entered.is_connected(hover_callable):
		button.focus_entered.connect(hover_callable)

	var click_callable := Callable(self, "play_click")
	if not button.pressed.is_connected(click_callable):
		button.pressed.connect(click_callable)


func _ensure_players() -> void:
	if _music_player == null:
		_music_player = _make_player("MenuMusic", menu_music_stream, music_bus, music_volume_db)
	if _hover_player == null:
		hover_stream = hover_stream if hover_stream != null else _make_tone_stream(940.0, 0.045, 0.22)
		_hover_player = _make_player("MenuHover", hover_stream, sfx_bus, hover_volume_db)
	if _click_player == null:
		click_stream = click_stream if click_stream != null else _make_tone_stream(620.0, 0.075, 0.35, 0.45)
		_click_player = _make_player("MenuClick", click_stream, sfx_bus, click_volume_db)


func _make_player(player_name: String, stream: AudioStream, bus_name: StringName, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.bus = String(bus_name)
	player.volume_db = volume_db
	player.max_polyphony = 4
	add_child(player)
	return player


func _play_ui_sfx(player: AudioStreamPlayer, stream: AudioStream, volume_db: float, base_pitch: float) -> void:
	_ensure_players()
	if player == null:
		return

	player.stream = stream
	player.bus = String(sfx_bus)
	player.volume_db = volume_db
	player.pitch_scale = base_pitch + randf_range(-ui_pitch_variation, ui_pitch_variation)
	player.stop()
	player.play()


func _bind_buttons_recursive(root: Node) -> void:
	if root is BaseButton:
		bind_button(root as BaseButton)
	for child: Node in root.get_children():
		_bind_buttons_recursive(child)


func _on_bound_root_child_entered_tree(child: Node) -> void:
	for root_path: NodePath in _bound_roots:
		var root := get_node_or_null(root_path)
		if root != null and (child == root or root.is_ancestor_of(child)):
			_bind_buttons_recursive(child)
			return


func _make_tone_stream(frequency_hz: float, duration_seconds: float, amplitude: float, downward_sweep: float = 0.0) -> AudioStreamWAV:
	var mix_rate := 44100
	var sample_count := int(float(mix_rate) * duration_seconds)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	for sample_index: int in range(sample_count):
		var t := float(sample_index) / float(mix_rate)
		var progress := float(sample_index) / maxf(float(sample_count - 1), 1.0)
		var envelope := sin(progress * PI)
		var sweep_frequency := lerpf(frequency_hz, frequency_hz * downward_sweep, progress) if downward_sweep > 0.0 else frequency_hz
		var sample := sin(TAU * sweep_frequency * t) * envelope * amplitude
		var pcm := int(clampf(sample, -1.0, 1.0) * 32767.0)
		if pcm < 0:
			pcm = 65536 + pcm
		bytes[sample_index * 2] = pcm & 0xff
		bytes[sample_index * 2 + 1] = (pcm >> 8) & 0xff

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = bytes
	return stream


func _set_stream_loop(stream: AudioStream, should_loop: bool) -> void:
	if stream == null:
		return
	for property: Dictionary in stream.get_property_list():
		if String(property.get("name", "")) == "loop":
			stream.set("loop", should_loop)
			return
