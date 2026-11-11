@tool
class_name BaseScene
extends CharacterBody2D

@export_tool_button("Refresh") var refresh: Callable = _refresh_visual
@export var data: BaseData = null:
	set(v):
		data = v
		_refresh_visual()

var visual: AnimatedSprite2D = null
var collision: CollisionShape2D = null
var occluder: LightOccluder2D = null


func _ready() -> void:
	visual = Helper.find_control(self, "AnimatedSprite2D")
	if not visual:
		visual = AnimatedSprite2D.new()
		add_child(visual)
	collision = Helper.find_control(self, "CollisionShape2D", &"Collision")
	print(collision)
	if not collision:
		collision = CollisionShape2D.new()
		collision.shape = CapsuleShape2D.new()
		(collision.shape as CapsuleShape2D).radius = Helper.BASE_ENTITY_LENGTH_BY_4
		(collision.shape as CapsuleShape2D).height = Helper.BASE_ENTITY_LENGTH - Helper.BASE_ENTITY_LENGTH_MARGIN
		add_child(collision)
	occluder = Helper.find_control(self, "LightOccluder2D")
	if not occluder:
		occluder = LightOccluder2D.new()
		occluder.occluder = OccluderPolygon2D.new()
		occluder.occluder.polygon = [ 
				Vector2.ZERO - Vector2.ONE * Helper.BASE_ENTITY_LENGTH_BY_4, 
				Vector2(Helper.BASE_ENTITY_LENGTH_BY_4, Helper.BASE_ENTITY_LENGTH_BY_4 * -1.0), 
				Vector2.ONE * Helper.BASE_ENTITY_LENGTH_BY_4, 
				Vector2(Helper.BASE_ENTITY_LENGTH_BY_4 * -1.0, Helper.BASE_ENTITY_LENGTH_BY_4), 
				]
		add_child(occluder)
	occluder.show_behind_parent = true
	occluder.occluder.cull_mode = OccluderPolygon2D.CULL_COUNTER_CLOCKWISE
	_refresh_visual()


func _refresh_visual() -> void:
	if not data:
		return
	if not data.visual:
		return
	if not visual:
		return
	visual.sprite_frames = data.visual
	if visual.sprite_frames.has_animation(&"idle"):
		visual.play(&"idle")
