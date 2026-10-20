class_name MazeImp
extends MazeEnemy
## A tiny imp in the maze. What it looks like and how it moves is Imp
## (creatures/imp/, a component of its own); this is only what it thinks, and
## it drives the Imp by moving it and calling on it.
##
## Imps do not kill. They pester: a few of them at once bring you down.
##
## - PERCH. They go in gangs (`gang()`: three or four), each clinging to the
##   face of the nearest wall, `perch_height` up, head down like a gargoyle, looking out over the hall, now
##   and then chittering (you hear them before you see them). Not for long: after
##   a while each comes down and goes ABOUT the passages (wandering, or steered by
##   the director), and then up onto a new perch on the nearest wall where it has got to.
## - Noticing someone (MazeEnemy's senses), one cackles, its gang takes up the
##   hunt, and each scurries DOWN the wall head first and comes after them on
##   all fours (HUNT), by the passages, at `run_speed`: faster than he runs,
##   slower than he sprints. A sprint gets away; a run does not.
## - Within `leap_range`, facing them, it crouches and LEAPs. If its claws or
##   jaws find them in the air it holds on (RIDING), somewhere on the body
##   (ImpRide: his back, a thigh, a shoulder...). Each one riding him holds him
##   back (`hold_back`: he cannot run as fast), and every `call_every` seconds
##   it cackles, and everything else that hunts within `alarm_range` hears where
##   he is: imps fetch bigger hunters.
## - `catch_count` of them on one player for `catch_time` and he is brought down
##   (`caught`). They drop off, cackle, and go home.
## - SHAKING THEM OFF. Each has a grip (`grip`, a little different each time).
##   It loosens while he is in the air and with the jolt of every landing (a
##   jump or two shakes them off), and fast while he slides or spins; a roll or
##   a dive flings every one off at once. Thrown off (FLUNG) an imp tumbles,
##   lands, and throws a TANTRUM before it comes on again.
## - Up on a ledge, a terrace or a concrete bridge is not out of its reach: it
##   scurries up the face after them as it goes up to its perch, and along the
##   top (MazeEnemy's CLIMBING; the user, 2026-10-18: "more creatures should be
##   able to climb things").
## - When it forgets them (`memory`) or they get up out of its reach (a vine, a
##   rope bridge, a wall top), it throws a tantrum and goes HOME: back to the foot
##   of its wall and up to its perch.
##
## Online, as every MazeEnemy: the host's copy thinks; a puppet follows what it
## hears (its mode, the wall it is on or the player it rides, and counts of its
## leaps and cackles). Whoever is ridden, on whichever machine, is held back
## there by the imps on them.

enum Mode { PERCH, DOWN, HUNT, LEAP, RIDING, FLUNG, TANTRUM, HOME, CLIMB, ABOUT }

## How high up the wall it perches (it picks its own height about this).
@export var perch_height := 4.0
## (how fast it climbs, `climb_speed`, is MazeEnemy's: 2.4 m/s, set in _init)
@export var run_speed := 5.0
@export var walk_speed := 0.9
@export var leap_range := 2.6
## How long a leap is in the air, and how high it goes.
@export var leap_time := 0.34
@export var leap_height := 0.55
## How near its claws must pass someone's body to hold on.
@export var grab_reach := 0.6
## How much of his speed each imp riding him takes away (of his sprint).
@export var hold_back := 0.17
## How many on one player bring him down, and how long they must all hold on.
@export var catch_count := 3
@export var catch_time := 1.2
## Its grip on him, seconds of his being in the air (a range: each hold is different).
@export var grip := Vector2(1.1, 1.9)
## A riding imp's cackle tells everything that hunts within this where he is, this often.
@export var alarm_range := 30.0
@export var call_every := 1.8
@export var gravity := 20.0
## Further than this from every player it is not posed.
@export var pose_range := 60.0

var mode := Mode.PERCH
var body: Imp
## Who it rides, and where on them (ImpRide.slot).
var ridden: Node3D
var slot := -1

