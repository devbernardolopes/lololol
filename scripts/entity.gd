@tool
class_name Entity
extends BaseScene

enum State {
	IDLE,
	WALK,
	RUN,
	AIRBORNE,
	FLY,
	HIT,
	DUCK,
}

enum Team {
	PLAYER,
	ENEMY,
	NEUTRAL,
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
@export_range(0.0, 1.0, 0.05) var slope_jump_assist: float = 0.25
@export var jump_buffer_distance: float = 24.0
@export var hit_points: int = 1

@export var flying: bool = false
@export var hover_amplitude: float = 0.0
@export var hover_frequency: float = 1.0

## When true, this entity may drop through terrain tiles by pressing "down"
## while jumping from the ground (fall-through).
@export var can_drop_through: bool = false
## Horizontal speed used while the entity is ducking.
@export var duck_speed: float = 200.0
## Downward fall speed used while dropping through terrain.
@export var drop_through_speed: float = 450.0

@export var team: Team = Team.ENEMY
@export var contact_damage: int = 0
@export var stompable: bool = false
@export var can_stomp: bool = false
@export var stomp_damage: int = 1
@export var stomp_bounce_velocity: float = -300.0
@export var stomp_tolerance: float = 12.0
@export var invulnerability_time: float = 0.0
@export var hit_stun_time: float = 0.25
@export var knockback_velocity: Vector2 = Vector2(250.0, -200.0)
@export var death_linger_time: float = 0.4

const ANIMATION_IDLE: StringName = &"idle"
const ANIMATION_WALK: StringName = &"walk"
const ANIMATION_JUMP: StringName = &"jump"
const ANIMATION_FLY: StringName = &"fly"
const ANIMATION_HIT: StringName = &"hit"
const ANIMATION_DUCK: StringName = &"duck"
const STOMP_GRACE_TIME: float = 0.25
## How far below the collision shape one-way tiles are searched when a drop starts.
const DROP_SEED_EXPANSION: float = 12.0
## Maximum distance between polygon vertices of two tiles for them to be connected.
const DROP_VERTEX_MERGE_DISTANCE: float = 3.0
## Safety cap for the number of one-way tiles in a single drop set.
const DROP_MAX_CELLS: int = 128
## Safety timeout for a single drop, in seconds.
const DROP_TIMEOUT: float = 1.0
## Horizontal margin used when testing whether the entity has cleared the slope.
const DROP_X_MARGIN: float = 1.0
## Mask for the plain alternative tile id (the upper bits hold flip/transpose flags).
const TILE_ALTERNATIVE_ID_MASK: int = 0xFFF

signal damaged(amount: int, source: Entity)
signal died(source: Entity)
signal stomped(victim: Entity)
signal contact_started(other: Entity)
signal contact_ended(other: Entity)

var controller: EntityController = null
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var hurtbox: Area2D = null
var facing: float = 1.0

var state: State = State.IDLE
var _last_state: State = State.IDLE
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _previous_bottom_y: float = 0.0
var _contacts: Array[Entity] = []
var _stomp_grace_timer: float = 0.0
var _invulnerability_timer: float = 0.0
var _hit_stun_timer: float = 0.0
var _death_linger_timer: float = 0.0
var _is_dead: bool = false
var _original_visual_y: float = 0.0
var _drop_through: bool = false
var _drop_elapsed: float = 0.0
var _drop_layers: Array[TileMapLayer] = []
var _drop_cells: Dictionary = {}
var _drop_polygons: Array[Dictionary] = []
var _drop_vertices: PackedVector2Array = PackedVector2Array()
var _is_ducking: bool = false
var _base_collision_shape: Shape2D = null
var _duck_collision_shape: Shape2D = null
var _duck_collision_shape_position: Vector2 = Vector2.ZERO
var _base_collision_shape_position: Vector2 = Vector2.ZERO
var _base_collision_rotation: float = 0.0
var _collision_mirrored: bool = false
var _base_collision_mask: int = 1


func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		if flying:
			motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		else:
			floor_snap_length = 16.0
			floor_max_angle = deg_to_rad(50.0)
			floor_constant_speed = true
		if controller == null:
			controller = _find_controller()
		if visual != null:
			_original_visual_y = visual.position.y
		_base_collision_mask = collision_mask
		_base_collision_shape = collision.shape
		_base_collision_shape_position = collision.position
		_base_collision_rotation = collision.rotation
		if collision.shape is CapsuleShape2D:
			var base_capsule: CapsuleShape2D = collision.shape as CapsuleShape2D
			var duck_capsule := CapsuleShape2D.new()
			duck_capsule.radius = base_capsule.radius # * 0.5
			duck_capsule.height = base_capsule.height # * 0.5
			duck_capsule.height = maxf(duck_capsule.height, duck_capsule.radius * 2.0)
			_duck_collision_shape = duck_capsule
			_duck_collision_shape_position = Vector2(
				collision.position.x,
				collision.position.y - (base_capsule.height - duck_capsule.height) * 0.5
			)
		_setup_hurtbox()
		if team == Team.PLAYER:
			add_to_group(&"player")
		elif team == Team.ENEMY:
			add_to_group(&"enemy")
		_play_state_animation()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_previous_bottom_y = get_body_rect().end.y
	# --- Hover bob for flying entities: shifts the visual only, never the body ---
	if flying and hover_amplitude > 0.0 and visual != null:
		visual.position.y = _original_visual_y + sin(Time.get_ticks_msec() * 0.001 * TAU * hover_frequency) * hover_amplitude
	# --- Timers ---
	_stomp_grace_timer = maxf(_stomp_grace_timer - delta, 0.0)
	_invulnerability_timer = maxf(_invulnerability_timer - delta, 0.0)
	if visual != null:
		if _invulnerability_timer > 0.0:
			visual.modulate.a = 0.35
		elif visual.modulate.a < 1.0:
			visual.modulate.a = 1.0
	_hit_stun_timer = maxf(_hit_stun_timer - delta, 0.0)
	_death_linger_timer = maxf(_death_linger_timer - delta, 0.0)
	if _death_linger_timer <= 0.0 and _is_dead and team != Team.PLAYER:
		queue_free()
	# --- Intents ---
	var direction: Vector2 = Vector2.ZERO
	var intents_active: bool = controller != null and not _intents_blocked()
	if intents_active:
		direction = controller.get_move_intent()
	var was_on_floor: bool = is_on_floor()
	var run_active: bool = controller != null and controller.is_run_held() and (was_on_floor or flying)
	var target_speed: float = move_speed
	if run_active:
		target_speed = run_speed
	if _is_ducking:
		target_speed = duck_speed
	# --- Jump buffer ---
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	if controller != null and intents_active and controller.is_jump_just_pressed() and (is_on_floor() or _coyote_timer > 0.0 or _is_near_floor() or _is_near_stompable()):
		_jump_buffer_timer = jump_buffer_time
	# --- Coyote time ---
	if was_on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	# --- Gravity + variable jump height ---
	if was_on_floor:
		velocity.y = 0.0
	elif not flying:
		velocity.y += gravity * delta
		if controller != null and controller.is_jump_just_released() and velocity.y < 0.0:
			velocity.y = 0.0
	# --- Horizontal movement ---
	if intents_active and not flying:
		if direction.x != 0.0:
			velocity.x = _approach(velocity.x, direction.x * target_speed, delta, run_acceleration if run_active else acceleration)
		else:
			velocity.x = _approach(velocity.x, 0.0, delta, deceleration)
	elif intents_active and flying:
		if direction != Vector2.ZERO:
			velocity = _approach_vector(velocity, direction * target_speed, delta, run_acceleration if run_active else acceleration)
		else:
			velocity = _approach_vector(velocity, Vector2.ZERO, delta, deceleration)
	# --- Jump ---
	if not flying and not _drop_through and intents_active and _jump_buffer_timer > 0.0 and (is_on_floor() or _coyote_timer > 0.0):
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_apply_jump()
		state = State.AIRBORNE
		_play_state_animation()
	if can_drop_through and not flying and controller != null and intents_active and controller.is_jump_just_pressed() and controller.is_down_held() and (was_on_floor or _coyote_timer > 0.0) and not _drop_through:
		_start_drop_through()
	if _drop_through and not flying:
		_update_drop_through(delta)
	if _drop_through and not flying:
		collision_mask = 0
	move_and_slide()
	_process_contacts()
	if _drop_through and not flying:
		collision_mask = _base_collision_mask
	# --- State transitions ---
	if _hit_stun_timer > 0.0:
		state = State.HIT
	elif flying:
		state = State.FLY if direction.x != 0.0 else State.IDLE
	elif is_on_floor():
		if controller != null and not flying and controller.is_down_held():
			_set_ducking(true)
			state = State.DUCK
		else:
			_set_ducking(false)
			if direction.x == 0.0:
				state = State.IDLE
			elif run_active:
				state = State.RUN
			else:
				state = State.WALK
	else:
		state = State.AIRBORNE
	if visual != null and direction.x != 0.0:
		visual.flip_h = direction.x < 0.0
	if direction.x != 0.0:
		facing = direction.x
		_update_collision_facing()
	_play_state_animation()


static func _approach(current: float, target: float, delta: float, _acceleration: float) -> float:
	var step: float = _acceleration * delta
	var difference: float = target - current
	if absf(difference) <= step:
		return target
	return current + signf(difference) * step


static func _approach_vector(current: Vector2, target: Vector2, delta: float, _acceleration: float) -> Vector2:
	var result: Vector2 = current
	result.x = _approach(current.x, target.x, delta, _acceleration)
	result.y = _approach(current.y, target.y, delta, _acceleration)
	return result


func _play_animation(animation: StringName, speed: float = 1.0) -> void:
	if visual != null:
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
		State.DUCK:
			_play_animation(ANIMATION_DUCK, 1.0)
		State.AIRBORNE:
			_play_animation(ANIMATION_JUMP, 1.0)
		State.FLY:
			_play_animation(ANIMATION_FLY, 1.0)
		State.HIT:
			_play_animation(ANIMATION_HIT, 1.0)


## Starts a jump. When jumping while climbing a slope, the horizontal speed is
## matched to the real motion along the slope and a fraction of the slope's
## rise speed is added, so the jump isn't swallowed by the ground rising with us.
func _apply_jump() -> void:
	velocity.y = jump_velocity
	if not is_on_floor():
		return
	var normal: Vector2 = get_floor_normal()
	if normal.x * velocity.x >= 0.0:
		return # flat ground or descending
	velocity.x *= absf(normal.y)
	var slope_rise: float = velocity.x * normal.x / -normal.y # negative = going up
	velocity.y += slope_jump_assist * slope_rise


## Starts a drop-through: the entity falls through the whole connected one-way
## surface it is standing on instead of landing on it.
func _start_drop_through() -> void:
	if not _build_drop_set():
		return
	_drop_through = true
	_drop_elapsed = 0.0
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	velocity.y = drop_through_speed
	state = State.AIRBORNE
	_play_state_animation()


## Ends an active drop-through and restores normal terrain collision.
func _end_drop_through() -> void:
	if not _drop_through:
		return
	_drop_through = false
	_drop_elapsed = 0.0
	_drop_layers.clear()
	_drop_cells.clear()
	_drop_polygons.clear()
	_drop_vertices = PackedVector2Array()
	collision_mask = _base_collision_mask


## Builds the set of one-way tiles that make up the surface being dropped
## through. Returns false when there is no one-way tile below the entity.
func _build_drop_set() -> bool:
	_drop_layers.clear()
	_drop_cells.clear()
	_drop_polygons.clear()
	_drop_vertices = PackedVector2Array()
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false
	_collect_tile_map_layers(scene)
	if _drop_layers.is_empty():
		return false

