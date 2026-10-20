class_name MazeFrog
extends MazeEnemy
## A giant toad in the maze: it goes about the passages in lazy leaps, and when
## someone comes it hunts them in great leaps and catches them with its
## tongue. It is drawn and moved by GiantToad (creatures/frog/giant_toad.gd);
## this is what it thinks.
##
## - SIT. Between lazy leaps about the passages (MazeEnemy.goal: wandering, or
##   steered by the director), throat pulsing, now and then a croak. It sees
##   down the passages (`sight_range`) and hears anyone near (`hear_range`).
## - ALERT. Someone seen: it croaks (its throat blown up into a great bubble)
##   and turns to them, slowly, shuffling round.
## - HOP. It leaps at them along the passages, each leap up to `leap_length`
##   in a high arc, with a rest between (`rest_time`). On the whole it goes
##   slower than a run: running away gets away.
## - WINDUP, TONGUE. Within `tongue_range` of someone it can see, facing them,
##   it winds up (GiantToad.WINDUP_TIME, about a second: the throat swells,
##   the body rocks back, then the mouth gapes). It aims at their chest until
##   `aim_lock` of the way through, and then holds that aim; the tongue shoots
##   out along it. Whoever it touches is `caught`. So: step aside (even a walk
##   sideways does it, just), duck under it (it is aimed at the chest), or be
##   out of reach (running straight away from it is only safe from far off).
## - RECOVER. After a shot, caught or not, it sits a moment, gulping.
## When it has lost everyone it goes about again.
##
## As a puppet it follows the host's news; its leaps, shots and croaks come
## as counts in its flag (and the point they were at), and are played here too.

enum Mode { SIT, ALERT, HOP, WINDUP, TONGUE, RECOVER }

## How much bigger than the model (a unit long) it is drawn: metres long.
const SIZE := 3.2

@export var leap_length := 5.5
@export var rest_time := 0.65
@export var tongue_range := 8.5
## How far through the wind-up it stops aiming (0..1).
@export var aim_lock := 0.62
## How fast it turns on the ground, radians a second.
@export var turn_rate := 2.2
@export var gravity := 24.0
## Further than this from every player it is not posed (the walls hide it).
@export var pose_range := 70.0
@export var tint := Color.WHITE

var mode := Mode.SIT
var facing_yaw := 0.0
var toad: GiantToad

var _home := Vector3.ZERO
var _home_yaw := 0.0
var _radius := 1.0
var _rest_left := 0.0
var _alert_left := 0.0
var _croak_in := 6.0
var _point := Vector3.INF
var _leaps := 0
var _shots := 0
var _croaks := 0
var _caught_one := false
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false


func _init() -> void:
	sight_range = 34.0
	hear_range = 8.0
	memory = 7.0
	alert_range = 0.0
	pack = &"frogs"
	look_every = 0.2


