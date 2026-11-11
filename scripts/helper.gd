@tool
class_name Helper
extends Node

const BASE_ENTITY_LENGTH: float = 128.0
const BASE_ENTITY_LENGTH_BY_4: float = BASE_ENTITY_LENGTH / 4.0
const BASE_ENTITY_LENGTH_MARGIN: float = 4.0

## Full heart = 2 hit points.
const HUD_HEART = preload("res://assets/images/hud/hud_heart.png")
## Empty heart = 0 hit point.
const HUD_HEART_EMPTY = preload("res://assets/images/hud/hud_heart_empty.png")
## Half heart = 1 hit point.
const HUD_HEART_HALF = preload("res://assets/images/hud/hud_heart_half.png")


static func find_control(_parent: Node, _class_name: String, _name: StringName = &"") -> Node:
	if not _parent:
		print("not _parent")
		return null
	if not _class_name:
		print("not _class_name")
		return null
	for child: Node in _parent.get_children():
		# Try to match by the built-in class name first, then by the 
		# user-authored class_name.
		# TODO: I don't know if this is bug-prone! Must review in the future.
		if child.get_class() == _class_name:
			return child
		var _script = child.get_script()
		if _script:
			var _global_name = _script.get_global_name()
			if _global_name:
				if _global_name == _class_name:
					if _name:
						print(_name)
						
						if child.name == _name:
							return child
					else:
						return child
	return null