	var body_rect: Rect2 = get_body_rect()
	var seed_rect := Rect2(
		body_rect.position,
		body_rect.size + Vector2(0.0, DROP_SEED_EXPANSION)
	)
	var pending: Array[Dictionary] = []
	for layer: TileMapLayer in _drop_layers:
		for coords: Vector2i in layer.get_used_cells():
			if _drop_cells.size() >= DROP_MAX_CELLS:
				break
			var polygons: Array[PackedVector2Array] = _get_cell_drop_polygons(layer, coords)
			if polygons.is_empty():
				continue
			var touches_body: bool = false
			for points: PackedVector2Array in polygons:
				if _points_aabb(points).intersects(seed_rect):
					touches_body = true
					break
			if not touches_body:
				continue
			if _add_drop_cell(layer, coords, polygons):
				pending.append({"layer": layer, "coords": coords})

	if _drop_cells.is_empty():
		return false

	# Flood fill across the connected surface, possibly over several layers.
	var index: int = 0
	while index < pending.size() and _drop_cells.size() < DROP_MAX_CELLS:
		var current: Dictionary = pending[index]
		index += 1
		var current_layer: TileMapLayer = current["layer"]
		var current_coords: Vector2i = current["coords"]
		var world_center: Vector2 = current_layer.to_global(current_layer.map_to_local(current_coords))
		for layer: TileMapLayer in _drop_layers:
			var layer_coords: Vector2i = layer.local_to_map(layer.to_local(world_center))
			for offset_x: int in range(-1, 2):
				for offset_y: int in range(-1, 2):
					if _drop_cells.size() >= DROP_MAX_CELLS:
						break
					var coords: Vector2i = layer_coords + Vector2i(offset_x, offset_y)
					if _drop_cells.has(_drop_cell_key(layer, coords)):
						continue
					var polygons: Array[PackedVector2Array] = _get_cell_drop_polygons(layer, coords)
					if polygons.is_empty():
						continue
					if not _are_drop_polygons_connected(polygons):
						continue
					if _add_drop_cell(layer, coords, polygons):
						pending.append({"layer": layer, "coords": coords})
	return true


func _collect_tile_map_layers(node: Node) -> void:
	if node is TileMapLayer and (node as TileMapLayer).tile_set != null:
		_drop_layers.append(node as TileMapLayer)
	for child: Node in node.get_children():
		_collect_tile_map_layers(child)


func _add_drop_cell(layer: TileMapLayer, coords: Vector2i, polygons: Array[PackedVector2Array]) -> bool:
	var key: String = _drop_cell_key(layer, coords)
	if _drop_cells.has(key):
		return false
	_drop_cells[key] = true
	for points: PackedVector2Array in polygons:
		_drop_polygons.append({"points": points, "aabb": _points_aabb(points)})
		_drop_vertices.append_array(points)
	return true


static func _points_aabb(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point: Vector2 = points[0]
	var max_point: Vector2 = points[0]
	for point: Vector2 in points:
		min_point = Vector2(minf(min_point.x, point.x), minf(min_point.y, point.y))
		max_point = Vector2(maxf(max_point.x, point.x), maxf(max_point.y, point.y))
	return Rect2(min_point, max_point - min_point)


func _drop_cell_key(layer: TileMapLayer, coords: Vector2i) -> String:
	return "%d:%d:%d" % [layer.get_instance_id(), coords.x, coords.y]


## Whether any vertex of the candidate polygons is close to a vertex already
## in the drop set. This is what connects flat, 27 and 45 degree slope tiles.
func _are_drop_polygons_connected(polygons: Array[PackedVector2Array]) -> bool:
	var max_distance_squared: float = DROP_VERTEX_MERGE_DISTANCE * DROP_VERTEX_MERGE_DISTANCE
	for points: PackedVector2Array in polygons:
		for vertex: Vector2 in points:
			for existing: Vector2 in _drop_vertices:
				if vertex.distance_squared_to(existing) <= max_distance_squared:
					return true
	return false


## World-space one-way collision polygons of a tile, with the cell transform
## flags applied. Empty when the cell has no one-way collision.
func _get_cell_drop_polygons(layer: TileMapLayer, coords: Vector2i) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var tile_set: TileSet = layer.tile_set
	if tile_set == null:
		return result

	var alternative_id: int = layer.get_cell_alternative_tile(coords)
	var flip_h: bool = (alternative_id & TileSetAtlasSource.TRANSFORM_FLIP_H) != 0
	var flip_v: bool = (alternative_id & TileSetAtlasSource.TRANSFORM_FLIP_V) != 0
	var transpose: bool = (alternative_id & TileSetAtlasSource.TRANSFORM_TRANSPOSE) != 0
	var plain_alternative_id: int = alternative_id & TILE_ALTERNATIVE_ID_MASK
	var source_id: int = layer.get_cell_source_id(coords)
	if source_id < 0:
		return result
	var source: TileSetSource = tile_set.get_source(source_id)
	if not (source is TileSetAtlasSource):
		return result
	var tile_data: TileData = (source as TileSetAtlasSource).get_tile_data(
		layer.get_cell_atlas_coords(coords), plain_alternative_id
	)
	if tile_data == null:
		return result
	flip_h = flip_h or tile_data.flip_h
	flip_v = flip_v or tile_data.flip_v
	transpose = transpose or tile_data.transpose

	var cell_local_origin: Vector2 = layer.map_to_local(coords)
	for physics_layer: int in range(tile_set.get_physics_layers_count()):
		var polygon_count: int = tile_data.get_collision_polygons_count(physics_layer)
		for polygon_index: int in range(polygon_count):
			if not tile_data.is_collision_polygon_one_way(physics_layer, polygon_index):
				continue
			var points: PackedVector2Array = tile_data.get_collision_polygon_points(physics_layer, polygon_index)
			if points.is_empty():
				continue
			var world_points: PackedVector2Array = PackedVector2Array()
			world_points.resize(points.size())
			for point_index: int in range(points.size()):
				world_points[point_index] = layer.to_global(
					cell_local_origin + _transform_tile_point(
						points[point_index], flip_h, flip_v, transpose
					)
				)
			result.append(world_points)
	return result


static func _transform_tile_point(point: Vector2, _flip_h: bool, _flip_v: bool, _transpose: bool) -> Vector2:
	var transformed: Vector2 = point
	if _transpose:
		transformed = Vector2(transformed.y, transformed.x)
	if _flip_h:
		transformed.x = -transformed.x
	if _flip_v:
		transformed.y = -transformed.y
	return transformed


## Advances an active drop. The set is cleared once the entity has passed below
## its lowest tile, or when the motion test finds a collider that is not part
## of the drop set (solid ground or an unrelated platform).
func _update_drop_through(delta: float) -> void:
	_drop_elapsed += delta
	if _drop_elapsed >= DROP_TIMEOUT:
		_end_drop_through()
		return
	if _drop_set_is_cleared():
		_end_drop_through()
		return
	if _drop_has_foreign_blocker(delta):
		_end_drop_through()


func _drop_set_is_cleared() -> bool:
	var body_rect: Rect2 = get_body_rect()
	var lowest_bottom: float = -INF
	var has_overlapping_polygon: bool = false
	for record: Dictionary in _drop_polygons:
		var aabb: Rect2 = record["aabb"]
		if aabb.end.x < body_rect.position.x - DROP_X_MARGIN:
			continue
		if aabb.position.x > body_rect.end.x + DROP_X_MARGIN:
			continue
		has_overlapping_polygon = true
		lowest_bottom = maxf(lowest_bottom, aabb.end.y)
	if not has_overlapping_polygon:
		return true
	return body_rect.end.y > lowest_bottom


func _drop_has_foreign_blocker(delta: float) -> bool:
	# PhysicsTestMotionParameters2D has no collision mask in Godot 4.7: the
	# body's own mask is used. It is still _base_collision_mask here because
	# the drop mask is only zeroed around move_and_slide().
	var params: PhysicsTestMotionParameters2D = PhysicsTestMotionParameters2D.new()
	params.recovery_as_collision = true
	# The 2D motion result only reports the nearest hit, so walk down the
	# sweep to collect up to 8 obstacles.
	var motion: Vector2 = Vector2(0.0, maxf(velocity.y * delta, jump_buffer_distance))
	var from: Transform2D = global_transform
	for step: int in range(8):
		params.from = from
		params.motion = motion
		var result: PhysicsTestMotionResult2D = PhysicsTestMotionResult2D.new()
		if not PhysicsServer2D.body_test_motion(get_rid(), params, result):
			return false
		var collider: Object = result.get_collider()
		if not (collider is TileMapLayer):
			return true
		var layer: TileMapLayer = collider as TileMapLayer
		var coords: Vector2i = layer.get_coords_for_body_rid(result.get_collider_rid())
		if not _drop_cells.has(_drop_cell_key(layer, coords)):
			return true
		# Move past the accepted tile to look for anything below it.
		var travel: Vector2 = result.get_travel()
		from.origin += travel
		motion -= travel
		if motion.length_squared() <= 0.0001:
			return false
		var nudge: float = maxf(result.get_collision_depth(), 0.5) + 1.0
		var nudge_vector: Vector2 = motion.normalized() * nudge
		from.origin += nudge_vector
		motion -= nudge_vector
		if motion.length_squared() <= 0.0001:
			return false
	return false


## Mirrors the collision shape when the entity faces away from the direction
## its art was authored in (playable art faces east, enemy art faces west).
func _update_collision_facing() -> void:
	var faces_east: bool = facing >= 0.0
	var should_mirror: bool = faces_east != playable
	if should_mirror == _collision_mirrored:
		return
	_collision_mirrored = should_mirror
	_apply_collision_shape_transform()
	_sync_hurtbox_transform()


func _apply_collision_shape_transform() -> void:
	if collision == null:
		return
	var use_duck_shape: bool = _is_ducking and _duck_collision_shape != null
	var shape_position: Vector2 = _duck_collision_shape_position if use_duck_shape else _base_collision_shape_position
	var shape_rotation: float = _base_collision_rotation
	if _collision_mirrored:
		shape_position.x = -shape_position.x
		shape_rotation = -shape_rotation
	collision.position = shape_position
	collision.rotation = shape_rotation


func _sync_hurtbox_transform() -> void:
	if hurtbox == null or collision == null:
		return
	for child: Node in hurtbox.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).transform = collision.transform
			return


## Enables or disables the duck hitbox shape.
func _set_ducking(value: bool) -> void:
	if _is_ducking == value:
		return
	_is_ducking = value
	if collision == null:
		return
	if value:
		if _duck_collision_shape != null:
			collision.debug_color = Color.RED
			collision.shape = _duck_collision_shape
			_apply_collision_shape_transform()
	else:
		collision.debug_color = Color(0.0, 0.6, 0.702, 0.42)
		collision.shape = _base_collision_shape
		_apply_collision_shape_transform()
	_sync_hurtbox_shape()


func _sync_hurtbox_shape() -> void:
	if hurtbox == null:
		return
	for child in hurtbox.get_children():
		if child is CollisionShape2D:
			child.shape = collision.shape
			return


func _is_near_floor() -> bool:
	return velocity.y >= 0.0 and test_move(global_transform, Vector2(0.0, jump_buffer_distance)) != null


## Returns true when the entity is falling towards a stompable hostile entity
## within the jump buffer distance below its feet.
func _is_near_stompable() -> bool:
	if flying or not can_stomp or velocity.y < 0.0:
		return false
	var query_shape: Shape2D = _get_hurtbox_shape()
	if query_shape == null:
		return false
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = query_shape
	query.transform = global_transform.translated(Vector2(0.0, jump_buffer_distance))
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = PhysicsLayers.HITBOXES
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query, 8)
	for result: Dictionary in results:
		var area: Area2D = result.get("collider")
		if area == null:
			continue
		var _owner: Node = area.get_parent()
		if _owner == self or not (_owner is Entity):
			continue
		var other: Entity = _owner as Entity
		if other.is_alive() and other.stompable and is_hostile_to(other):
			return true
	return false