func seed_choices(value: int) -> void:
	super(value)
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	var tints := [Color.WHITE, Color(1.1, 1.0, 0.82), Color(0.85, 0.95, 0.8), Color(1.05, 0.92, 0.85), Color(0.92, 1.05, 0.7)]
	tint = tints[rng.randi_range(0, tints.size() - 1)]


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = _radius
	shape.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)
	toad = GiantToad.new()
	toad.low_poly = Settings.low_poly
	toad.tint = tint
	toad.tongue_reach = tongue_range + 1.0
	toad.scale = Vector3.ONE * SIZE
	add_child(toad)
	toad.top_level = true
	facing_yaw = rotation.y
	_home = global_position
	_home_yaw = facing_yaw
	_prev_pos = global_position
	_curr_pos = global_position
	toad.global_position = global_position
	toad.rotation = Vector3(0.0, facing_yaw, 0.0)
	toad.settle()
	_croak_in = _rng.randf_range(4.0, 12.0)
	spotted.connect(_on_spotted)


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow_news(delta)
		return
	if maze == null:
		return
	_sense(delta)
	var after := quarry if hunting() and quarry.get(&"is_limp") != true else null
	var grounded := is_on_floor()
	match mode:
		Mode.SIT:
			_rest_left -= delta
			if after:
				_point = _chest(after)
				if _turn_to(after.global_position, delta) and _rest_left <= 0.0:
					_choose(after)
			else:
				_point = Vector3.INF
				_croak_in -= delta
				if _croak_in <= 0.0:
					_croak()
					_croak_in = _rng.randf_range(8.0, 16.0)
				# (nobody after: it goes about the passages in lazy leaps, where it wanders
				# or is steered (goal()); the user, 2026-10-19: "most monsters should
				# wander rather than sit")
				var aim := goal()
				var away := Vector2(aim.x - global_position.x, aim.z - global_position.z)
				if away.length() > 3.0 and _rest_left <= 0.0:
					_leap_towards(aim)
		Mode.ALERT:
			_alert_left -= delta
			if after:
				_point = _chest(after)
				_turn_to(after.global_position, delta)
			if _alert_left <= 0.0:
				mode = Mode.SIT
		Mode.HOP:
			if _far:
				# (nobody near enough to see it, and its body still: the leap is done at once)
				global_position = Vector3(_point.x, maze.ground_height(_point) + 0.05, _point.z)
				toad.global_position = global_position
				toad.settle()
				mode = Mode.SIT
				_rest_left = rest_time * _rng.randf_range(0.8, 1.3) * (1.0 if hunting() else 3.0)
				return
			var push := toad.leap_push()
			velocity.x = push.x
			velocity.z = push.z
			if toad.leap_stage() == GiantToad.Leap.FLIGHT:
				velocity.y = push.y
				move_and_slide()
				_track()
				return
			if toad.leap_stage() == GiantToad.Leap.NONE:
				mode = Mode.SIT
				# (going about, not after anyone, it sits longer between leaps)
				# (going about, not after anyone, it sits longer between leaps)
				_rest_left = rest_time * _rng.randf_range(0.8, 1.3) * (1.0 if hunting() else 3.0) * (1.0 if hunting() else 3.0)
		Mode.WINDUP:
			if after and toad.windup_progress() < aim_lock:
				_point = _chest(after)
				toad.aim(_point)
				_turn_to(after.global_position, delta)
			if toad.tongue_stage() in [GiantToad.Tongue.OUT, GiantToad.Tongue.HOLD]:
				mode = Mode.TONGUE
		Mode.TONGUE:
			if not _caught_one:
				for player: Node3D in players():
					if huntable(player) and _tongue_touches(player):
						_caught_one = true
						_catch(player)
						break
			if toad.tongue_stage() == GiantToad.Tongue.NONE:
				mode = Mode.RECOVER
				_rest_left = 1.1
		Mode.RECOVER:
			_rest_left -= delta
			if _rest_left <= 0.0:
				mode = Mode.SIT
				_rest_left = 0.2
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	if not grounded:
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()
	_track()


func _track() -> void:
	_prev_pos = _curr_pos
	_curr_pos = global_position


## What to do about someone it is facing: the tongue, if they are near and in
## sight, or a leap towards them.
func _choose(after: Node3D) -> void:
	var mouth := global_position + Vector3.UP * 1.0
	var chest := _chest(after)
	var flat := Vector2(chest.x - global_position.x, chest.z - global_position.z)
	var forward := Vector2(sin(facing_yaw), cos(facing_yaw))
	if flat.length() < tongue_range and forward.dot(flat.normalized()) > 0.85 and nav.sees(mouth, chest, tongue_range + 1.0):
		mode = Mode.WINDUP
		_caught_one = false
		_point = chest
		_shots += 1
		toad.strike(chest)
		return
	# A leap along the way to them, stopping short of them.
	if flat.length() < 3.5:
		_rest_left = 0.3
		return
	_leap_towards(after.global_position - Vector3(flat.x, 0.0, flat.y).normalized() * 2.5)