## Every rider, by who they ride (instance id -> Array of MazeImp).
static var _riders := {}

var _perch := Transform3D.IDENTITY
var _wall_foot := Vector3.INF
var _wall_normal := Vector3.BACK
var _has_perch := false
var _surface := Vector3.ZERO
var _heading := Vector3.UP
var _pos := Vector3.ZERO
var _vel := Vector3.ZERO
var _yaw := 0.0
var _leap_aim := Vector3.ZERO
var _leap_from := Vector3.ZERO
var _gather := 0.0
var _grip := 1.0
var _was_air := false
var _air_time := 0.0
var _call := 0.0
var _held := 0.0
var _won := false
var _chitter_in := 3.0
## It does not keep to one perch (the user, 2026-10-19: imps should wander): after
## PERCH_FOR seconds on it, it comes down and goes ABOUT for ABOUT_FOR, then finds
## the nearest wall where it has got to and goes up onto a new perch there.
const PERCH_FOR := Vector2(15.0, 40.0)
const ABOUT_FOR := Vector2(20.0, 45.0)
var _perch_left := 0.0
var _about_left := 0.0
var _roaming := false
var _spin := Vector3.ZERO
var _tumble := Basis.IDENTITY
var _leaps := 0
var _cackles := 0
var _skeletons := {}
var _far := false
var _far_check := 0.0
var _shown := Transform3D.IDENTITY
var _shown_set := false


## A gang of `count` imps.
static func gang(count := 3) -> Array[MazeImp]:
	var made: Array[MazeImp] = []
	for k in count:
		var one := MazeImp.new()
		one.perch_height = 3.2 + 0.7 * k
		made.append(one)
	return made


func _init() -> void:
	sight_range = 30.0
	hear_range = 8.0
	memory = 9.0
	alert_range = 25.0
	pack = &"imps"
	spare_time = 4.0
	climbs = Climbs.SCRAMBLE
	climb_speed = 2.4


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = 0
	collision_mask = 0
	# (it runs after the players have moved: it holds them back, and rides them where they are)
	process_physics_priority = 50
	process_priority = 50
	body = Imp.new()
	body.size = _rng.randf_range(0.4, 0.48)
	body.force_low = Settings.low_poly or Mummy.low_poly
	body.seed_value = _rng.randi()
	add_child(body)
	body.top_level = true
	_pos = global_position
	_surface = global_position
	_yaw = global_rotation.y
	_chitter_in = _rng.randf_range(1.0, 6.0)
	spotted.connect(func(_who: Node3D) -> void: _cackle())
	_find_perch.call_deferred()
	_perch_left = _rng.randf_range(PERCH_FOR.x * 0.3, PERCH_FOR.y)


## Finds the wall face nearest where it was put, `perch_height` up, and goes onto it.
func _find_perch() -> void:
	if not is_inside_tree():
		return
	var middle := global_position
	middle.y = (maze.ground_height(middle) if maze else middle.y) + perch_height
	var best := Vector3.INF
	var normal := Vector3.BACK
	var space := get_world_3d().direct_space_state
	for step: Vector2i in Maze.STEPS:
		var way := Vector3(step.x, 0.0, step.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(middle, middle + way * Maze.CELL, 1))
		if hit.is_empty():
			continue
		var point: Vector3 = hit["position"]
		if best == Vector3.INF or middle.distance_to(point) < middle.distance_to(best):
			best = point
			normal = hit["normal"]
	if best == Vector3.INF:
		# (no wall: it goes about on the ground)
		mode = Mode.ABOUT
		_pos = global_position
		_place_floor(_pos, _yaw)
		return
	normal.y = 0.0
	normal = normal.normalized()
	var along := Vector3.UP.cross(normal)
	best += along * _rng.randf_range(-1.5, 1.5)
	_wall_normal = normal
	_wall_foot = Vector3(best.x, 0.0, best.z) + normal * 0.35
	if maze:
		_wall_foot.y = maze.ground_height(_wall_foot)
	var tilt := _rng.randf_range(-0.5, 0.5)
	# (head down, like a gargoyle, to look out over the hall below)
	_perch = _on_wall(best, Vector3.DOWN.rotated(normal, tilt))
	_has_perch = true
	if mode == Mode.PERCH:
		_surface = best
		_heading = _perch.basis.z
		global_position = best
		body.clinging = true
		body.global_transform = _perch
		body.settle()