func _get_hurtbox_shape() -> Shape2D:
	if hurtbox != null:
		for child in hurtbox.get_children():
			if child is CollisionShape2D:
				return (child as CollisionShape2D).shape
	if collision != null:
		return collision.shape
	return null


func _setup_hurtbox() -> void:
	hurtbox = _get_or_create_hurtbox()


func _get_or_create_hurtbox() -> Area2D:
	if hurtbox != null:
		return hurtbox
	for child in get_children():
		if child is Area2D and child.name == "Hurtbox":
			hurtbox = child
			return hurtbox
	var area: Area2D = Area2D.new()
	area.collision_layer = PhysicsLayers.HITBOXES
	area.collision_mask = PhysicsLayers.HITBOXES
	area.monitoring = true
	area.monitorable = true
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	shape_node.shape = collision.shape
	shape_node.transform = collision.transform
	area.add_child(shape_node)
	add_child(area)
	hurtbox = area
	return hurtbox


func _find_controller() -> EntityController:
	for child in get_children():
		if child is EntityController:
			return child
	return null


func _intents_blocked() -> bool:
	return _is_dead or _hit_stun_timer > 0.0


func _process_contacts() -> void:
	var current: Array[Entity] = []
	if hurtbox != null and hurtbox.monitoring:
		var overlapping: Array[Area2D] = hurtbox.get_overlapping_areas()
		for area: Area2D in overlapping:
			var _owner: Node = area.get_parent()
			if _owner == self or not (_owner is Entity):
				continue
			var other: Entity = _owner as Entity
			if not other.is_alive():
				continue
			if not current.has(other):
				current.append(other)
	var previous: Array[Entity] = _contacts.duplicate()
	_contacts.clear()
	var started: Array[Entity] = []
	for other in current:
		_contacts.append(other)
		if not previous.has(other):
			started.append(other)
	for other in previous:
		if not current.has(other):
			contact_ended.emit(other)
			if _contacts and not _contacts.is_empty():
				_contacts.remove_at(_contacts.find(other))
	for other in started:
		contact_started.emit(other)
	for other in _contacts:
		if other.get_instance_id() < get_instance_id():
			_resolve_contact(other)


