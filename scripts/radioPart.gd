extends Area3D

signal collected(part_name: String)

@export var part_name: String = "Radio Part"

@onready var sphere_shape: CollisionShape3D = $CollisionShape3D
@onready var highlight: Node3D = $Highlight
@onready var ring: MeshInstance3D = $Highlight/Ring

var _player: Node = null
var _in_range: bool = false

# Highlight anim state
var _highlight_active: bool = false
var _spin_speed: float = 3.0      # radians/sec
var _pulse_amp: float = 0.08      # +/- scale amount
var _pulse_speed: float = 2.5     # Hz-ish
var _t: float = 0.0

func _ready() -> void:
	if not is_in_group("RadioPart"):
		add_to_group("RadioPart")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Start hidden
	if ring:
		ring.visible = false
	set_process(true)

func _process(delta: float) -> void:
	if _highlight_active and ring and highlight:
		_t += delta
		# spin the highlight
		highlight.rotate_y(_spin_speed * delta)
		# soft pulse
		var s := 1.0 + sin(_t * TAU * 0.5 * _pulse_speed) * _pulse_amp
		ring.scale = Vector3.ONE * s

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player = body
		_in_range = true
		_show_prompt(true)
		_set_highlight(true)

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_in_range = false
		_player = null
		_show_prompt(false)
		_set_highlight(false)

func _unhandled_input(event: InputEvent) -> void:
	if _in_range and event.is_action_pressed("collect"):
		var d := global_position.distance_to(_player.global_position)
		var radius := 1.0
		if sphere_shape and sphere_shape.shape is SphereShape3D:
			radius = (sphere_shape.shape as SphereShape3D).radius
		if d <= radius + 0.01:
			_collect()

func _collect() -> void:
	collected.emit(part_name)

	if _player and _player.has_method("play_collect_animation"):
		_player.play_collect_animation()

	var game := get_tree().root.get_node_or_null("Game")
	if game:
		if game.has_method("add_radio_part"):
			game.add_radio_part(part_name)
		if game.has_method("show_interact_prompt"):
			game.show_interact_prompt(false, "", self)
			
	queue_free()


func _show_prompt(show: bool) -> void:
	var game := get_tree().root.get_node_or_null("Game")
	if game and game.has_method("show_interact_prompt"):
		var text := "[C] Pick up %s" % part_name
		game.show_interact_prompt(show, text, self)

func _set_highlight(enable: bool) -> void:
	_highlight_active = enable
	_t = 0.0
	if ring:
		ring.visible = enable

# Optional: lets Game re-query text when multiple in range
func get_part_prompt_text() -> String:
	return "[C] Pick up %s" % part_name
