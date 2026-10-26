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