## A transform on the wall at `point`, facing `heading` along it.
func _on_wall(point: Vector3, heading: Vector3) -> Transform3D:
	var up := _wall_normal
	var z := (heading - up * heading.dot(up)).normalized()
	return Transform3D(Basis(up.cross(z), up, z), point + up * 0.01)


func _cackle() -> void:
	_cackles += 1
	body.cackle()


func _physics_process(delta: float) -> void:
	if puppet:
		_follow_news(delta)
		_hold_back_local()
		return
	if maze == null:
		return
	_sense(delta)
	chasing = hunting() and mode != Mode.PERCH or mode in [Mode.DOWN, Mode.HUNT, Mode.LEAP, Mode.RIDING]
	var after: Node3D = quarry if hunting() else null
	_gather -= delta
	match mode:
		Mode.PERCH:
			_chitter_in -= delta
			if _chitter_in <= 0.0:
				_chitter_in = _rng.randf_range(3.0, 9.0)
				body.chitter()
			if after:
				mode = Mode.DOWN
			else:
				# (sat long enough: down, and off about the passages)
				_perch_left -= delta
				if _perch_left <= 0.0:
					_roaming = true
					_about_left = _rng.randf_range(ABOUT_FOR.x, ABOUT_FOR.y)
					mode = Mode.DOWN
		Mode.DOWN:
			_heading = Vector3.DOWN
			_surface += Vector3.DOWN * climb_speed * delta
			var floor_y := maze.ground_height(_surface)
			if _surface.y <= floor_y + 0.25:
				_pos = Vector3(_surface.x, floor_y, _surface.z) + _wall_normal * 0.3
				_yaw = atan2(_wall_normal.x, _wall_normal.z)
				mode = Mode.HUNT if after else (Mode.ABOUT if _roaming else Mode.HOME)
		Mode.CLIMB:
			_heading = (_perch.origin - _surface)
			if _heading.length() < 0.1:
				mode = Mode.PERCH
				_perch_left = _rng.randf_range(PERCH_FOR.x, PERCH_FOR.y)
				_surface = _perch.origin
				_heading = _perch.basis.z
			else:
				_heading = _heading.normalized()
				_surface += _heading * minf(climb_speed * delta, (_perch.origin - _surface).length())
			if after:
				mode = Mode.DOWN
		Mode.HUNT:
			# (up the wall after them, out of reach on a ledge: as it goes up to its perch)
			global_position = _pos
			if _ways_up(delta, 0.2, run_speed):
				_pos = global_position
				_vel = velocity
				_yaw = aloft_yaw()
			else:
				_hunt(after, delta)
		Mode.LEAP:
			_leaping(delta)
		Mode.RIDING:
			_riding(delta)
		Mode.FLUNG:
			_flung(delta)
		Mode.TANTRUM:
			if not body.in_tantrum():
				if _won or after == null:
					mode = Mode.HOME
				else:
					mode = Mode.HUNT
		Mode.HOME:
			_home(after, delta)
		Mode.ABOUT:
			if after:
				_roaming = false
				mode = Mode.HUNT
			else:
				_walk_to(goal(), walk_speed, delta, 0.3)
				# (gone about long enough: up onto the nearest wall where it has got to)
				_about_left -= delta
				if _roaming and _about_left <= 0.0:
					_roaming = false
					_find_perch()
					if _has_perch and mode == Mode.ABOUT:
						mode = Mode.HOME
	global_position = _surface if mode in [Mode.PERCH, Mode.DOWN, Mode.CLIMB] else _pos
	velocity = _vel


