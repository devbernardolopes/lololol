@tool
class_name Entity
extends BaseScene

@export var playable: bool = false:
	set(v):
		playable = v

var controller: EntityController = null


func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		if playable:
			if not controller:
				controller = Helper.find_control(self, "PlayerController")
	## In-game, game-related rules and stuff.