## Leaps towards `point` by the passages (as far as `leap_length`).
func _leap_towards(point: Vector3) -> void:
	var to := nav.waypoint(global_position, point, MazeNav.clearance_for(_radius)) - global_position
	to.y = 0.0
	var whole := Vector2(point.x - global_position.x, point.z - global_position.z).length()
	if to.length() < 0.3:
		return
	to = to.normalized() * clampf(whole, 1.5, leap_length)
	if not nav.line_free(global_position, global_position + to, _radius):
		to *= 0.5
		if not nav.line_free(global_position, global_position + to, _radius):
			_rest_left = 0.5
			return
	var yaw := atan2(to.x, to.z)
	if absf(angle_difference(facing_yaw, yaw)) > 0.5:
		# (it turns first, shuffling)
		facing_yaw = rotate_toward(facing_yaw, yaw, turn_rate * get_physics_process_delta_time())
		return
	mode = Mode.HOP
	_leaps += 1
	_point = global_position + to
	facing_yaw = yaw
	toad.leap(_point)


func _croak() -> void:
	_croaks += 1
	toad.croak(2)


## Turns towards `point` at its own slow pace; whether it is facing it now.
func _turn_to(point: Vector3, delta: float) -> bool:
	var to := point - global_position
	return _turn_to_yaw(atan2(to.x, to.z), delta)


func _turn_to_yaw(yaw: float, delta: float) -> bool:
	facing_yaw = rotate_toward(facing_yaw, yaw, turn_rate * delta)
	return absf(angle_difference(facing_yaw, yaw)) < 0.25


## Where it aims at someone: their chest (lower if they are ducking or crawling).
func _chest(player: Node3D) -> Vector3:
	var low: bool = player.get(&"is_ducking") == true or player.get(&"is_crawling") == true
	return player.global_position + Vector3.UP * (0.65 if low else 1.35)


## Whether the tongue is touching `player` anywhere on their body.
func _tongue_touches(player: Node3D) -> bool:
	var feet := player.global_position
	var low: bool = player.get(&"is_ducking") == true or player.get(&"is_crawling") == true
	var top := 0.85 if low else 1.55
	for k in 4:
		var at := feet + Vector3.UP * lerpf(0.3, top - 0.25, k / 3.0)
		if toad.tongue_hits(at, 0.28):
			return true
	return false


func _on_spotted(_player: Node3D) -> void:
	if puppet or mode != Mode.SIT:
		return
	mode = Mode.ALERT
	_alert_left = 1.0
	_croak()


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			toad.visible = not far
			toad.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if _far:
		return
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	toad.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	toad.rotation = Vector3(0.0, facing_yaw, 0.0)
	toad.look_at_point = _point if mode in [Mode.SIT, Mode.ALERT] else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Leaps (low four bits), tongue shots (next three) and croaks (top bit, as it changes).
func net_flag() -> int:
	return (_leaps & 0x0f) | ((_shots & 0x07) << 4) | ((_croaks & 1) << 7)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode in [Mode.ALERT, Mode.HOP, Mode.WINDUP, Mode.TONGUE]
	_point = point
	var leaps := flag & 0x0f
	var shots := (flag >> 4) & 0x07
	var croaks := (flag >> 7) & 1
	if not _heard_flagged:
		_heard_flagged = true
	elif toad:
		if leaps != (_leaps & 0x0f) and point.is_finite():
			toad.leap(point)
		if shots != (_shots & 0x07) and point.is_finite():
			toad.strike(point)
		if croaks != (_croaks & 1):
			toad.croak(2)
	_leaps = leaps
	_shots = shots
	_croaks = croaks


func _follow_news(delta: float) -> void:
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-8.0 * delta))
	if global_position.distance_to(_heard_at) > 4.0:
		global_position = _heard_at
	if toad and mode == Mode.WINDUP and _heard_extra.is_finite():
		toad.aim(_heard_extra)
	_track()


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if toad:
		toad.global_position = at
		toad.settle()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
