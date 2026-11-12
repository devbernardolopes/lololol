@tool
class_name Eye
extends Node2D

const EYE = preload("res://assets/images/misc/tile_0157.png")

@export var target: Node2D = null
## The maximum distance the eye can move from its center position.
@export var radius: float = 2.5
## How fast the eye moves. Higher = snaps faster, Lower = moves smoothly.
@export var move_speed: float = 50.0 

## The center point of our circular boundary.
#var center_position: Vector2 = Vector2.ZERO
var visual: Sprite2D = null

func _ready():
	visual = Helper.find_control(self, "Visual")
	if not visual:
		visual = Sprite2D.new()
		visual.texture = EYE
		add_child(visual)


func _process(delta):
	if not visual:
		return
	if not is_instance_valid(target):
		return
	var offset = target.position - position
	var distance = offset.length()
	var clamped_distance = min(distance, radius)
	var target_pos = position
	if distance > 0:
		target_pos = position + (offset.normalized() * clamped_distance)
	position = position.move_toward(target_pos, move_speed * delta)
	visual.rotation = offset.angle()


#
#func _process(delta):
	#if not visual:
		#return
	#
	## Safety check: ensure the target still exists in the scene.
	#if not is_instance_valid(target):
		#return
#
	#if center_position == Vector2.ZERO:
		#center_position = global_position
#
	## 1. Calculate the vector and distance from the center to the target
	#var offset = target.global_position - center_position
	#var distance = offset.length()
#
	## 2. Clamp the distance to the radius
	## Note: If you want the eye to ALWAYS stay exactly on the circumference 
	## (the edge of the circle) regardless of how close the target is, 
	## change `min(distance, radius)` to just `radius`.
	#var clamped_distance = min(distance, radius)
#
	## 3. Calculate the desired position within the circle
	#var target_pos = center_position
	#if distance > 0:
		#target_pos = center_position + (offset.normalized() * clamped_distance)
#
	## 4. Move the Eye smoothly towards the target position
	## move_toward gives it a nice, consistent "walking" speed rather than teleporting
	#global_position = global_position.move_toward(target_pos, move_speed * delta)
#
	## 5. Rotate the Sprite to always point at the target
	## Note: This assumes your eye sprite is drawn facing RIGHT (positive X axis).
	## See the tip below if your sprite faces a different direction.
	#visual.rotation = offset.angle()
