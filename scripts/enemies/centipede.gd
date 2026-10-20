class_name Centipede
extends MazeEnemy
## A giant centipede, eighteen metres of it, let loose in the maze. What it
## looks like and how it moves is CentipedeBody (creatures/centipede, a
## component with nothing of the maze in it); this is what it does, and drives
## that body.
##
## - IT PROWLS the passages slowly, along the feet of the walls, wandering or
##   steered by the director (MazeEnemy.goal), never resting (`start_resting`
##   and `rest_after` 0, as it is in the game now). Set to rest instead:
## - AT REST it lies coiled in a dead end, its feelers stirring, until it
##   notices someone (MazeEnemy's senses; it feels footsteps through the ground
##   from further off than the others hear them). Then it rears up
##   (`wake_time`) and comes.
## - THE CHASE. By the passages (MazeNav), quicker than a run on the straight
##   (`speed`) and much slower in a turn, so a sprint keeps ahead of it, and a
##   turn taken well gains on it. Its body runs a little way up the walls' feet
##   as it goes, and up them round the corners.
## - THE STRIKE. Near enough (`strike_distance`), in sight and in front, it
##   stops, rears high with its poison claws spread (`CentipedeBody.wind_up`:
##   the warning, following them round), and throws itself at where they are.
##   Only its claws catch: `caught(player)` is emitted if they pass through
##   someone. A step aside in that moment and it misses, and lies there a
##   moment before it draws itself back.
## - LOSING THEM. It goes on to where they were last seen, stops, and rears to
##   feel the air for a while, swaying (SEARCH); then it prowls slowly along the
##   feet of the walls; and after `rest_after` seconds with nobody about it goes
##   to the nearest dead end and coils up there.
## - Its body pushes this machine's player aside but does not hurt them.
##
## As a puppet (online, not the host) it follows the host's news and its body
## does the rest: the strike is set off from the state, at the point sent with it.

enum State { RESTING, WAKING, HUNT, STRIKE, SEARCH, PROWL, COILING }

## The least room (the radius of a ring, m) it coils up in; anywhere narrower it lies stretched out.
const ROOMY := 2.3

## Its speed, m/s: the boy runs at 4.4 and sprints at 5.6. A little faster
## than this on the straight; a good deal slower in a turn.
@export var speed := 5.0
## How fast it prowls with nobody to go after, as a share of `speed`.
@export var prowl_pace := 0.42
@export var turn_rate := 3.2
@export var wake_time := 0.9
## How near its head must be to strike, how near its claws must pass to have them.
@export var strike_distance := 5.5
@export var catch_distance := 0.85
## Seconds of searching with nobody found, and of prowling before it goes to coil up (0: never).
@export var search_time := 3.2
## (0, and it prowls on: the user, 2026-10-19, "most monsters should wander rather than sit")
@export var rest_after := 0.0
## Coiled in a dead end until it notices someone (else, as it is now, it prowls from the start).
@export var start_resting := false

var state := State.RESTING
## What it looks like (made in `_ready`).
var body: CentipedeBody

var _time := 0.0
var _yaw := 0.0
var _idle := 0.0
var _was_hunting := false
var _lost := false
var _has_him := false
var _strike_rest := 0.0
var _aim := Vector3.INF
var _den := Vector2i(-1, -1)
var _den_radius := 2.6
var _den_turned := 0.0
var _detour := Vector3.ZERO
var _detour_time := 0.0
var _stuck_at := Vector3.ZERO
var _stuck_time := 0.0
var _flip := 1.0
var _spawn := Transform3D.IDENTITY
var _prev := Vector3.ZERO
var _curr := Vector3.ZERO


func _init() -> void:
	sight_range = 46.0
	hear_range = 11.0
	memory = 8.0
	pack = &"centipedes"


func _ready() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1
	floor_snap_length = 0.4
	var ball := SphereShape3D.new()
	ball.radius = 0.6
	var collider := CollisionShape3D.new()
	collider.shape = ball
	collider.position.y = 0.6
	add_child(collider)
	body = CentipedeBody.new()
	body.name = "Body"
	body.top_level = true
	add_child(body)
	_spawn = global_transform
	reset()


func _body_radius() -> float:
	return body.width * 0.5 if body else 0.65