func _hunt(after: Node3D, delta: float) -> void:
	if after == null:
		body.tantrum(1.2)
		mode = Mode.TANTRUM
		return
	var chest := after.global_position + Vector3.UP * 0.6
	var to := chest - _pos
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() < 8.0 and to.y > 2.2:
		# (up out of its reach: it gives up on them)
		_forget = minf(_forget, 1.5)
	var forward := Vector3(sin(_yaw), 0.0, cos(_yaw))
	if _gather <= 0.0 and flat.length() < leap_range and to.y < 1.6 and forward.dot(flat.normalized()) > 0.8 and _riders_on(after).size() < ImpRide.SLOTS:
		_spring(after)
		return
	_walk_to(after.global_position, run_speed, delta, 0.25)


## Goes by the passages to `goal` at `pace`, on the ground.
func _walk_to(goal_at: Vector3, pace: float, delta: float, radius: float) -> void:
	var to := nav.waypoint(_pos, goal_at, MazeNav.clearance_for(radius)) - _pos
	to.y = 0.0
	var wish := to.normalized() if to.length() > 0.05 else Vector3.ZERO
	var push := _apart(radius)
	if push != Vector3.ZERO:
		wish = (wish + push * 0.7).normalized()
	_vel = _vel.move_toward(wish * pace, 30.0 * delta)
	_pos += _vel * delta
	_pos.y = maze.ground_height(_pos)
	if _vel.length() > 0.2:
		_yaw = lerp_angle(_yaw, atan2(_vel.x, _vel.z), 1.0 - exp(-12.0 * delta))


func _apart(radius: float) -> Vector3:
	var push := Vector3.ZERO
	for other: Node in get_tree().get_nodes_in_group(pack):
		if other == self or not (other is MazeImp) or (other as MazeImp).mode != Mode.HUNT:
			continue
		var out := _pos - (other as MazeImp)._pos
		out.y = 0.0
		var near := radius * 3.0
		if out.length() < near and out.length() > 0.001:
			push += out.normalized() * (near - out.length()) / near
	return push


## Springs at `who`: crouches, then flies at where they will be.
func _spring(who: Node3D) -> void:
	mode = Mode.LEAP
	_leaps += 1
	var moving: Variant = who.get(&"velocity")
	var lead := (moving as Vector3) * (Imp.CROUCH_TIME + leap_time * 0.7) if moving is Vector3 else Vector3.ZERO
	lead.y = 0.0
	_leap_aim = who.global_position + lead
	_leap_from = _pos
	_vel = Vector3.ZERO
	body.leap(leap_time, leap_height)


func _leaping(delta: float) -> void:
	var stage := body.leap_stage()
	if stage == Imp.Leap.CROUCH:
		var to := _leap_aim - _pos
		_yaw = lerp_angle(_yaw, atan2(to.x, to.z), 1.0 - exp(-14.0 * delta))
		return
	if stage == Imp.Leap.FLIGHT:
		var to := _leap_aim - _leap_from
		to.y = 0.0
		var reach := clampf(to.length() + 0.4, 0.8, leap_range + 1.0)
		_vel = to.normalized() * reach / leap_time
		_pos += _vel * delta
		_pos.y = maze.ground_height(_pos)
		for player: Node3D in players():
			if not huntable(player) or _riders_on(player).size() >= ImpRide.SLOTS:
				continue
			var at := player.global_position
			if body.reaches(at + Vector3.UP * 0.85, grab_reach) or body.reaches(at + Vector3.UP * 0.45, grab_reach * 0.8):
				_mount(player)
				return
		return
	_vel = _vel.move_toward(Vector3.ZERO, 20.0 * delta)
	_pos += _vel * delta
	_pos.y = maze.ground_height(_pos)
	if stage == Imp.Leap.NONE:
		mode = Mode.HUNT
		_gather = 0.7


