@tool
class_name Helper
extends Node

const BASE_ENTITY_LENGTH: float = 128.0
const BASE_ENTITY_LENGTH_BY_4: float = BASE_ENTITY_LENGTH / 4.0
const BASE_ENTITY_LENGTH_MARGIN: float = 4.0


static func find_control(_parent: Node, _class_name: String, _name: StringName = &"") -> Node:
	if not _parent:
		print("not _parent")
		return null
	if not _class_name:
		print("not _class_name")
		return null
	for child: Node in _parent.get_children():
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
