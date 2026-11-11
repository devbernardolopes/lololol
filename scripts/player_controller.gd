class_name PlayerController
extends EntityController

func get_move_intent() -> Vector2:
	var input_vector: Vector2 = Input.get_vector("left", "right", "up", "down")
	if input_vector.is_zero_approx():
		return Vector2.ZERO
	return input_vector
