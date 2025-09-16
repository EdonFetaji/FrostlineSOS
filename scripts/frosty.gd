# FrostFX.gd
extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
var mat: ShaderMaterial
var t := 0.0

func _ready() -> void:
	mat = overlay.material as ShaderMaterial
	if mat == null:
		push_error("FrostFX: ShaderMaterial missing on Overlay")
	# ensure full-rect in case layout wasn’t set
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if mat:
		t += delta
		mat.set_shader_parameter("time", t)

func set_freeze(amount: float) -> void:
	if mat:
		mat.set_shader_parameter("freeze", clamp(amount, 0.0, 1.0))
