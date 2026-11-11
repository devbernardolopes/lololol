class_name PlayerController
extends EntityController

func get_move_intent() -> Vector2:
	var horizontal: float = Input.get_axis("left", "right")
	if horizontal == 0.0:
		return Vector2.ZERO
	return Vector2(horizontal, 0.0)
