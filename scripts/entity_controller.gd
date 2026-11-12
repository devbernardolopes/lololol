class_name EntityController
extends Node

## Horizontal movement intent of the controlled entity. Returns a Vector2;
## the y axis is used by flying entities to move vertically.
func get_move_intent() -> Vector2:
	return Vector2.ZERO


## Whether the jump action was just pressed.
func is_jump_just_pressed() -> bool:
	return false


## Whether the jump action was just released.
func is_jump_just_released() -> bool:
	return false


## Whether the jump action is held.
func is_jump_held() -> bool:
	return false


## Whether the run action is held.
func is_run_held() -> bool:
	return false
