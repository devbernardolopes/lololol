@tool
class_name Entity
extends BaseScene

enum State {
	IDLE,
	WALK,
	RUN,
	AIRBORNE,
}

@export var playable: bool = false:
	set(v):
		playable = v
@export var move_speed: float = 400.0
@export var run_speed: float = 600.0
@export var run_animation_speed: float = 1.5
@export var acceleration: float = 1400.0
@export var run_acceleration: float = 2100.0
@export var deceleration: float = 1800.0
@export var jump_velocity: float = -400.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.08
@export var hit_points: int = 1

const ANIMATION_IDLE: StringName = &"idle"
const ANIMATION_WALK: StringName = &"walk"
const ANIMATION_JUMP: StringName = &"jump"

var controller: EntityController = null
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var state: State = State.IDLE
var _last_state: State = State.IDLE
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0


func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		if playable:
			if not controller:
				controller = Helper.find_control(self, "PlayerController")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var direction := Vector2.ZERO
	if controller:
		direction = controller.get_move_intent()

	var was_on_floor: bool = is_on_floor()

	# --- Jump buffer ---
	if playable and Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	# --- Coyote time ---
	if was_on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	# --- Gravity + variable jump height ---
	if was_on_floor:
		velocity.y = 0.0
	else:
		velocity.y += gravity * delta
		if playable and Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y = 0.0

	# --- Horizontal movement: accelerate toward the target speed, decay when no input ---
	var run_active: bool = playable and Input.is_action_pressed("run") and was_on_floor
	var target_speed: float = move_speed
	if run_active:
		target_speed = run_speed
	if direction.x != 0.0:
		velocity.x = _approach(velocity.x, direction.x * target_speed, delta, run_acceleration if run_active else acceleration)
	else:
		velocity.x = _approach(velocity.x, 0.0, delta, deceleration)

	# --- Jump ---
	if playable and _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_jump_buffer_timer = 0.0
		velocity.y = jump_velocity
		state = State.AIRBORNE
		_play_state_animation()

	move_and_slide()

	# --- State transitions ---
	if is_on_floor():
		velocity.y = 0.0
		if direction.x == 0.0:
			state = State.IDLE
		elif Input.is_action_pressed("run"):
			state = State.RUN
		else:
			state = State.WALK
	else:
		state = State.AIRBORNE

	if visual and direction.x != 0.0:
		visual.flip_h = direction.x < 0.0

	_play_state_animation()


static func _approach(current: float, target: float, delta: float, _acceleration: float) -> float:
	var step: float = _acceleration * delta
	var difference: float = target - current
	if absf(difference) <= step:
		return target
	return current + signf(difference) * step


func _play_animation(animation: StringName, speed: float = 1.0) -> void:
	if visual:
		if visual.sprite_frames.has_animation(animation):
			visual.play(animation, speed)


func _play_state_animation() -> void:
	if state == _last_state:
		return
	_last_state = state
	match state:
		State.IDLE:
			_play_animation(ANIMATION_IDLE, 1.0)
		State.WALK:
			_play_animation(ANIMATION_WALK, 1.0)
		State.RUN:
			_play_animation(ANIMATION_WALK, run_animation_speed)
		State.AIRBORNE:
			_play_animation(ANIMATION_JUMP, 1.0)