func _resolve_contact(other: Entity) -> void:
	if _intents_blocked():
		return
	if other == null or not other.is_alive():
		return
	if team == Team.NEUTRAL or other.team == Team.NEUTRAL:
		return
	if team == other.team:
		return
	var stomper: Entity = null
	var victim: Entity = null
	if _is_stomp(self, other):
		stomper = self
		victim = other
	elif _is_stomp(other, self):
		stomper = other
		victim = self
	if stomper != null:
		victim.take_damage(stomper.stomp_damage, stomper)
		stomper._on_stomp(victim)
		return
	if contact_damage > 0 and is_hostile_to(other) and _stomp_grace_timer <= 0.0:
		other.take_damage(contact_damage, self)


func _is_stomp(stomper: Entity, victim: Entity) -> bool:
	if not stomper.can_stomp or not victim.stompable:
		return false
	if stomper.velocity.y <= 0.0:
		return false
	var victim_rect: Rect2 = victim.get_body_rect()
	return stomper._previous_bottom_y < victim_rect.position.y + stomp_tolerance


func _on_stomp(victim: Entity) -> void:
	var full_jump: bool = _jump_buffer_timer > 0.0 or (controller != null and controller.is_jump_held())
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	if full_jump:
		velocity.y = jump_velocity
	else:
		velocity.y = stomp_bounce_velocity
	state = State.AIRBORNE
	_play_state_animation()
	stomped.emit(victim)
	if victim.is_alive():
		_stomp_grace_timer = STOMP_GRACE_TIME