## Back where it was put, as at the start: coiled there, or lying straight.
func reset() -> void:
	global_transform = _spawn
	_yaw = _spawn.basis.get_euler().y
	velocity = Vector3.ZERO
	quarry = null
	_forget = 0.0
	_last_seen = Vector3.INF
	_prev = global_position
	_curr = global_position
	_place_body()
	var room := _ring_for(global_position)
	if start_resting and room >= ROOMY:
		# Coiled round where it was put: its head on the ring, the middle of the ring to its left.
		var middle := global_position
		_den = maze.cell_at(middle) if maze else Vector2i(-1, -1)
		_den_radius = room
		global_position = middle + Vector3(-cos(_yaw), 0.0, sin(_yaw)) * _den_radius
		_prev = global_position
		_curr = global_position
		_place_body()
		body.lay_coil(_den_radius, middle)
		_set_state(State.RESTING)
	else:
		# (too narrow a place to coil in: it lies stretched out along the passage)
		body.lay_straight()
		_set_state(State.RESTING if start_resting else State.PROWL)
	body.rear(0.0)


func is_awake() -> bool:
	return state != State.RESTING


func wake() -> void:
	if state == State.RESTING or state == State.COILING:
		_set_state(State.WAKING)


func _set_state(to: State) -> void:
	if to != state:
		_time = 0.0
	state = to
	chasing = to == State.HUNT or to == State.STRIKE or to == State.WAKING
	if chasing and not is_in_group(&"pursuers"):
		add_to_group(&"pursuers")
	elif not chasing and is_in_group(&"pursuers"):
		remove_from_group(&"pursuers")


func _forward() -> Vector3:
	return Vector3(sin(_yaw), 0.0, cos(_yaw))


# --- What it does ---

func _physics_process(delta: float) -> void:
	_time += delta
	if puppet:
		_puppet(delta)
	elif maze:
		_think(delta)
	_prev = _curr
	_curr = global_position
	_push_aside()


func _think(delta: float) -> void:
	_strike_rest -= delta
	_sense(delta)
	var after := hunting()
	if _was_hunting and not after:
		_lost = true
	_was_hunting = after
	match state:
		State.RESTING:
			velocity = Vector3.ZERO
			body.rear(0.0)
			if quarry:
				wake()
		State.WAKING:
			_stand(delta)
			body.rear(0.9)
			if quarry:
				_face(quarry.global_position, delta)
			if _time >= wake_time:
				_set_state(State.HUNT)
		State.HUNT, State.PROWL:
			_hunt(delta)
		State.STRIKE:
			_strike(delta)
		State.SEARCH:
			_stand(delta)
			body.rear(0.85)
			body.look_about = true
			if quarry:
				body.look_about = false
				_set_state(State.HUNT)
			elif _time > search_time:
				body.look_about = false
				_set_state(State.PROWL)
		State.COILING:
			_coil(delta)
			if quarry:
				_set_state(State.WAKING)


func _hunt(delta: float) -> void:
	var after := quarry if hunting() else null
	if after == null:
		_set_state(State.PROWL)
		body.rear(0.0)
		# Come to where they were last seen and lost them: it stops to feel for them.
		if _lost and not _last_seen.is_finite():
			_lost = false
			_set_state(State.SEARCH)
			return
		_idle += delta
		if rest_after > 0.0 and _idle > rest_after and not _last_seen.is_finite():
			_idle = 0.0
			_go_to_den()
			return
		_go(delta, 0.85 if _last_seen.is_finite() else prowl_pace, true)
		return
	_idle = 0.0
	_set_state(State.HUNT)
	body.rear(0.12)
	var to := after.global_position - global_position
	var away := Vector2(to.x, to.z).length()
	if _strike_rest <= 0.0 and away < strike_distance and absf(to.y) < 1.6 and is_on_floor() \
			and nav.sees(global_position + Vector3.UP, after.global_position + Vector3.UP) \
			and (away < 1.5 or _forward().dot(Vector3(to.x, 0.0, to.z).normalized()) > 0.6):
		_begin_strike(after)
		return
	_go(delta, 1.0, false)


func _begin_strike(after: Node3D) -> void:
	_set_state(State.STRIKE)
	_has_him = false
	_aim = _target_point(after)
	body.strike(_aim)


func _target_point(player: Node3D) -> Vector3:
	var low: bool = player.get(&"is_ducking") == true or player.get(&"is_crawling") == true
	return player.global_position + Vector3.UP * (0.3 if low else 0.6)


