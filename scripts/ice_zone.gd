extends Area3D

@export var speed_mult: float = 0.65     # top speed is 65% on ice
@export var accel_on_ice: float = 4.0    # accelerate slowly
@export var decel_on_ice: float = 2.0    # brake very slowly → sliding feel

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _on_enter(body: Node) -> void:
	if body.is_in_group("Player") and body.has_method("apply_ice_zone"):
		body.apply_ice_zone(speed_mult, accel_on_ice, decel_on_ice)

func _on_exit(body: Node) -> void:
	if body.is_in_group("Player") and body.has_method("clear_ice_zone"):
		body.clear_ice_zone()
