extends Area3D

signal collected(part_name: String)

@export var part_name: String = "Radio Part"

@onready var highlight: Node3D = $Highlight
@onready var ring: MeshInstance3D = $Highlight/Ring

var _collected: bool = false
var _t: float = 0.0
var _spin_speed := 3.0     # purely visual
var _pulse_amp := 0.08
var _pulse_speed := 2.5

func _ready() -> void:
	if not is_in_group("RadioPart"):
		add_to_group("RadioPart")
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	set_process(true)

func _process(delta: float) -> void:
	# Optional: keep the nice ring spin/pulse
	if ring and highlight and not _collected:
		_t += delta
		highlight.rotate_y(_spin_speed * delta)
		var s := 1.0 + sin(_t * TAU * 0.5 * _pulse_speed) * _pulse_amp
		ring.scale = Vector3.ONE * s

func _on_body_entered(body: Node) -> void:
	# Auto-pickup the instant the Player touches the Area
	if _collected:
		return
	if body.is_in_group("Player"):
		_collect(body)

func _collect(player: Node) -> void:
	_collected = true
	collected.emit(part_name)

	# Play player's pickup animation if available (non-blocking)
	if player and player.has_method("play_collect_animation"):
		player.play_collect_animation()

	# Tell the Game to increase the counter (your existing API)
	var game := get_tree().root.get_node_or_null("Game")
	if game and game.has_method("add_radio_part"):
		game.add_radio_part(part_name)

	# Remove the object immediately
	queue_free()