## Takes hold of `player`, in the first free place on them.
func _mount(player: Node3D) -> void:
	var list := _riders_on(player)
	var used := {}
	for other: MazeImp in list:
		used[other.slot] = true
	for k in ImpRide.SLOTS:
		if not used.has(k):
			slot = k
			break
	list.append(self)
	ridden = player
	mode = Mode.RIDING
	body.end_leap()
	_grip = _rng.randf_range(grip.x, grip.y)
	_was_air = false
	_call = 0.3
	_held = 0.0
	_cackle()


func _riding(delta: float) -> void:
	var who := ridden
	if who == null or not is_instance_valid(who) or not huntable(who):
		_let_go(Vector3.ZERO)
		return
	_pos = who.global_position
	# Shaking it off: in the air, landing, sliding, spinning; a roll or a dive throws it.
	var air := not (who.call(&"is_on_floor") as bool) if who.has_method(&"is_on_floor") else absf((who.get(&"velocity") as Vector3).y) > 1.5
	if air:
		_air_time += delta
		_grip -= delta
	elif _was_air:
		if _air_time > 0.2:
			_grip -= 0.5
		_air_time = 0.0
	_was_air = air
	if who.get(&"is_diving") == true or (who.get(&"flip_progress") is float and (who.get(&"flip_progress") as float) < 1.0):
		_grip = 0.0
	var landing: Variant = who.get(&"landing")
	if landing is int and (who.get(&"landing_progress") as float) < 0.6 and landing == Player.Landing.ROLL:
		_grip = 0.0
	if who.get(&"state") is int and who.get(&"state") == Player.State.SLIDE:
		_grip -= delta * 2.5
	if who.get(&"is_spinning") == true:
		_grip -= delta * 3.0
	if who.get(&"is_limp") == true:
		_grip = 0.0
	if _grip <= 0.0:
		var going: Variant = who.get(&"velocity")
		_let_go(going if going is Vector3 else Vector3.ZERO)
		return
	# Calling the others.
	_call -= delta
	if _call <= 0.0:
		_call = call_every * _rng.randf_range(0.8, 1.2)
		_cackle()
		_raise_alarm(who)
	# Enough of them on him for long enough, and he is down.
	if _riders_on(who).size() >= catch_count:
		_held += delta
		if _held >= catch_time:
			var all := _riders_on(who).duplicate()
			_catch(who)
			for one: MazeImp in all:
				one._won = true
				one._let_go(Vector3.ZERO)
				one._cackle()
	else:
		_held = 0.0
	_hold_back_local()


## A rider on this machine's own player holds him back (each frame, after he has moved).
func _hold_back_local() -> void:
	if mode != Mode.RIDING or ridden == null or not is_instance_valid(ridden) or not (ridden is Player):
		return
	var boy := ridden as Player
	var count := _riders_on(boy).size()
	var cap := boy.sprint_speed * maxf(1.0 - hold_back * count, 0.25)
	var flat := Vector3(boy.velocity.x, 0.0, boy.velocity.z)
	if flat.length() > cap:
		flat = flat.normalized() * cap
		boy.velocity.x = flat.x
		boy.velocity.z = flat.z


## Everything else that hunts within `alarm_range` is told where `player` is.
func _raise_alarm(player: Node3D) -> void:
	for other: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		if other == self or not (other is MazeEnemy) or other is MazeImp or other is Bats or (other as MazeEnemy).puppet:
			continue
		if (other as Node3D).global_position.distance_to(global_position) < alarm_range:
			(other as MazeEnemy).notice(player)
	for griever: Node in get_tree().get_nodes_in_group(&"grievers"):
		if griever.has_method(&"alert") and (griever as Node3D).global_position.distance_to(global_position) < alarm_range:
			griever.call(&"alert", player.global_position)


## Lets go (thrown off, going `going` and away from him).
func _let_go(going: Vector3) -> void:
	var from := body.global_position
	_leave_rider()
	mode = Mode.FLUNG
	var away := from - _pos
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	_pos = from
	_vel = going * 0.5 + away * _rng.randf_range(1.6, 2.6) + Vector3.UP * _rng.randf_range(2.0, 3.2)
	_spin = Vector3(_rng.randf_range(-9, 9), _rng.randf_range(-6, 6), _rng.randf_range(-9, 9))
	_tumble = body.global_basis.orthonormalized()


