class_name HeartsContainer
extends Node2D

## Full heart = 2 hit points.
const HUD_HEART = preload("res://assets/images/hud/hud_heart.png")
## Empty heart = 0 hit point.
const HUD_HEART_EMPTY = preload("res://assets/images/hud/hud_heart_empty.png")
## Half heart = 1 hit point.
const HUD_HEART_HALF = preload("res://assets/images/hud/hud_heart_half.png")

@export var target: Entity = null:
	set(v):
		target = v
		_connect_signals()
		_refresh_visual()
@export var margin: float = 32.0
@export var spacing: float = 16.0


func _ready() -> void:
	if not target:
		return
	_connect_signals()
	_refresh_visual()


func _connect_signals() -> void:
	if not target.has_signal("hit_points_changed"):
		return
	if target.is_connected("hit_points_changed", _refresh_visual):
		return
	if not target.has_signal("max_hit_points_changed"):
		return
	if target.is_connected("max_hit_points_changed", _refresh_visual):
		return
	target.connect("hit_points_changed", _refresh_visual)
	target.connect("max_hit_points_changed", _refresh_visual)


func _refresh_visual() -> void:
	var children: Array[Node] = get_children()
	for child in children:
		child.queue_free()
	if not target:
		return
	if not Helper.has_property(target, "hit_points"):
		return
	if not Helper.has_property(target, "max_hit_points"):
		return
	for i in target.hit_points:
		var heart: Sprite2D = Sprite2D.new()
		heart.texture = HUD_HEART
		heart.centered = false
		heart.position.x = margin + (i * 64) + (i * spacing)
		add_child(heart)
	for i in range(target.hit_points, target.max_hit_points):
		var heart: Sprite2D = Sprite2D.new()
		heart.texture = HUD_HEART_EMPTY
		heart.centered = false
		heart.position.x = margin + (i * 64) + (i * spacing)
		add_child(heart)
