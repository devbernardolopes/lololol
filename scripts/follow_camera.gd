@tool
class_name FollowCamera
extends Camera2D
## Follows the active player entity.

@export var target: Node2D = null:
	set(v):
		if target == v:
			return
		target = v
		if not Engine.is_editor_hint():
			snap_to_target()

## Fixed framing zoom applied on entering the tree.
@export var base_zoom: float = 1.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	visible = true
	enabled = true
	zoom = Vector2.ONE * base_zoom
	position_smoothing_enabled = false
	snap_to_target()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if target == null or not is_instance_valid(target):
		return
	global_position = target.global_position


func snap_to_target() -> void:
	if Engine.is_editor_hint():
		return
	if target == null or not is_instance_valid(target):
		return
	global_position = target.global_position
	reset_smoothing()