func _leave_rider() -> void:
	if ridden and _riders.has(ridden.get_instance_id()):
		(_riders[ridden.get_instance_id()] as Array).erase(self)
	ridden = null
	slot = -1


func _flung(delta: float) -> void:
	_vel.y -= gravity * delta
	var next := _pos + _vel * delta
	# (it does not go through walls: it bounces off them)
	if nav and not nav.clear_of_walls(Vector3(next.x, 0.0, next.z), 0.2):
		_vel.x = -_vel.x * 0.4
		_vel.z = -_vel.z * 0.4
		next = _pos + _vel * delta
	_pos = next
	_tumble = (Basis.from_euler(_spin * delta) * _tumble).orthonormalized()
	var floor_y := maze.ground_height(_pos)
	if _pos.y <= floor_y and _vel.y < 0.0:
		_pos.y = floor_y
		_vel = Vector3.ZERO
		if _won:
			mode = Mode.HOME
		else:
			mode = Mode.TANTRUM
			body.tantrum(_rng.randf_range(1.1, 1.7))


func _home(after: Node3D, delta: float) -> void:
	if after and not _won:
		mode = Mode.HUNT
		return
	if not _has_perch:
		mode = Mode.ABOUT
		return
	var to := _wall_foot - _pos
	to.y = 0.0
	if to.length() < 0.5:
		_won = false
		mode = Mode.CLIMB
		_surface = Vector3(_wall_foot.x, _pos.y, _wall_foot.z) - _wall_normal * 0.34 + Vector3.UP * 0.15
		return
	_walk_to(_wall_foot, run_speed * 0.6, delta, 0.25)


## The imps riding `who` (kept for all MazeImps).
static func _riders_on(who: Node3D) -> Array:
	var key := who.get_instance_id()
	if not _riders.has(key):
		_riders[key] = []
	var list: Array = _riders[key]
	for i in range(list.size() - 1, -1, -1):
		if not is_instance_valid(list[i]):
			list.remove_at(i)
	return list


## How many imps are riding `who` now.
static func riding(who: Node3D) -> int:
	return _riders_on(who).size()


func _exit_tree() -> void:
	_leave_rider()


# --- Drawing it ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range and mode != Mode.RIDING
		if far != _far:
			_far = far
			body.visible = not far
			body.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if _far:
		return
	var on_face := aloft == HighClimb.Aloft.CLIMB or aloft == HighClimb.Aloft.DOWN
	body.clinging = mode in [Mode.PERCH, Mode.DOWN, Mode.CLIMB] or on_face
	body.riding = mode == Mode.RIDING
	body.tumbling = mode == Mode.FLUNG
	body.on_all_fours = mode in [Mode.HUNT, Mode.LEAP, Mode.HOME, Mode.DOWN]
	var after: Node3D = quarry if hunting() else null
	if puppet:
		after = nearest_player(global_position) if chasing else null
	body.look_at_point = after.global_position + Vector3.UP * 1.0 if after and mode != Mode.FLUNG else Vector3.INF
	var want: Transform3D
	match (mode if not on_face else Mode.CLIMB):
		Mode.PERCH, Mode.DOWN, Mode.CLIMB:
			if on_face:
				# (up a face after someone: clinging to it head up, or head down coming down)
				var out := aloft_out()
				var ahead := Vector3.UP if aloft == HighClimb.Aloft.CLIMB else Vector3.DOWN
				want = Transform3D(Basis(out.cross(ahead), out, ahead), global_position + out * 0.01)
			else:
				want = _on_wall(_surface, _heading)
		Mode.RIDING:
			if ridden and is_instance_valid(ridden):
				want = ImpRide.slot(_skeleton_of(ridden), ridden, slot)
				body.global_transform = want
				_shown = want
				return
			want = Transform3D(Basis(Vector3.UP, _yaw), _pos)
		Mode.FLUNG:
			want = Transform3D(_tumble, _pos)
		_:
			want = Transform3D(Basis(Vector3.UP, _yaw), _pos)
	if not _shown_set:
		_shown = want
		_shown_set = true
	# (turned onto the wall or off it smoothly, but never lagging where it is)
	var q := _shown.basis.get_rotation_quaternion().slerp(want.basis.get_rotation_quaternion(), 1.0 - exp(-14.0 * delta))
	_shown = Transform3D(Basis(q), want.origin)
	body.global_transform = _shown


