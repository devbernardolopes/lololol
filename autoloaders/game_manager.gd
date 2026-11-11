extends Node


func _input(event: InputEvent) -> void:
	if event.is_action("escape"):
		get_tree().quit()
