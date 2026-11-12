@tool
class_name Helper
extends Node

const BASE_ENTITY_LENGTH: float = 128.0
const BASE_ENTITY_LENGTH_BY_4: float = BASE_ENTITY_LENGTH / 4.0
const BASE_ENTITY_LENGTH_MARGIN: float = 4.0

static func has_property(target: Node, property: String) -> bool:
	if not target:
		return false
	var _properties: Array[Dictionary] = target.get_property_list()
	if not _properties or _properties.is_empty():
		return false
	for i in _properties.size():
		var _p = _properties[i].get("name")
		if _p and _p is String:
			if _p == property:
				return true
	return false


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