## Applies damage to this entity. Returns true when the damage was applied.
func take_damage(amount: int, source: Entity = null) -> bool:
	if _is_dead or is_invulnerable():
		return false
	hit_points -= amount
	damaged.emit(amount, source)
	if hit_points <= 0:
		die(source)
		return true
	_hit_stun_timer = hit_stun_time
	if invulnerability_time > 0.0:
		_invulnerability_timer = invulnerability_time
	apply_knockback(source.global_position if source != null else global_position)
	return true


## Applies a knockback impulse away from the source position.
func apply_knockback(from_position: Vector2) -> void:
	var direction: float = signf(global_position.x - from_position.x)
	if direction == 0.0:
		direction = -facing
	velocity = Vector2(direction * knockback_velocity.x, knockback_velocity.y)


## Whether this entity is still alive (has not died).
func is_alive() -> bool:
	return not _is_dead


## Whether this entity is currently invulnerable.
func is_invulnerable() -> bool:
	return _invulnerability_timer > 0.0


## Whether this entity is currently in hit stun.
func is_stunned() -> bool:
	return _hit_stun_timer > 0.0


## Whether this entity is hostile towards the other entity.
func is_hostile_to(other: Entity) -> bool:
	return team != Team.NEUTRAL and other.team != Team.NEUTRAL and team != other.team


