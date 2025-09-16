extends Node3D

# ----- HUD refs -----
@onready var parts_label: Label = $HUD/RadioParts/PartsLabel
@onready var hud: CanvasLayer = $HUD
@onready var interact_prompt: Panel = $HUD/Interactive
@onready var thermo_text: Label = $HUD/Temp/Label
@onready var thermo_bar: ProgressBar = $HUD/ThermoBar
@onready var end_game: Control = $EndGame
@onready var end_game_msg: Label = $EndGame/Message
@onready var game_result: Label = $EndGame/GameState
@onready var frost_fx: CanvasLayer = $FrostFX

# ----- Collectibles -----
var total_parts: int = 5
var collected_parts: int = 0
var _interact_stack: Array[Node] = []

# ----- Cold / timer settings -----
@export var cold_duration_sec: float = 180.0
@export var temperature_start_c: float = -5.0
@export var temperature_end_c: float = -40.0

@export var cold_min_speed_mult: float = 0.80   # must be > ice multiplier
@export var cold_log_curve: float = 4.0         

var elapsed: float = 0.0
var game_over: bool = false

func _ready() -> void:
	interact_prompt.visible = false
	if end_game:
		end_game.visible = false

	# Connect existing pickups by group
	var parts: Array[Node] = get_tree().get_nodes_in_group("RadioPart")
	total_parts = parts.size()
	for p in parts:
		if p.has_signal("collected") and not p.collected.is_connected(_on_part_collected):
			p.collected.connect(_on_part_collected)

	_update_hud()
	_update_thermo_ui(_current_temperature())

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_end_game(false)
		
	if game_over:
		return
	# advance cold timer
	elapsed += delta
	elapsed = clamp(elapsed, 0.0, cold_duration_sec)
	if frost_fx:
		frost_fx.call("set_freeze", _current_progress()*1.2)
	# update HUD thermometer
	var temp: float = _current_temperature()
	_update_thermo_ui(temp)

	# time up -> end game (win if all parts already collected)
	if is_time_up():
		_end_game(collected_parts >= total_parts)

func _current_progress() -> float:
	# 0.0 (start/warm) -> 1.0 (too cold)
	return clamp(elapsed / cold_duration_sec, 0.0, 1.0)

func _current_temperature() -> float:
	return lerp(temperature_start_c, temperature_end_c, _current_progress())

func _update_thermo_ui(temp_c: float) -> void:
	if thermo_text:
		thermo_text.text = "%.0f°C" % temp_c
	if thermo_bar:
		thermo_bar.value = temp_c  # bar min=-40, max=-5

func is_time_up() -> bool:
	return elapsed >= cold_duration_sec

# ----- Exposed to Player: how cold slows movement (logarithmic) -----
func get_cold_speed_mult() -> float:
	var p: float = _current_progress()
	var a: float = max(0.001, cold_log_curve)
	var s: float = log(1.0 + a * p) / log(1.0 + a)  # 0..1 (concave)
	var mult: float = 1.0 - s * (1.0 - cold_min_speed_mult)
	return clamp(mult, cold_min_speed_mult, 1.0)

# ----- Collectibles / HUD -----
func _on_part_collected(_part_name: String) -> void:
	collected_parts += 1
	_update_hud()
	if collected_parts >= total_parts:
		_end_game(true)

func _update_hud() -> void:
	if parts_label:
		parts_label.text = "%d / %d" % [collected_parts, total_parts]

# Called by RadioPart to show/hide the HUD prompt
func show_interact_prompt(show: bool, text: String, source: Node = null) -> void:
	if show:
		if source and not _interact_stack.has(source):
			_interact_stack.append(source)
		interact_prompt.visible = true
	else:
		if source:
			_interact_stack.erase(source)
		if _interact_stack.is_empty():
			interact_prompt.visible = false
		else:
			interact_prompt.visible = true

func _on_player_anim_finished(anim_name: StringName) -> void:
	var player: Node = get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var anim: AnimationPlayer = player.get_node_or_null("Barbarian/AnimationPlayer")
	if anim == null:
		return

	if anim_name == "Cheer":
		anim.play("Cheer")

	if anim_name == "Death_A":
		anim.play("Death_A_Pose")

func _setup_endgame_animations(victory: bool) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return

	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	if player.has_method("set_process"):
		player.set_process(false)

	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO

	# Play the one-shot end animation (no loops, no pose queuing)
	var anim: AnimationPlayer = player.get_node_or_null("Barbarian/AnimationPlayer")
	if anim == null:
		return
	if victory:
		anim.play("Cheer")
	else:
		anim.play("Death_A")


func _end_game(victory: bool) -> void:
	if game_over:
		return
	game_over = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Show overlay, hide only the interact prompt
	if end_game:
		end_game.visible = true
	if interact_prompt:
		interact_prompt.visible = false

	# Set texts
	if end_game_msg:
		end_game_msg.text = ("Активиран сигнал – Спасен си!" if victory else "Се е смрзнато! Обиди се повторно…")
	if game_result:
		game_result.text = ("YOU WIN" if victory else "GAME OVER")

	# Play end animation (tree NOT paused)
	_setup_endgame_animations(victory)

	if game_over:
		return
	game_over = true

	self.process_mode = Node.PROCESS_MODE_ALWAYS  # <- keep this script alive after pause
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if end_game:
		end_game.visible = true
		end_game.process_mode = Node.PROCESS_MODE_ALWAYS
	if interact_prompt:
		interact_prompt.visible = false

	if end_game_msg:
		end_game_msg.text = ("Активиран сигнал – Спасен си!" if victory else "Се е смрзнато! Обиди се повторно…")
	if game_result:
		game_result.text = ("YOU WIN" if victory else "GAME OVER")

	_setup_endgame_animations(victory)
	get_tree().paused = true
