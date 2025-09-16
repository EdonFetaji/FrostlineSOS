extends CharacterBody3D

# ----------------- Tuning -----------------
@export var SPEED: float = 10.0
@export var JUMP_VELOCITY: float = 8.0
@export var GRAVITY: float = 24.0
@export var MOUSE_SENSITIVITY: float = 0.002

# Ice feel (only used while inside an IceZone)
@export var ice_speed_mult_default: float = 0.65
@export var accel_ice_default: float = 4.0
@export var decel_ice_default: float = 2.0

# Diagnostics
@export var INVERT_LR: bool = false
@export var INVERT_FB: bool = false

# Some models need 180 here
@export var MESH_YAW_OFFSET_DEG: float = 0.0

# Pick-up anim name (matches your list)
@export var PICKUP_ANIM: String = "Pickup"

# Optional: briefly freeze input during pickup (polish)
@export var FREEZE_DURING_PICKUP: bool = false

# Ice state
var on_ice: bool = false
var ice_speed_mult: float = 1.0
var accel_current: float = 4.0
var decel_current: float = 2.0

# Animation lock so movement anims don't override one-shot pickup
var _anim_lock: bool = false
var _anim_lock_timer: float = 0.0
var _pickup_freeze_until: float = 0.0

@onready var camera_controller: Node3D = $Camera_Controller
@onready var model_pivot: Node3D = $Barbarian
@onready var anim_player: AnimationPlayer = $Barbarian/AnimationPlayer

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if not is_in_group("Player"):
		add_to_group("Player")
	# default ice params
	accel_current = accel_ice_default
	decel_current = decel_ice_default

	if not anim_player:
		push_error("AnimationPlayer not found! Check node path.")
	else:
		print("Animations:", anim_player.get_animation_list())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		camera_controller.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

func _physics_process(delta: float) -> void:
	# -------- Vertical (gravity/jump) --------
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("ui_accept"):
		velocity.y = JUMP_VELOCITY
		if anim_player:
			anim_player.play("Jump_Full_Short")

	# -------- Input (camera-relative) --------
	var input_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if INVERT_LR: input_vec.x = -input_vec.x
	if INVERT_FB: input_vec.y = -input_vec.y

	var now := Time.get_ticks_msec() / 1000.0
	if FREEZE_DURING_PICKUP and now < _pickup_freeze_until:
		input_vec = Vector2.ZERO

	var cam_basis := camera_controller.global_transform.basis
	var forward := -cam_basis.z; forward.y = 0; forward = forward.normalized()
	var right := -cam_basis.x;   right.y = 0; right = right.normalized()
	var move_dir := (right * input_vec.x + forward * input_vec.y).normalized()

	# -------- Horizontal movement --------
	if on_ice:
		# SLIDE ONLY ON ICE (accel/decel + reduced max speed)
		var max_speed := SPEED * ice_speed_mult
		var target := Vector2(move_dir.x, move_dir.z) * max_speed
		var v := Vector2(velocity.x, velocity.z)
		if target.length() > 0.001:
			v = v.move_toward(target, accel_current * delta)
		else:
			v = v.move_toward(Vector2.ZERO, decel_current * delta)
		velocity.x = v.x
		velocity.z = v.y
	else:
		# ORIGINAL GROUND FEEL + cold slowdown (never as slow as ice)
		var cold_mult := 1.0
		var game := get_tree().root.get_node_or_null("Game")
		if game and game.has_method("get_cold_speed_mult"):
			cold_mult = game.get_cold_speed_mult()

		if move_dir != Vector3.ZERO:
			velocity.x = move_dir.x * SPEED * cold_mult
			velocity.z = move_dir.z * SPEED * cold_mult
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)


	# -------- Facing --------
	if on_ice:
		var face_dir := move_dir
		if face_dir == Vector3.ZERO:
			var hv := Vector3(velocity.x, 0.0, velocity.z)
			if hv.length() > 0.01:
				face_dir = hv.normalized()
		if face_dir != Vector3.ZERO:
			var target_yaw := atan2(face_dir.x, face_dir.z) + deg_to_rad(MESH_YAW_OFFSET_DEG)
			model_pivot.rotation.y = lerp_angle(model_pivot.rotation.y, target_yaw, 10.0 * delta)
	else:
		if move_dir != Vector3.ZERO:
			var target_yaw := atan2(move_dir.x, move_dir.z) + deg_to_rad(MESH_YAW_OFFSET_DEG)
			model_pivot.rotation.y = lerp_angle(model_pivot.rotation.y, target_yaw, 10.0 * delta)

	# -------- Animations --------
	# keep a short lock so the pickup anim isn't overridden by walk/idle
	if _anim_lock:
		_anim_lock_timer -= delta
		if _anim_lock_timer <= 0.0 or not anim_player.is_playing():
			_anim_lock = false

	if anim_player and anim_player.current_animation != "Jump_Full_Short" and not _anim_lock:
		if on_ice:
			if Vector2(velocity.x, velocity.z).length() > 0.2:
				anim_player.play("Walking_A")
			else:
				anim_player.play("Idle")
		else:
			if move_dir != Vector3.ZERO:
				anim_player.play("Walking_A")
			else:
				anim_player.play("Idle")

	move_and_slide()

	# Smooth camera follow
	camera_controller.position = lerp(camera_controller.position, position, 0.15)

# =====================  Ice API (called by IceZone)  =====================

func apply_ice_zone(speed_mult: float, accel_on_ice: float, decel_on_ice: float) -> void:
	on_ice = true
	ice_speed_mult = (speed_mult if speed_mult > 0.0 else ice_speed_mult_default)
	accel_current = (accel_on_ice if accel_on_ice > 0.0 else accel_ice_default)
	decel_current = (decel_on_ice if decel_on_ice > 0.0 else decel_ice_default)

func clear_ice_zone() -> void:
	on_ice = false
	ice_speed_mult = 1.0
	# ground movement instantly goes back original behavior

# =====================  Pick-up animation API  =====================

func play_collect_animation() -> void:
	if not anim_player:
		return
	var anim_name := PICKUP_ANIM
	var found := anim_player.has_animation(anim_name)
	if not found:
		for alt in ["Pickup", "Interact", "Use Item", "Gather", "Pick_Up", "Use"]:
			if anim_player.has_animation(alt):
				anim_name = alt
				found = true
				break
	if not found:
		return  # no suitable animation found; skip

	# Play the pick-up and lock movement anim overrides for its duration
	anim_player.play(anim_name)
	var length := 0.6
	var a := anim_player.get_animation(anim_name)
	if a:
		length = max(0.1, a.length)
	_anim_lock = true
	_anim_lock_timer = length * 0.9  # slight margin so Walk/Idle resumes right after

	# briefly freeze movement input
	if FREEZE_DURING_PICKUP:
		_pickup_freeze_until = Time.get_ticks_msec() / 1000.0 + length * 0.85