## Global-space bounding rect of the collision shape.
func get_body_rect() -> Rect2:
	if collision == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var shape_rect: Rect2 = collision.shape.get_rect()
	var half_size: Vector2 = shape_rect.size * 0.5
	# Use the body transform plus the shape's local transform: collision nodes
	# with top_level enabled have a global_transform that ignores the body.
	var shape_transform: Transform2D = global_transform * collision.transform
	var corners: Array[Vector2] = [
		shape_transform * Vector2(-half_size.x, -half_size.y),
		shape_transform * Vector2(half_size.x, -half_size.y),
		shape_transform * Vector2(-half_size.x, half_size.y),
		shape_transform * Vector2(half_size.x, half_size.y),
	]
	var min_corner: Vector2 = corners[0]
	var max_corner: Vector2 = corners[0]
	for corner: Vector2 in corners:
		min_corner = Vector2(minf(min_corner.x, corner.x), minf(min_corner.y, corner.y))
		max_corner = Vector2(maxf(max_corner.x, corner.x), maxf(max_corner.y, corner.y))
	return Rect2(min_corner, max_corner - min_corner)


## Entities that are currently in contact with this entity.
func get_contacts() -> Array[Entity]:
	return _contacts


func die(source: Entity) -> void:
	if _is_dead:
		return
	_is_dead = true
	if hurtbox != null:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	died.emit(source)
	_death_linger_timer = death_linger_time
	if visual != null:
		if visual.sprite_frames.has_animation(ANIMATION_HIT):
			_play_animation(ANIMATION_HIT, 1.0)
		else:
			_play_death_squash()


func _play_death_squash() -> void:
	if visual == null:
		return
	var tween: Tween = create_tween()
	var base_position_y: float = visual.position.y
	var half_height: float = 64.0
	var texture: Texture2D = visual.sprite_frames.get_frame_texture(visual.animation, visual.frame)
	if texture != null:
		half_height = texture.get_height() * 0.5
	tween.tween_property(visual, "scale:y", 0.2, death_linger_time)
	tween.tween_property(visual, "position:y", base_position_y + (1.0 - 0.2) * half_height, death_linger_time)
	tween.tween_property(visual, "modulate:a", 0.0, death_linger_time)
