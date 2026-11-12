@tool
extends Node2D

@onready var visual: AnimatedSprite2D = $Visual


func _ready() -> void:
	if not visual:
		return
	visual.play(&"on")
