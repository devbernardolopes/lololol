class_name PlayerController
extends EntityController

func get_move_intent() -> Vector2:
	var horizontal: float = Input.get_axis("left", "right")
	if horizontal == 0.0:
		return Vector2.ZERO
	var y: float = 0.0
	if InputMap.has_action("up") and Input.is_action_pressed("up"):
		y += 1.0
	elif InputMap.has_action("down") and Input.is_action_pressed("down"):
		y -= 1.0
	return Vector2(horizontal, y)


func is_jump_just_pressed() -> bool:
	return Input.is_action_just_pressed("jump")


func is_jump_just_released() -> bool:
	return Input.is_action_just_released("jump")


func is_jump_held() -> bool:
	return Input.is_action_pressed("jump")


func is_run_held() -> bool:
	return Input.is_action_pressed("run")


func is_down_held() -> bool:
	return InputMap.has_action("down") and Input.is_action_pressed("down")


func is_up_held() -> bool:
	return InputMap.has_action("up") and Input.is_action_pressed("up")