func _strike(delta: float) -> void:
	_stand(delta)
	var after := quarry if hunting() else null
	var stage := body.stage()
	if stage == CentipedeBody.Stage.WIND_UP and after and body.strikes_in() > 0.15:
		# It follows them round as it rears, but not to the last.
		_face(after.global_position, delta * 1.5)
		_aim = _target_point(after)
		body.retarget(_aim)
	if (stage == CentipedeBody.Stage.POUNCE or stage == CentipedeBody.Stage.HOLD) and not _has_him and not puppet:
		for player: Node3D in players():
			if not huntable(player):
				continue
			var feet := player.global_position
			var low: bool = player.get(&"is_ducking") == true or player.get(&"is_crawling") == true
			if body.bites(feet + Vector3.UP * 0.1, feet + Vector3.UP * (0.65 if low else 1.15), catch_distance):
				_has_him = true
				_catch(player)
				break
	if stage == CentipedeBody.Stage.NONE and _time > 0.2:
		_strike_rest = 0.4
		if not puppet:
			_set_state(State.HUNT)
			_stuck_time = 0.0
			_stuck_at = global_position


# Turns it towards a place.
func _face(at: Vector3, by: float) -> void:
	var to := at - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		_yaw = rotate_toward(_yaw, atan2(to.x, to.z), by * turn_rate)


# Goes on its way through the passages: turns, goes forward, slides round what is in the way;
# prowling, it keeps to the foot of a wall.
func _go(delta: float, pace: float, hug: bool) -> void:
	var flat := way(_body_radius() * 1.3)
	var wish := flat.normalized() if flat.length() > 0.05 else _forward()
	if hug:
		wish = (wish + _to_wall() * 0.5).normalized()
	_detour_time -= delta
	if _detour_time > 0.0:
		wish = (wish * 0.45 + _detour).normalized()
	_steer(delta, wish, pace, flat.length())


func _steer(delta: float, wish: Vector3, pace: float, room: float) -> void:
	var want := atan2(wish.x, wish.z)
	var off := absf(angle_difference(_yaw, want))
	var near := room < 1.6 and off > 0.8
	_yaw = rotate_toward(_yaw, want, turn_rate * (1.0 + (off if near else minf(off, 0.6))) * delta)
	var forward := _forward()
	var factor := lerpf(1.1, 0.5, clampf(off / 0.9, 0.0, 1.0))
	if near:
		factor = 0.3
	if room < 0.1:
		factor = 0.0
	if is_on_floor():
		var hit := KinematicCollision3D.new()
		if test_move(global_transform, forward * 0.5, hit) and hit.get_normal().y < 0.6:
			if _detour_time <= 0.0:
				var normal := hit.get_normal()
				_detour = Vector3(-normal.z, 0.0, normal.x)
				if absf(_detour.dot(wish)) > 0.15:
					_detour *= signf(_detour.dot(wish))
				_detour *= _flip
			_detour_time = 0.7
	var going := forward * speed * pace * factor
	velocity.x = going.x
	velocity.z = going.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 24.0 * delta
	move_and_slide()
	_stuck_time += delta
	if _stuck_time >= 1.0:
		if _stuck_at.distance_to(global_position) < 0.35 and room > 0.9:
			_flip = -_flip
			_detour_time = 0.0
		_stuck_time = 0.0
		_stuck_at = global_position


# Towards the nearer wall beside it if it is more than a body's width off, away if nearer (flat, 0..1).
func _to_wall() -> Vector3:
	var side := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var low := global_position + Vector3.UP * 0.6
	var space := get_world_3d().direct_space_state
	var best := INF
	var toward := Vector3.ZERO
	for way_out: float in [1.0, -1.0]:
		var query := PhysicsRayQueryParameters3D.create(low, low + side * way_out * 6.0, 1)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var d := low.distance_to(hit["position"])
			if d < best:
				best = d
				toward = side * way_out
	if best == INF:
		return Vector3.ZERO
	return toward * clampf((best - 2.0) / 3.0, -1.0, 1.0)


