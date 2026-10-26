class_name RemotePlayer
extends Figure
## Somebody else in the maze: a figure on the boy's rig that follows where their
## game says they are. Their own game moves them; this only chases its news, so
## that between packets they walk on smoothly, and a long way off they are put
## straight there.

## Their seat in the room.
var slot := 0
var escaped := false
## What they have in their hand (shown there: Loot), for the rig to hold it as
## the Player's does (a torch held up, a hook's coil, a bat in both hands, a gun).
var carried: RigidBody3D

## They have fired the gun they hold (the rig takes the kick, as the Player's does).
signal shot(kick: float)

## As the Player's, for the rig: a swing of what they hold (Loot tells of each:
## `swung`), and a gun brought up to fire and its aim (`fired`).
var swing_progress := 1.0
var swing_time := 0.6
var gun_handling := true
var gun_raise := 0.0
var gun_aim := Vector3.FORWARD
var _aim_hold := 0.0

var _target := Vector3.ZERO
var _target_velocity := Vector3.ZERO
var _target_yaw := 0.0
var _grounded := true
var _heard := false
## How long their game has had them off the ground (the rig reads it, as the Player's).
var air_time := 0.0

## What they are doing beyond walking and jumping, as their Player has it, for the
## rig to show: hanging, climbing, on a rope or a ladder, swimming, crawling, a
## landing... Their game sends these (DOINGS, in order) with each news of them.
const DOINGS: Array[StringName] = [
	&"state", &"is_ducking", &"is_crawling", &"is_sprinting", &"is_underwater", &"swim_clear",
	&"wade", &"dive_in", &"is_diving", &"dive_roll", &"climb_progress", &"rope_travel",
	&"ladder_travel", &"ladder_off", &"shimmy_travel", &"ledge_point", &"ledge_wall",
	&"landing", &"landing_progress", &"is_scrambling", &"hand_reach", &"hand_normal",
	&"hand_hook", &"hand_fingers", &"hand_points", &"foot_points", &"on_stairs", &"stair_run",
	&"stair_rise", &"stair_dir", &"stair_edge", &"tightrope", &"tightrope_aside", &"taut_progress",
]
## (these run on as they go, so between news they are eased along, not jumped)
const EASED: Array[StringName] = [&"rope_travel", &"ladder_travel", &"shimmy_travel"]
var state := 0
var is_ducking := false
var is_crawling := false
var is_sprinting := false
var is_underwater := false
var swim_clear := 1.0
var wade := 0.0
var dive_in := 0.0
var is_diving := false
var dive_roll := false
var climb_progress := 0.0
var rope_travel := 0.0
var ladder_travel := 0.0
var ladder_off := 0.0
var shimmy_travel := 0.0
var shimmy_speed := 0.8
var ledge_point := Vector3.ZERO
var ledge_wall := true
var landing := 0
var landing_progress := 1.0
var is_scrambling := false
var hand_reach := 0.0
var hand_normal := Vector3.ZERO
var hand_hook := 0.0
var hand_fingers := Vector3.ZERO
var hand_points := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var foot_points := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var on_stairs := 0.0
var stair_run := 0.4
var stair_rise := 0.0
var stair_dir := Vector3.FORWARD
var stair_edge := Vector3.ZERO
var tightrope := 0.0
var tightrope_aside := 0.0
var taut_progress := 1.0
var _eased_to := {}


func _init() -> void:
	super()
	# They pass through everyone, and only the floor and walls stop them.
	collision_layer = 0
	collision_mask = 1
	walk_speed = 1.6
	run_speed = 4.5


## Their latest news: where they are, how fast they are going, which way they
## face, and whether they are on the ground.
func hear(at: Vector3, moving: Vector3, yaw: float, grounded: bool) -> void:
	_target = at
	_target_velocity = moving
	_target_yaw = yaw
	_grounded = grounded
	if not _heard or global_position.distance_to(at) > 6.0:
		place(at, yaw)
	_heard = true


## What a Player is doing, as bytes for its news (DOINGS).
static func doings_of(player: Node) -> PackedByteArray:
	var values := []
	for key in DOINGS:
		values.append(player.get(key))
	return var_to_bytes(values)


## Their latest news of what they are doing (from doings_of).
func hear_doings(bytes: PackedByteArray) -> void:
	var values: Variant = bytes_to_var(bytes)
	if not (values is Array) or values.size() != DOINGS.size():
		return
	var was_state := state
	for i in DOINGS.size():
		var key := DOINGS[i]
		if key in EASED:
			_eased_to[key] = values[i]
		else:
			set(key, values[i])
	# (onto something new, its travel starts where they are on it)
	for key in EASED:
		if state != was_state or absf(float(get(key)) - float(_eased_to[key])) > 1.0:
			set(key, _eased_to[key])


func _physics_process(delta: float) -> void:
	if not _heard:
		return
	# Carry on as they were going, and close the gap to where they were last heard of.
	_target += _target_velocity * delta
	var wish := _target_velocity + (_target - global_position) * 6.0
	velocity = wish
	air_time = 0.0 if _grounded else air_time + delta
	# (on the ground they are pressed to it: nothing else pulls them down, and
	# without touching it the rig would hold them in a jump)
	if _grounded:
		velocity.y = minf(velocity.y, -1.0)
	move_and_slide()
	# (a wall between where they are drawn and where they are is no reason to lag behind)
	if global_position.distance_to(_target) > 2.5:
		global_position = _target
	_prev_pos = _curr_pos
	_curr_pos = global_position


## They have begun a swing of what they hold.
func swung() -> void:
	var kind: Variant = carried.get(&"kind") if is_instance_valid(carried) else null
	swing_time = LootItem.MELEE[kind]["swing"] if kind != null and kind in LootItem.MELEE else 0.6
	swing_progress = 0.0


## They have fired the gun they hold, along `aim`.
func fired(kick: float, aim: Vector3) -> void:
	gun_aim = aim
	gun_raise = 1.0
	_aim_hold = 1.3
	shot.emit(kick)


func _process(delta: float) -> void:
	super(delta)
	for key: StringName in _eased_to:
		set(key, lerpf(get(key), _eased_to[key], 1.0 - exp(-12.0 * delta)))
	if Vector2(_target_velocity.x, _target_velocity.z).length() < 0.3:
		facing_yaw = lerp_angle(facing_yaw, _target_yaw, 1.0 - exp(-8.0 * delta))
	if swing_progress < 1.0:
		swing_progress = minf(swing_progress + delta / swing_time, 1.0)
	if gun_raise > 0.0:
		_aim_hold -= delta
		if _aim_hold <= 0.0:
			gun_raise = move_toward(gun_raise, 0.0, delta / 0.45)
	else:
		# (lowered, a gun points the way they face)
		gun_aim = Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