func _place_floor(at: Vector3, yaw_now: float) -> void:
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw_now), at)
	body.settle()


func _skeleton_of(who: Node3D) -> Skeleton3D:
	var key := who.get_instance_id()
	if not _skeletons.has(key) or not is_instance_valid(_skeletons[key]):
		var found := who.find_children("*", "Skeleton3D", true, false)
		_skeletons[key] = found[0] if not found.is_empty() else null
	return _skeletons[key]


# --- Being run by someone else ---

func yaw() -> float:
	return _yaw


func net_state() -> int:
	return mode


## Its place on whoever it rides (low three bits, 7: none), and counts of its leaps (two bits) and cackles (three).
func net_flag() -> int:
	return (slot if slot >= 0 else 7) | ((_leaps & 0x03) << 3) | ((_cackles & 0x07) << 5)


## On a wall, a point a metre out from it; riding, the one it rides; else none.
func net_point() -> Vector3:
	if mode in [Mode.PERCH, Mode.DOWN, Mode.CLIMB]:
		return _surface + _wall_normal
	if mode == Mode.RIDING and ridden:
		return ridden.global_position
	return Vector3.INF


var _heard_flags := -1


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var was := mode
	mode = state as Mode
	chasing = mode in [Mode.DOWN, Mode.HUNT, Mode.LEAP, Mode.RIDING]
	if mode in [Mode.PERCH, Mode.DOWN, Mode.CLIMB] and point.is_finite():
		_wall_normal = (point - at).normalized()
	if mode == Mode.RIDING and point.is_finite():
		var who := nearest_player(point)
		if who != ridden:
			_leave_rider()
			ridden = who
			slot = flag & 0x07
			if who:
				_riders_on(who).append(self)
	elif was == Mode.RIDING:
		_leave_rider()
	if mode == Mode.FLUNG and was != Mode.FLUNG:
		_spin = Vector3(_rng.randf_range(-9, 9), _rng.randf_range(-6, 6), _rng.randf_range(-9, 9))
		_tumble = body.global_basis.orthonormalized() if body else Basis.IDENTITY
	if mode == Mode.TANTRUM and was != Mode.TANTRUM and body:
		body.tantrum(1.4)
	if _heard_flags >= 0 and body:
		if ((flag >> 3) & 0x03) != ((_heard_flags >> 3) & 0x03):
			body.leap(leap_time, leap_height)
		if ((flag >> 5) & 0x07) != ((_heard_flags >> 5) & 0x07):
			body.cackle()
	_heard_flags = flag


func _follow_news(delta: float) -> void:
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	var at := global_position.lerp(_heard_at, 1.0 - exp(-10.0 * delta))
	if at.distance_to(_heard_at) > 3.0:
		at = _heard_at
	global_position = at
	_pos = at
	_surface = at
	_yaw = lerp_angle(_yaw, _heard_yaw, 1.0 - exp(-12.0 * delta))
	if mode in [Mode.PERCH, Mode.DOWN, Mode.CLIMB]:
		_heading = _heard_moving.normalized() if _heard_moving.length() > 0.3 else Vector3.UP
	if mode == Mode.FLUNG:
		_tumble = (Basis.from_euler(_spin * delta) * _tumble).orthonormalized()


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	_pos = at
	_surface = at
	_yaw = facing
	_shown_set = false


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0