func _stand(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 0.0 if is_on_floor() else velocity.y - 24.0 * delta
	move_and_slide()


# --- Coiling up ---

## How many walls a cell has round it (3: a dead end, 2: a corner or a passage).
func walls_round(cell: Vector2i) -> int:
	var walls := 0
	for step: Vector2i in Maze.STEPS:
		if maze.blocked(cell, step):
			walls += 1
	return walls


# Picks the nearest dead end by the passages (or, failing one, the nearest
# corner) and goes there to coil up.
func _go_to_den() -> void:
	var here := maze.cell_at(global_position)
	var steps := nav.field(here)
	var best := 1 << 30
	_den = here
	for cell: Vector2i in nav.lairs(1):
		var d := steps[maze.index(cell)]
		if d < 0:
			continue
		# (a dead end is worth going twenty cells further than a corner for; and it must be roomy enough to coil in)
		var score := d + (0 if walls_round(cell) >= 3 else 20 if walls_round(cell) == 2 else 1000)
		if score < best and _ring_for(maze.world(cell)) >= ROOMY:
			best = score
			_den = cell
	_den_radius = _ring_for(maze.world(_den))
	_den_turned = 0.0
	_set_state(State.COILING)


# The widest ring it can coil in at `middle`, clear of the walls.
func _ring_for(middle: Vector3) -> float:
	if nav == null:
		return 2.6
	var r := 3.2
	while r > 1.4:
		var clear := true
		for k in 8:
			var angle := TAU * k / 8.0
			if not nav.clear_of_walls(middle + Vector3(sin(angle), 0.0, cos(angle)) * (r + _body_radius()), 0.2):
				clear = false
				break
		if clear:
			return r
		r -= 0.3
	return 1.4


# Goes to its den, and once there (or as near as it can get) stops and curls up, and rests.
func _coil(delta: float) -> void:
	var middle := maze.world(_den)
	var from := Vector3(global_position.x - middle.x, 0.0, global_position.z - middle.z)
	_den_turned += delta
	var there := from.length() < _den_radius + 0.6
	var stuck := _den_turned > 1.5 and maze.cell_at(global_position) == _den and Vector2(velocity.x, velocity.z).length() < 0.2
	if not there and not stuck and _den_turned < 40.0:
		var to := nav.waypoint(global_position, middle, MazeNav.clearance_for(_body_radius())) - global_position
		to.y = 0.0
		_steer(delta, to.normalized() if to.length() > 0.05 else _forward(), prowl_pace, to.length())
		return
	_stand(delta)
	if _ring_for(middle) >= ROOMY:
		body.curl(_den_radius, middle)
	_set_state(State.RESTING)


# --- Its body ---

func _place_body() -> void:
	body.global_transform = Transform3D(Basis(Vector3.UP, _yaw), global_position)


func _process(_delta: float) -> void:
	var at := _prev.lerp(_curr, Engine.get_physics_interpolation_fraction())
	body.global_transform = Transform3D(Basis(Vector3.UP, _yaw), at)
	if state == State.STRIKE or state == State.WAKING or state == State.HUNT:
		var after := quarry if not puppet else null
		body.aim = after.global_position + Vector3.UP * 0.8 if after else (_heard_extra if puppet else Vector3.INF)
	elif state == State.SEARCH:
		body.aim = Vector3.INF
	else:
		body.aim = Vector3.INF


# Its body is in the way of this machine's player: they are put out of it.
func _push_aside() -> void:
	if state == State.STRIKE or body == null:
		return
	var boy := local_player()
	if boy == null or boy.is_limp:
		return
	var feet := boy.global_position
	var length := body.length
	if absf(feet.x - global_position.x) > length or absf(feet.z - global_position.z) > length:
		return
	var thick := _body_radius() + 0.35
	for i in range(1, body.spine.size(), 2):
		var at := body.spine[i]
		if at.y < feet.y - 0.6 or at.y > feet.y + 1.6:
			continue
		var out := Vector3(feet.x - at.x, 0.0, feet.z - at.z)
		var away := out.length()
		if away < thick and away > 0.001:
			boy.move_and_collide(out / away * (thick - away))
			return


# --- Being run by someone else ---

func yaw() -> float:
	return _yaw


func net_state() -> int:
	return state


func net_point() -> Vector3:
	if state == State.STRIKE:
		return _aim
	if chasing and quarry:
		return quarry.global_position + Vector3.UP * 0.8
	return Vector3.INF


func _puppet(delta: float) -> void:
	if not _heard:
		return
	match state:
		State.RESTING:
			velocity = Vector3.ZERO
			body.rear(0.0)
			return
		State.WAKING:
			body.rear(0.9)
		State.SEARCH:
			body.rear(0.85)
			body.look_about = true
		State.STRIKE:
			if _heard_extra.is_finite():
				body.retarget(_heard_extra)
		_:
			body.rear(0.12 if state == State.HUNT else 0.0)
			body.look_about = false
	_yaw = lerp_angle(_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	_follow(delta)


func _heard_changed(was: int, now: int, first: bool) -> void:
	var to := now as State
	if to == State.STRIKE and not first:
		_aim = _heard_extra if _heard_extra.is_finite() else global_position + _forward() * strike_distance
		body.strike(_aim)
	if to == State.RESTING and not first and (was as State) == State.COILING and _ring_for(global_position) >= ROOMY:
		body.curl(_ring_for(global_position))
	_set_state(to)
	if first and to == State.RESTING and _ring_for(global_position) >= ROOMY:
		body.lay_coil(_ring_for(global_position))


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	_yaw = facing
	_prev = at
	_curr = at
	velocity = Vector3.ZERO
	if body:
		_place_body()
		body.lay_straight()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
