class_name DogRig
extends Node3D
## Poses a feral dog (creatures/dog/models/dog_*.glb) in code, every frame,
## from what its Dog (the parent) says it is doing. After Outside's HoundRig:
## paws follow a gait cycle and are put down with IK, and the spine, neck,
## head, jaw and lips are laid on top; the tail and the ears are on springs.
##
## THE GAITS are a dog's, chosen by its speed: a four-beat walk (each hind paw
## lands a quarter of a stride before the fore paw on its side), a trot on
## diagonal pairs, and a rotary gallop (hind, hind, fore, fore round in a
## circle) in which the back stretches and gathers once a stride and the whole
## dog is off the ground once, gathered. Their timings, reach, lift and the
## body's rise, pitch and bend are measured from a real dog's motion capture
## (the AI4Animation dog, SIGGRAPH 2018): each stride centred under its hip or
## shoulder, as a real dog's is.
##
## WHAT IT DOES, on top of the gait (each eases in and out):
## - TRACKING: nose down. The head goes down to a hand's breadth off the
##   ground and casts from side to side along the trail, the nose working
##   (quick small jerks of the head), ears forward, the tail out level.
## - STALKING: stiff and low. It sinks on its legs with its shoulders hunched
##   up, its head held low and level with its back, stretched forward, its
##   tail straight out behind and still, hackles up, lip curled.
## - SNARLING: its upper lips are drawn up off its teeth (bones `lip_l` and
##   `lip_r`), the gums show, the jaw drops a little, the ears go back.
## - BARK and HOWL: the jaw keeps time with the voice it would have (there is
##   no sound here: the Dog's signals are where a game would play one). A
##   bark jerks the head and bounces the front of it; a howl throws the head
##   back, nose to the sky, the mouth an O that trembles.
## - THE LUNGE: it gathers itself down on its haunches, springs (it is
##   thrown up in an arc, stretched out, forelegs reaching, jaws wide), the
##   jaws snap shut, and it lands and takes the weight. (The Dog says when;
##   the game moves it forward by `Dog.lunge_push`.)
## - THE SHAKE: after a miss, a shake that runs from its head to its tail like
##   a wet dog's, ears flapping.
## - GLAD (friendly): its tail carried high and wagging hard, the whole of it,
##   its ears pricked up, its head up, hackles flat, its mouth a little open.
## - EATING: its head down to the ground, worrying at what it eats, jaws working.
## - Sitting and lying down, panting when it has run, the hackles (the Dog
##   sets the crest material's `bristle`).
##
## Every joint is read from the model's skeleton (tools/build_dog.py), so a
## model with other measurements on the same bones would do as well.

## Fore left, fore right, hind left, hind right.
const SUFFIXES: Array[String] = ["_fl", "_fr", "_rl", "_rr"]
## The model faces +Z.
const AHEAD := Vector3(0.0, 0.0, 1.0)
const BEHIND := Vector3(0.0, 0.0, -1.0)
## Where in the stride each paw lands, walking, trotting and galloping.
const WALK: Array[float] = [0.25, 0.75, 0.0, 0.5]
const TROT: Array[float] = [0.5, 1.0, 0.0, 0.5]
const GALLOP: Array[float] = [0.53, 0.38, 0.0, 0.16]
## The share of the stride a paw is down, fore and hind, at a walk, a trot and a gallop.
const DUTY_FORE := Vector3(0.63, 0.47, 0.25)
const DUTY_HIND := Vector3(0.62, 0.43, 0.23)
## Galloping faster, a paw is down for less of the stride: from FLAT_OUT.x to
## FLAT_OUT.y m/s its share falls to FLAT_OUT_DUTY of the gallop's (the mocap
## dog's: 0.22 at 3.6 m/s, 0.15 at 4.6, scaled to this model).
const FLAT_OUT := Vector2(3.95, 5.2)
const FLAT_OUT_DUTY := 0.66
## Galloping, the body rises and falls once a stride (m, for the model's size),
## highest at LOFT, in the flight; it pitches (radians), nose down most at
## PITCHED, as the forepaws take it; and its back arches (chest and pelvis,
## radians) most at ARCHED, the hind legs swung forward under it, and is
## stretched straightest half a stride from that, the hind legs driving.
const BOUND := 0.024
const LOFT := 0.72
const PITCH := 0.15
const PITCHED := 0.7
const ARCH := Vector2(0.1, 0.16)
const ARCHED := 0.64
## Speeds (m/s, for a dog of the model's size) over which it goes from a walk to a trot, and a trot to a gallop.
## (a pack at full chase is at a full gallop whatever its size: a gait half way
## between the two is a scrabble, not a run)
const TROT_AT := Vector2(1.0, 1.4)
const GALLOP_AT := Vector2(2.4, 3.0)
## Length of a stride (m) against speed (m/s).
const STRIDE := [0.0, 0.42, 0.8, 0.65, 1.8, 0.95, 2.7, 1.38, 3.9, 1.82, 5.5, 2.3, 9.0, 3.1]
const REACH := 0.42
## Galloping: how much further a paw may sweep under it, how far past where it
## lands a paw reaches out first (fore, hind), and how far back it is flung as
## it leaves the ground (fore, hind), m in the model.
const GALLOP_REACH := 1.4
const REACH_OUT := Vector2(0.15, 0.07)
const FLING_BACK := Vector2(0.06, 0.095)
## How high a forepaw is lifted (m, for the model's size) walking, trotting
## and galloping; a hind paw goes HIND_LIFT as high (walking, galloping).
const LIFT := Vector3(0.088, 0.125, 0.22)
const HIND_LIFT := Vector2(0.77, 0.95)
## Where a stride is centred: this far (m) behind the hip or shoulder.
const CENTRE := 0.01
## How far a shoulder (with its blade) and a hip slide toward where their paw is.
const GLIDE := Vector2(0.2, 0.08)
const FOLD := Vector2(3.4, 2.2)
const FOLD_PLANTED := Vector2(-0.25, 0.9)
## How the jaw goes (time in seconds, how far open) for a bark and the snap of a bite.
const BARK := [0.0, 0.0, 0.035, 1.0, 0.11, 0.8, 0.19, 0.0]
const SNAP := [0.0, 1.0, 0.05, 0.0, 0.13, 0.15, 0.2, 0.0]
## How far the jaw drops, wide open, radians.
const GAPE := 0.7
## Sitting and lying (as Outside's hounds).
const SIT_HIP := 0.125
const SIT_CHEST := -0.12
const SIT_PELVIS := 0.42
const SIT_SHOULDER := 0.985
const LIE_ROLL := 0.16
## How far the lips draw back and up to snarl (m, in the model).
const SNARL_LIFT := Vector3(0.003, 0.016, -0.010)
## A shake: how long, and how many times a second it goes from side to side.
const SHAKE_TIME := 1.1
const SHAKE_RATE := 4.6

## Use the demade, low-poly model. Set before it enters the tree.
var low_poly := false
## Which of the models (0, 1). Set before it enters the tree.
var variant := 0
## Layers of fur stood off the coat (none on the low-poly model).
var fur_shells := 2
var coat_tint := Color.WHITE
var mange := 0.2
var eyeshine := 0.5
## The materials, by name (see DogLook.dress).
var materials := {}


class Link:
	var joint: Node3D
	var bone := -1
	var rest := Vector3.DOWN
	var aim := Vector3.DOWN
	var twist := 0.0
	var length := 0.1
	var stiffness := 120.0
	var damping := 8.0
	var drag := 1.0
	var gravity := 6.0
	var limit := 1.2
	var outward := Vector3.ZERO
	var tip := Vector3.ZERO
	var velocity := Vector3.ZERO
	var held_tip := Vector3.ZERO


var _dog: Dog
var _skeleton: Skeleton3D
var _joints: Array[Node3D] = []
var _bones: Array[int] = []
var _body: Node3D
var _chest: Node3D
var _pelvis: Node3D
var _neck: Node3D
var _neck_1: Node3D
var _head: Node3D
var _jaw: Node3D
var _lips: Array[Node3D] = []
var _lip_rest: Array[Vector3] = []
var _legs: Array[Array] = []
var _tail: Array[Link] = []
var _ears: Array[Array] = [[], []]
var _links: Array[Link] = []
var _links_settled := false

var _body_rest := Vector3.ZERO
var _hips: Array[Vector3] = []
var _paws: Array[Vector3] = []
var _lengths: Array[Vector3] = []
var _spans: Array[float] = []
var _bends: Array[float] = []
var _frames: Array[Array] = []
var _size := 1.0
var _paw_height := 0.035
var _sit_pitch := -0.8
var _sit_body := Vector3.ZERO
var _sit_paws: Array[Vector3] = []
var _lie_body := Vector3.ZERO
var _lie_paws: Array[Vector3] = []
## Where the tip of its jaw is, in the head's space (for the bite).
var _jaw_tip := Vector3.ZERO

var _time := 0.0
var _phase := 0.0
var _pace := 0.0
var _air := 0.0
var _crouch := 0.0
var _crouch_velocity := 0.0
var _drop := 0.0
var _was_grounded := true
var _last_yaw := 0.0
var _turn := 0.0
var _mirrored := false
var _side := 1.0
var _sit := 0.0
var _lie := 0.0
var _lain := 0.0
var _doze := 0.0
var _mouth := 0.0
var _barked := 9.0
var _howl := 0.0
var _puffed := 0.0
var _breath := 0.0
var _wag := 0.0
var _wag_phase := 0.0
var _alert := 0.0
var _look := Vector2.ZERO
var _tilt := 0.0
var _ear_turn := Vector2.ZERO
var _ear_turn_to := Vector2.ZERO
var _ear_timer := 1.0
var _ear_flat := 0.0
var _twitch_timer := 3.0
## How far into each mood it is, 0..1.
var _track := 0.0
var _stalk := 0.0
var _snarl := 0.0
var _happy := 0.0
var _eat := 0.0
var _bristle := 0.0
## Tracking: the head casting from side to side, and the nose working.
var _cast := 0.0
var _sniff := 0.0
var _sniff_in := 0.0
var _shaken := 9.0


func _ready() -> void:
	_dog = get_parent() as Dog
	_build()
	_time = randf() * 10.0
	_mirrored = randf() < 0.5
	_side = 1.0 if randf() < 0.5 else -1.0
	_last_yaw = global_rotation.y


## Stands it as it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	_links_settled = false
	_crouch = 0.0
	_crouch_velocity = 0.0
	_air = 0.0
	_last_yaw = global_rotation.y
	_turn = 0.0


## Starts a bark (the jaw and the jerk of the head).
func bark() -> void:
	_barked = 0.0
	_crouch_velocity -= 1.2


## Starts a shake.
func shake() -> void:
	_shaken = 0.0
	for side in 2:
		_flick(side, Vector3(0.8 if side == 0 else -0.8, 0.5, 0.0))


func shaking() -> bool:
	return _shaken < SHAKE_TIME


## Where the tip of its jaw is, in the world.
func jaw_tip() -> Vector3:
	return _head.global_transform * _jaw_tip if _head else global_position


func _process(delta: float) -> void:
	if _dog == null or _skeleton == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta
	# (it works in the model's own size: a dog drawn twice as big strides as one this size going half as fast)
	var velocity := _dog.velocity / maxf(global_basis.get_scale().x, 0.01)
	var speed := Vector2(velocity.x, velocity.z).length()
	var grounded := _dog.grounded
	var yaw := global_rotation.y
	_turn = _approach(_turn, angle_difference(_last_yaw, yaw) / delta, 8.0, delta)
	_last_yaw = yaw

	# --- The lunge, from where the Dog is in it ---
	var stage := _dog.lunge_stage()
	var through := _dog.lunge_progress()
	var gather := 0.0
	var spring := 0.0
	var landing := 0.0
	match stage:
		Dog.Lunge.GATHER:
			gather = smoothstep(0.0, 1.0, through)
		Dog.Lunge.SPRING:
			spring = through
			gather = 1.0 - smoothstep(0.0, 0.25, through)
		Dog.Lunge.BITE:
			spring = 1.0
		Dog.Lunge.LAND:
			landing = 1.0 - through
	var flung := 1.0 if stage == Dog.Lunge.SPRING or stage == Dog.Lunge.BITE else 0.0
	if stage == Dog.Lunge.LAND and through < 0.05 and _air > 0.5:
		_crouch_velocity += 2.5
	_air = _approach(_air, 1.0 if (not grounded or flung > 0.0) else 0.0, 14.0, delta)

	# --- Moods ---
	_track = _approach(_track, 1.0 if _dog.tracking and stage == Dog.Lunge.NONE else 0.0, 3.0, delta)
	_stalk = _approach(_stalk, 1.0 if _dog.stalking and stage == Dog.Lunge.NONE else 0.0, 4.0, delta)
	var snarling := _dog.snarling or stage != Dog.Lunge.NONE
	_snarl = _approach(_snarl, 1.0 if snarling else 0.6 * _stalk, 9.0 if snarling else 4.0, delta)
	_howl = _approach(_howl, 1.0 if _dog.howling() else 0.0, 5.0 if _dog.howling() else 3.0, delta)
	var glad := _dog.friendly and not snarling and not _dog.stalking and stage == Dog.Lunge.NONE
	_happy = _approach(_happy, 1.0 if glad else 0.0, 3.0, delta)
	_eat = _approach(_eat, 1.0 if _dog.eating and stage == Dog.Lunge.NONE else 0.0, 5.0, delta)
	_bristle = _approach(_bristle, maxf(maxf(_stalk, _snarl), maxf(1.0 if stage != Dog.Lunge.NONE else 0.0, _track * 0.25)) * (1.0 - _happy), 6.0, delta)
	if materials.has("crest"):
		(materials["crest"] as ShaderMaterial).set_shader_parameter(&"bristle", _bristle)
	_barked += delta
	_shaken += delta
	_alert = _approach(_alert, 1.0 if _dog.look_at_point.is_finite() else 0.0, 4.0, delta)
	_puffed = clampf(_puffed + (speed / 5.0 * 0.22 - 0.05) * delta, 0.0, 1.0)
	if grounded and not _was_grounded:
		_crouch_velocity += clampf(-velocity.y * 0.3 + 1.0, 1.0, 3.0)
	_was_grounded = grounded
	_crouch_velocity += (-_crouch * 240.0 - _crouch_velocity * 22.0) * delta
	_crouch = clampf(_crouch + _crouch_velocity * delta, -0.03, 0.16)
	_settle(delta, grounded)
	var sit := smoothstep(0.0, 1.0, _sit)
	var lie := smoothstep(0.0, 1.0, _lie)

	# --- The gait ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 0.22), 10.0, delta)
	var trot := smoothstep(TROT_AT.x, TROT_AT.y, _pace)
	var gallop := smoothstep(GALLOP_AT.x, GALLOP_AT.y, _pace)
	var stride := _keyed(STRIDE, _pace) * lerpf(1.0, 0.75, _stalk)
	if grounded:
		_phase = fposmod(_phase + _pace / stride * delta, 1.0)
	var gait := smoothstep(0.05, 0.45, _pace) * (1.0 - _air) * (1.0 - sit)
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var lift := lerpf(lerpf(LIFT.x, LIFT.y, trot), LIFT.z, gallop) * _size * lerpf(1.0, 0.6, _stalk)
	var flying := gallop * gait
	var rise := cos(TAU * (_phase - LOFT)) * BOUND * _size * flying
	var targets: Array[Vector3] = []
	var pitches: Array[float] = []
	var load_fore := 0.0
	var load_hind := 0.0
	var drop := 0.0
	for i in 4:
		var fore := i < 2
		var duties := DUTY_FORE if fore else DUTY_HIND
		var duty := lerpf(lerpf(duties.x, duties.y, trot), duties.z * lerpf(1.0, FLAT_OUT_DUTY, smoothstep(FLAT_OUT.x, FLAT_OUT.y, _pace)), gallop)
		duty = lerpf(duty, minf(duty + 0.12, 0.8), _stalk)
		var span := minf(duty * stride, REACH * lerpf(1.0, GALLOP_REACH, gallop) * _size) * travel
		var middle := (_hips[i].z - _paws[i].z - CENTRE * _size) * travel
		var other := i ^ 1 if _mirrored else i
		var at := fposmod(_phase - lerpf(lerpf(WALK[i], TROT[i], trot), GALLOP[other], gallop), 1.0)
		var cycle := _foot_cycle(at, duty, span * 0.5, lift * (1.0 if fore else lerpf(HIND_LIFT.x, HIND_LIFT.y, gallop)))
		if at >= duty and flying > 0.0:
			# Galloping, a paw is flung out behind as it leaves the ground, and
			# reaches out ahead before it lands (drawn back under it as it does).
			var swing := (at - duty) / (1.0 - duty)
			var out: float = REACH_OUT.x if fore else REACH_OUT.y
			var back: float = FLING_BACK.x if fore else FLING_BACK.y
			cycle.z += (out * sin(PI * smoothstep(0.4, 1.0, swing)) - back * sin(PI * clampf(swing / 0.4, 0.0, 1.0))) * _size * travel * flying
		var rest := _paws[i]
		var carried := 0.0
		if at >= duty:
			var swing := (at - duty) / (1.0 - duty)
			carried = clampf(minf(swing, 1.0 - swing) * 6.0, 0.0, 1.0) * maxf(rise, 0.0)
		# (stalking, its paws go wider apart and a little further forward: it is braced)
		var wide := 1.0 + 0.12 * _stalk
		targets.append(Vector3(rest.x * lerpf(1.0, 0.72, trot * gait) * wide, _paw_height + (cycle.y + carried) * gait, rest.z + (middle + cycle.z) * gait))
		pitches.append(cycle.x * gait)
		if at < duty:
			var bearing := sin(PI * at / duty)
			if fore:
				load_fore += bearing
			else:
				load_hind += bearing
		var from_hip := rest.z - _hips[i].z + middle * gait
		# (galloping it is not lowered to reach the ends of its stride: the back
		# bends and stretches for them instead)
		var furthest := (absf(from_hip) + span * 0.5 * gait * (1.0 - 0.45 * flying)) * (1.0 - (GLIDE.x if fore else GLIDE.y))
		var total := _lengths[i].x + _lengths[i].y + _lengths[i].z - 0.012
		drop = maxf(drop, _hips[i].y - _paw_height - sqrt(maxf(total * total - furthest * furthest, 0.01)))

	_drop = _approach(_drop, drop + 0.004, 9.0, delta)
	var sprung := 0.016 * trot * (1.0 - gallop)
	var vault := 0.014 * (1.0 - trot)
	var high_fore := ((load_fore - 0.7) * vault - (load_fore - 0.5) * sprung) * gait
	var high_hind := ((load_hind - 0.7) * vault - (load_hind - 0.5) * sprung) * gait
	var rock := (high_hind - high_fore) / 0.42 + cos(TAU * (_phase - PITCHED)) * PITCH * flying
	var back_bend := cos(TAU * (_phase - ARCHED)) * flying
	var bend := clampf(_turn * 0.06, -0.3, 0.3) * (1.0 - sit)
	var swing_fore := (targets[1].z - targets[0].z) * 0.22 * (1.0 - gallop)
	var swing_hind := (targets[3].z - targets[2].z) * 0.28 * (1.0 - gallop)
	var bank := clampf(-_turn * speed * 0.012, -0.22, 0.22)

	var air_pitch := _air * clampf(-velocity.y * 0.04, -0.4, 0.4) * (1.0 - flung)
	var body_at := _body_rest + Vector3(0.0, -_drop - _crouch + (high_fore + high_hind) * 0.5 + rise, 0.0)
	var body_turn := Vector3(air_pitch + rock, 0.0, bank)
	var chest_turn := Vector3(back_bend * ARCH.x, bend + swing_fore, (targets[0].y - targets[1].y) * 0.5)
	var pelvis_turn := Vector3(-back_bend * ARCH.y,-bend * 0.7 + swing_hind, (targets[2].y - targets[3].y) * 0.6)
	var poles: Array[Vector3] = [BEHIND, BEHIND, AHEAD, AHEAD]
	var flat: Array[float] = [0.0, 0.0, 0.0, 0.0]

	# Tracking: the front of it a little lower, nose to the ground.
	body_turn.x += 0.12 * maxf(_track, _eat)
	# Stalking: down on bent legs, the shoulders hunched up over the forelegs, rump low.
	body_at.y -= 0.075 * _size * _stalk
	chest_turn.x += -0.10 * _stalk
	pelvis_turn.x += 0.06 * _stalk
	# The lunge: gathered down on its haunches, then flung up in an arc,
	# stretched out, and down onto its forelegs.
	if gather > 0.0:
		body_at.y -= 0.11 * _size * gather
		body_at.z -= 0.04 * _size * gather
		pelvis_turn.x += 0.28 * gather
		chest_turn.x += 0.05 * gather
		body_turn.x += 0.06 * gather
	if flung > 0.0 or landing > 0.0:
		var arc := sin(PI * clampf(spring, 0.0, 1.0)) * flung
		position.y = arc * 0.22 * _size
		body_turn.x += lerpf(-0.28, 0.22, spring) * flung + 0.12 * landing
		pelvis_turn.x -= 0.25 * flung
	else:
		position.y = 0.0
	# The shake: from head to tail, side to side, dying away.
	var shook := 0.0
	if _shaken < SHAKE_TIME:
		var u := _shaken / SHAKE_TIME
		shook = sin(PI * u) * (1.0 - u * 0.3)
		var w := TAU * SHAKE_RATE * _shaken
		chest_turn.z += sin(w - 0.6) * 0.26 * shook
		pelvis_turn.z += sin(w - 1.4) * 0.24 * shook
		body_turn.z += sin(w - 1.0) * 0.08 * shook
		body_at.x += sin(w - 1.0) * 0.012 * _size * shook
		if int(_shaken * SHAKE_RATE * 2.0) != int((_shaken - delta) * SHAKE_RATE * 2.0):
			for side in 2:
				_flick(side, Vector3(sin(w) * 1.2, 0.6, 0.0))

	if sit > 0.0:
		body_at = body_at.lerp(_sit_body, sit)
		body_turn = body_turn.lerp(Vector3(_sit_pitch, 0.0, 0.0), sit)
		chest_turn = chest_turn.lerp(Vector3(SIT_CHEST, 0.0, 0.0), sit)
		pelvis_turn = pelvis_turn.lerp(Vector3(SIT_PELVIS, 0.0, 0.0), sit)
		for i in 4:
			var step := clampf(_sit * 2.0 - (0.0 if i == 0 or i == 3 else 0.9), 0.0, 1.0)
			targets[i] = targets[i].lerp(_sit_paws[i], smoothstep(0.0, 1.0, step)) + Vector3.UP * sin(PI * step) * 0.035
			pitches[i] *= 1.0 - sit
			if i >= 2:
				poles[i] = AHEAD.slerp(Vector3(signf(_hips[i].x) * 0.5, 0.6, 1.0).normalized(), sit)
				flat[i] = smoothstep(0.35, 0.9, sit)
	if lie > 0.0:
		body_at = body_at.lerp(_lie_body, lie)
		body_turn = body_turn.lerp(Vector3(-0.03, 0.0, -_side * 0.06), lie)
		chest_turn = chest_turn.lerp(Vector3(0.1 * _doze, 0.0, 0.0), lie)
		pelvis_turn = pelvis_turn.lerp(Vector3(0.12, 0.0, -_side * LIE_ROLL), lie)
		for i in 4:
			var step := clampf(_lie * 1.6 - (0.0 if i == 0 or i == 3 else 0.5), 0.0, 1.0)
			if i >= 2:
				poles[i] = poles[i].slerp(Vector3(signf(_hips[i].x) * 0.75, 0.25, 1.0).normalized(), lie)
			else:
				poles[i] = poles[i].slerp(Vector3(signf(_hips[i].x) * 0.12, -0.5, -1.0).normalized(), lie)
				flat[i] = smoothstep(0.3, 0.9, lie)
			targets[i] = targets[i].lerp(_lie_paws[i], smoothstep(0.0, 1.0, step)) + Vector3.UP * sin(PI * step) * 0.03
	if gather > 0.0:
		# (the hind paws come forward under it, to drive)
		for i in [2, 3]:
			targets[i] = targets[i] + Vector3(0.0, 0.0, 0.07 * _size * gather)
	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = chest_turn
	_pelvis.rotation = pelvis_turn
	_breathe(delta, sit)
	_look_about(delta)
	_pose_head(delta, body_turn.x + chest_turn.x, lerpf(1.0, 0.75, gallop), sit, lie, flying, gather, flung, shook)
	_pose_jaw(stage, through, flung)
	_pose_legs(targets, pitches, poles, flat, velocity.y, flung, spring)
	_carry_tail(delta, gallop, sit, lie, flung, shook)
	_carry_ears(delta, gallop)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)
	_swing(delta)


## Into and out of sitting and lying. It sits before it lies, and gets up far faster than it went down.
func _settle(delta: float, grounded: bool) -> void:
	var resting := grounded and (_dog.sitting or _dog.lying or _dog.howling() and _dog.sit_to_howl)
	_sit = move_toward(_sit, 1.0 if resting else 0.0, delta / (0.75 if resting else 0.3))
	var lying := grounded and _dog.lying and _sit > 0.85
	_lie = move_toward(_lie, 1.0 if lying else 0.0, delta / (1.1 if lying else 0.3))
	_lain = _lain + delta if _lie >= 1.0 else 0.0
	_doze = _approach(_doze, 1.0 if _lain > 2.0 else 0.0, 1.3 if _lain > 2.0 else 8.0, delta)


## Its ribs: slow and deep asleep, quick and shallow when it is out of breath.
func _breathe(delta: float, sit: float) -> void:
	var panting := smoothstep(0.25, 0.6, _puffed) * (1.0 - _doze)
	_breath += delta * TAU * lerpf(lerpf(0.45, 0.25, _doze), 3.6, panting)
	var swell := sin(_breath) * lerpf(lerpf(0.014, 0.034, _doze), 0.024, panting)
	_chest.scale = Vector3(1.0 + swell, 1.0 + swell, 1.0)
	_neck.scale = Vector3.ONE / _chest.scale
	_body.position.y += swell * 0.2 * sit


## Head and neck: kept level whatever the body under them is doing, turned to
## what it watches; nose to the ground on a trail, low and level stalking,
## thrown back to howl, thrust out springing, shaking with the rest of it.
func _pose_head(delta: float, upstream: float, level: float, sit: float, lie: float, flying: float, gather: float, flung: float, shook: float) -> void:
	var awake := 1.0 - _doze
	_tilt = _approach(_tilt, 0.0, 5.0, delta)
	# Casting about on the trail, and the quick small jerks of a nose at work.
	_cast += delta * lerpf(1.1, 0.4, clampf(_pace / 3.0, 0.0, 1.0))
	_sniff_in -= delta
	if _sniff_in <= 0.0:
		_sniff_in = randf_range(0.08, 0.22) if randf() < 0.85 else randf_range(0.5, 0.9)
		_sniff = randf_range(-1.0, 1.0)
	var cast := sin(_cast * 2.1) * 0.32 + sin(_cast * 3.7 + 1.0) * 0.1
	var yaw := _look.x * awake * (1.0 - _track) * (1.0 - _eat) + cast * _track + _sniff * 0.03 * _track
	var pitch := _look.y * awake * (1.0 - _track) * (1.0 - _stalk) * (1.0 - _eat)
	# Nose down: the neck goes down and forward, the head turns down at the end of it.
	pitch += 1.4 * _track + _sniff * 0.025 * _track
	# Stalking: the neck stretched forward, level with the back; the head low.
	pitch += 0.35 * _stalk - 0.15 * _stalk
	# Howling: nose to the sky.
	pitch -= 1.25 * _howl
	# Eating: head down to it on the ground, worrying at it. Glad: the head carried up.
	pitch += 1.5 * _eat * (1.0 - _track) + sin(_time * 5.3) * 0.06 * _eat
	pitch -= 0.12 * _happy * (1.0 - _eat)
	# Snarling: the head a little lower, so it looks up from under its brow.
	pitch += 0.12 * _snarl * (1.0 - _howl)
	var laid := lie * _doze
	_chest.rotation.y += yaw * 0.1 * (1.0 - sit)
	var stretch := flying * (0.2 + 0.25 * _size * _size + 0.08 * sin(TAU * (_phase - ARCHED + 0.25))) + 0.35 * _stalk + 0.5 * flung + 0.2 * gather
	var neck := Vector3(-upstream * 0.55 * level + pitch * 0.5 + laid * 1.2 + lie * awake * 0.2 + stretch, yaw * 0.45, 0.0)
	var head := Vector3(-upstream * 0.45 * level + pitch * 0.5 - laid * 1.0 - lie * awake * 0.2 - stretch * 0.8, yaw * 0.45, _tilt)
	if shook > 0.0:
		var w := TAU * SHAKE_RATE * _shaken
		neck.y += sin(w) * 0.35 * shook
		head.z += sin(w + 0.4) * 0.55 * shook
		head.y += sin(w + 0.2) * 0.2 * shook
	if _howl > 0.0:
		# (the howl trembles at the throat)
		head.x += sin(_time * 31.0) * 0.015 * _howl
	_neck.rotation = neck * 0.5
	_neck_1.rotation = neck * 0.5
	_head.rotation = head


## The jaw: the bark, the howl, the snap of a bite, a snarl's half-open
## mouth, and panting. The lips are drawn up for a snarl.
func _pose_jaw(stage: int, through: float, flung: float) -> void:
	var open := _keyed(BARK, _barked)
	open = maxf(open, _howl * (0.48 + 0.06 * sin(_time * 9.0)))
	open = maxf(open, 0.2 * _snarl)
	if stage == Dog.Lunge.GATHER:
		open = maxf(open, 0.35 * through)
	elif stage == Dog.Lunge.SPRING:
		open = maxf(open, lerpf(0.35, 1.0, smoothstep(0.0, 0.5, through)))
	elif stage == Dog.Lunge.BITE:
		open = _keyed(SNAP, through * Dog.BITE_TIME)
	var panting := smoothstep(0.25, 0.6, _puffed) * (1.0 - _doze) * (1.0 - _snarl)
	open = maxf(open, panting * (0.25 + 0.08 * sin(_breath)))
	# (glad, its mouth hangs a little open; eating, its jaws work)
	open = maxf(open, _happy * (0.16 + 0.04 * sin(_breath)))
	open = maxf(open, _eat * (0.08 + 0.22 * maxf(sin(_time * 10.5), 0.0)))
	_mouth = lerpf(_mouth, open, 0.6)
	_jaw.rotation.x = _mouth * GAPE
	var lift := maxf(_snarl, flung) * (1.0 - _howl * 0.7)
	for side in 2:
		var out := 1.0 if side == 0 else -1.0
		_lips[side].position = _lip_rest[side] + Vector3(SNARL_LIFT.x * out, SNARL_LIFT.y, SNARL_LIFT.z) * lift
		_lips[side].rotation = Vector3(-0.12 * lift, 0.0, -out * 0.12 * lift)


func _pose_legs(targets: Array[Vector3], pitches: Array[float], poles: Array[Vector3], flat: Array[float], vertical_speed: float, flung: float, spring: float) -> void:
	var to_body := _body.transform.affine_inverse()
	var rising := clampf(vertical_speed / 5.0, -1.0, 1.0) * 0.5 + 0.5
	if flung > 0.0:
		# (flung at him: stretched out going up, forelegs reaching for him coming down)
		rising = 1.0 - smoothstep(0.3, 0.9, spring)
	for i in 4:
		var fore := i < 2
		var rest := _paws[i]
		var stretched := rest + Vector3(0.0, 0.13, 0.30 if fore else -0.30) * _size
		var landing := rest + Vector3(0.0, 0.10 if fore else 0.17, 0.24 if fore else -0.04) * _size
		var target := targets[i].lerp(landing.lerp(stretched, rising), _air)
		var spine := _chest if fore else _pelvis
		var hip := spine.transform * (_hips[i] - _body_rest - spine.position)
		var paw := to_body * target
		# (where its stride is centred, moving; where it stands, still)
		var under := hip.z + lerpf(rest.z - _hips[i].z, -CENTRE * _size, minf(_pace / TROT_AT.x, 1.0))
		hip.z += clampf((paw.z - under) * (GLIDE.x if fore else GLIDE.y), -0.07, 0.07)
		var lifted := maxf(_air, clampf((target.y - _paw_height) / (0.05 * _size), 0.0, 1.0))
		_solve_leg(i, hip, paw, to_body.basis * Basis(Vector3.RIGHT, lerpf(pitches[i], 0.5, _air)), to_body.basis * poles[i], to_body.basis * AHEAD,
				flat[i] * (1.0 - _air), lifted)


func _foot_cycle(phase: float, duty: float, half_step: float, lift: float) -> Vector3:
	if phase < duty:
		var planted := phase / duty
		return Vector3(smoothstep(0.65, 1.0, planted) * 0.55, 0.0, lerpf(half_step, -half_step, planted))
	var swing := (phase - duty) / (1.0 - duty)
	return Vector3(lerpf(0.75, -0.22, smoothstep(0.0, 0.8, swing)), sin(PI * pow(swing, 0.75)) * lift, lerpf(-half_step, half_step, smoothstep(0.0, 1.0, swing)))


## Three-bone IK in body space, folding in a zigzag (Outside's HoundRig._solve_leg).
func _solve_leg(index: int, hip: Vector3, target: Vector3, paw_basis: Basis, pole: Vector3, ground: Vector3, flat: float, lifted: float) -> void:
	var lengths := _lengths[index]
	var total := lengths.x + lengths.y + lengths.z
	var to_target := target - hip
	var reach := clampf(to_target.length(), 0.06, total - 0.004)
	var line := to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.DOWN
	var aside := pole - line * pole.dot(line)
	aside = aside.normalized() if aside.length_squared() > 0.0001 else AHEAD
	var paw := hip + line * reach
	var span := _spans[index]
	var bend := _bends[index]
	if reach > span:
		bend *= (total - reach) / (total - span)
	else:
		var fore := index < 2
		bend += (span - reach) / span * lerpf(FOLD_PLANTED.x if fore else FOLD_PLANTED.y, FOLD.x if fore else FOLD.y, lifted)
	var last := line * cos(bend) + aside * sin(bend)
	if flat > 0.0:
		last = last.slerp(ground, flat).normalized()
	var far := lengths.x + lengths.y - 0.003
	var near := absf(lengths.x - lengths.y) + 0.01
	var second := paw - last * lengths.z
	for attempt in 8:
		if (second - hip).length() <= far:
			break
		last = last.slerp(line, 0.3).normalized()
		second = paw - last * lengths.z
	var across := second - hip
	var gap := clampf(across.length(), near, far)
	var along := across.normalized()
	second = hip + along * gap
	paw = second + last * lengths.z
	var off := aside - along * aside.dot(along)
	off = off.normalized() if off.length_squared() > 0.0001 else aside
	var fold := acos(clampf((lengths.x * lengths.x + gap * gap - lengths.y * lengths.y) / (2.0 * lengths.x * gap), -1.0, 1.0))
	var first := hip + (along * cos(fold) + off * sin(fold)) * lengths.x
	var normal := aside.cross(line).normalized()
	var bones: Array = _legs[index]
	var frames: Array = _frames[index]
	(bones[0] as Node3D).transform = Transform3D(_frame(normal, (first - hip).normalized()) * frames[0], hip)
	(bones[1] as Node3D).transform = Transform3D(_frame(normal, (second - first).normalized()) * frames[1], first)
	(bones[2] as Node3D).transform = Transform3D(_frame(normal, last) * frames[2], second)
	(bones[3] as Node3D).transform = Transform3D(paw_basis, paw)


static func _frame(normal: Vector3, along: Vector3) -> Basis:
	var x := (normal - along * normal.dot(along)).normalized()
	return Basis(x, -along, x.cross(-along))


## Turns its head towards what it is watching (the Dog's `look_at_point`), or
## lets it gaze about.
func _look_about(delta: float) -> void:
	var target := Vector2.ZERO
	var point := _dog.look_at_point
	if point.is_finite() and _head:
		var to := point - _head.global_position
		target.x = clampf(angle_difference(global_rotation.y, atan2(to.x, to.z)), -1.6, 1.6)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.9, 0.6)
	else:
		target.x = sin(_time * 0.41) * 0.3 + sin(_time * 0.9 + 1.0) * 0.1
		target.y = 0.08 + sin(_time * 0.3 + 2.0) * 0.06
	_look = _look.lerp(target, 1.0 - exp(-(10.0 if _alert > 0.5 else 6.0) * delta))


## How the tail is carried: out level on a trail (and waving a little, keen),
## straight back and stiff stalking, streaming at a gallop, low howling, down
## when it is at rest; flung about in a shake.
func _carry_tail(delta: float, gallop: float, sit: float, lie: float, flung: float, shook: float) -> void:
	# (glad, the tail is carried up and wags hard, the whole of it, faster the gladder; less at a gallop)
	_wag = _approach(_wag, maxf(0.5 * _track, _happy * lerpf(1.0, 0.45, gallop) * (1.0 - 0.5 * lie)), 4.0, delta)
	_wag_phase += delta * TAU * lerpf(2.4, 4.6, _wag)
	var carried := 0.05 + 0.35 * _track + 0.5 * _stalk + 0.3 * gallop + 0.3 * _alert * (1.0 - _stalk) - 0.35 * _howl + 0.4 * flung + 0.55 * _happy
	carried = lerpf(carried, 0.35, sit)
	carried = lerpf(carried, 0.05, lie)
	for i in _tail.size():
		var link := _tail[i]
		var swing := sin(_wag_phase - i * 0.8) * _wag * ((0.3 if i == 0 else 0.2) + 0.3 * _happy) + lie * _side * 0.3
		if shook > 0.0:
			swing += sin(TAU * SHAKE_RATE * _shaken - 2.0 - i * 0.5) * 0.5 * shook
		var curl := carried - _pelvis.rotation.x * 0.8 - _body.rotation.x * 0.5 * (1.0 - sit) if i == 0 else -gallop * 0.08 - _stalk * 0.05
		link.aim = Basis(Vector3.UP, swing) * Basis(Vector3.RIGHT, curl) * link.rest
		link.limit = lerpf(lerpf(0.7, 0.14, gallop), 0.12, _stalk)
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = randf_range(2.5, 6.0)
		if _sit < 0.1 and _alert < 0.5 and randf() < 0.4:
			var which := randi() % 2
			_flick(which, Vector3(0.7 if which == 0 else -0.7, 0.3, 0.0))


func _flick(which: int, push: Vector3) -> void:
	for link: Link in _ears[which]:
		link.velocity += (link.joint.get_parent() as Node3D).global_basis * push * 2.0


## The ears: forward on a trail or stalking, laid back flat to snarl, howl, or
## run flat out, one or other turned aside to listen when it is at ease.
func _carry_ears(delta: float, gallop: float) -> void:
	var flat := maxf(gallop * 0.7, maxf(_snarl * 0.85, _howl * 0.75))
	flat = maxf(flat, _doze * 0.55) * (1.0 - 0.6 * _stalk) * (1.0 - 0.8 * _happy)
	_ear_flat = _approach(_ear_flat, clampf(flat, 0.0, 1.0), 9.0 if flat > _ear_flat else 4.0, delta)
	_ear_timer -= delta
	if _ear_timer <= 0.0:
		_ear_timer = randf_range(0.7, 2.6)
		var pick := randi() % 4
		_ear_turn_to = Vector2(randf_range(0.5, 1.1) if pick == 0 else 0.0, randf_range(0.5, 1.1) if pick == 1 else 0.0)
	var listening := (1.0 - _alert) * (1.0 - _ear_flat) * (1.0 - _track)
	_ear_turn = _ear_turn.lerp(_ear_turn_to * listening, 1.0 - exp(-9.0 * delta))
	# (glad, the ears are up and a little forward: pricked)
	var forward := maxf(maxf(_track, _stalk), 0.7 * _happy)
	for side in 2:
		var out := 1.0 if side == 0 else -1.0
		var turn: float = _ear_turn[side]
		var root: Link = _ears[side][0]
		var flap: Link = _ears[side][1]
		var lean := Basis(Vector3.RIGHT, -_ear_flat * 1.0 - turn * 0.3 + forward * 0.45) * Basis(BEHIND, out * (_ear_flat * 0.3 + turn * 0.45 - _alert * 0.07 - forward * 0.12))
		root.aim = lean * root.rest
		root.twist = out * (turn + _ear_flat * 0.5)
		flap.aim = Basis(Vector3.RIGHT, -_ear_flat * 0.25 + forward * 0.2) * flap.rest


func _swing(delta: float) -> void:
	var ground := global_position.y - position.y + 0.02
	for link in _links:
		var parent := (link.joint.get_parent() as Node3D).global_transform
		var frame := parent.basis.orthonormalized()
		var root := parent * link.joint.position
		var held_tip := root + frame * link.aim * link.length * parent.basis.get_scale().x
		if not _links_settled:
			link.tip = held_tip
			link.held_tip = held_tip
			link.velocity = Vector3.ZERO
		var held_velocity := (held_tip - link.held_tip) / delta
		link.held_tip = held_tip
		var before := link.tip
		var pull := (held_tip - link.tip) * link.stiffness - (link.velocity - held_velocity) * link.damping
		link.velocity += (pull - link.velocity * link.drag + Vector3.DOWN * link.gravity) * delta
		link.tip += link.velocity * delta
		link.tip.y = maxf(link.tip.y, ground)
		var along := (link.tip - root).normalized()
		var held := (held_tip - root).normalized()
		var off := held.angle_to(along)
		if off > link.limit:
			along = held.slerp(along, link.limit / off)
		if link.outward != Vector3.ZERO:
			var out := frame * link.outward
			var outness := along.dot(out)
			if outness < -0.02:
				along = (along + out * (-0.02 - outness)).normalized()
		link.tip = root + along * (held_tip - root).length()
		link.velocity = (link.tip - before) / delta
		link.joint.basis = Basis(Quaternion(link.rest, (frame.inverse() * along).normalized())) * Basis(link.rest, link.twist)
		_skeleton.set_bone_pose(link.bone, link.joint.transform)
	_links_settled = true


static func _approach(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))


## Reads a curve drawn by hand: (time, value) pairs, joined smoothly.
static func _keyed(keys: Array, time: float) -> float:
	var last := keys.size() / 2 - 1
	if time <= keys[0]:
		return keys[1]
	if time >= keys[last * 2]:
		return keys[last * 2 + 1]
	var k := 0
	while time > keys[k * 2 + 2]:
		k += 1
	var t0: float = keys[k * 2]
	var t1: float = keys[k * 2 + 2]
	var v0: float = keys[k * 2 + 1]
	var v1: float = keys[k * 2 + 3]
	var m0: float = (v1 - keys[k * 2 - 1]) / (t1 - keys[k * 2 - 2]) if k > 0 else 0.0
	var m1: float = (keys[k * 2 + 5] - v0) / (keys[k * 2 + 4] - t0) if k < last - 1 else 0.0
	var span := t1 - t0
	var u := (time - t0) / span
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * v0 + (u3 - 2.0 * u2 + u) * span * m0 + (-2.0 * u3 + 3.0 * u2) * v1 + (u3 - u2) * span * m1


## The model it poses. A rig that extends this one for another animal on the
## same bones (the coyote's) gives its own.
func _model_path() -> String:
	return "res://creatures/dog/models/dog_%s%s.glb" % ["b" if variant == 1 else "a", "_lo" if low_poly else ""]


## Gives the model its materials, and says which is which (see DogLook.dress).
func _dress(model: Node) -> Dictionary:
	return DogLook.dress(model, coat_tint, 0 if low_poly else fur_shells, mange, eyeshine)


func _build() -> void:
	var model: Node = (load(_model_path()) as PackedScene).instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	materials = _dress(model)
	_body_rest = _rest(&"body")
	_body = _joint(self, &"body")
	_chest = _joint(_body, &"chest")
	_pelvis = _joint(_body, &"pelvis")
	_neck = _joint(_chest, &"neck")
	_neck_1 = _joint(_neck, &"neck_1")
	_head = _joint(_neck_1, &"head")
	_jaw = _joint(_head, &"jaw")
	for suffix in ["_l", "_r"]:
		var lip := _joint(_head, "lip" + suffix)
		_lips.append(lip)
		_lip_rest.append(lip.position)
	# (the jaw's tip: about as far ahead of the jaw's root as the mouth is long)
	_jaw_tip = _jaw.position + Vector3(0.0, -0.03, 0.17)
	for i in 4:
		var fore := i < 2
		var bones: Array = []
		var at: Array[Vector3] = []
		for bone: String in ["upper", "lower", "hock", "paw"]:
			bones.append(_joint(_body, bone + SUFFIXES[i]))
			at.append(_body_rest + _rest(bone + SUFFIXES[i]))
		_legs.append(bones)
		_hips.append(at[0])
		_paws.append(at[3])
		_lengths.append(Vector3(at[0].distance_to(at[1]), at[1].distance_to(at[2]), at[2].distance_to(at[3])))
		var line := (at[3] - at[0]).normalized()
		var pole := BEHIND if fore else AHEAD
		var aside := (pole - line * pole.dot(line)).normalized()
		var normal := aside.cross(line).normalized()
		var last := (at[3] - at[2]).normalized()
		_spans.append(at[0].distance_to(at[3]))
		_bends.append(atan2(last.dot(aside), last.dot(line)))
		_frames.append([
			_frame(normal, (at[1] - at[0]).normalized()).inverse(), _frame(normal, (at[2] - at[1]).normalized()).inverse(),
			_frame(normal, last).inverse(),
		])
	_paw_height = _paws[0].y
	_size = _hips[2].y / 0.52
	_measure()
	var from := _pelvis
	var names: Array[String] = ["tail", "tail_1", "tail_2", "tail_3", "tail_end"]
	for i in 4:
		var link := _link(from, names[i], _rest(names[i + 1]))
		link.stiffness = lerpf(1800.0, 700.0, i / 3.0)
		link.damping = lerpf(50.0, 26.0, i / 3.0)
		link.gravity = 3.0
		link.limit = 0.7
		_tail.append(link)
		from = link.joint
	for side in 2:
		var suffix := "_l" if side == 0 else "_r"
		var root := _link(_head, "ear" + suffix, _rest("ear_tip" + suffix))
		var flap := _link(root.joint, "ear_tip" + suffix, _rest("ear_end" + suffix))
		for link: Link in [root, flap]:
			link.stiffness = 900.0 if link == root else 420.0
			link.damping = 20.0 if link == root else 9.0
			link.gravity = 0.0 if link == root else 2.0
			link.drag = 0.5
			link.limit = 0.5 if link == root else 0.8
		_ears[side] = [root, flap]


## Works out, from how it is built, where it puts itself to sit and to lie (as Outside's hounds).
func _measure() -> void:
	var chest_at := _chest.position
	var pelvis_at := _pelvis.position
	var shoulder := _hips[0] - _body_rest - chest_at
	var hip := _hips[2] - _body_rest - pelvis_at
	shoulder.x = 0.0
	hip.x = 0.0
	var sit_hip := SIT_HIP * _size
	var want := _hips[0].y * SIT_SHOULDER - sit_hip
	var low := -1.45
	var high := 0.0
	var shoulder_at := Vector3.ZERO
	var hip_at := Vector3.ZERO
	for step in 24:
		_sit_pitch = (low + high) * 0.5
		var back := Basis(Vector3.RIGHT, _sit_pitch)
		shoulder_at = back * (chest_at + Basis(Vector3.RIGHT, SIT_CHEST) * shoulder)
		hip_at = back * (pelvis_at + Basis(Vector3.RIGHT, SIT_PELVIS) * hip)
		if shoulder_at.y - hip_at.y < want:
			high = _sit_pitch
		else:
			low = _sit_pitch
	_sit_body = Vector3(0.0, sit_hip - hip_at.y, _paws[2].z + 0.05 * _size - hip_at.z)
	_sit_paws.clear()
	for i in 4:
		var side := signf(_paws[i].x)
		if i < 2:
			var top := _sit_body + shoulder_at
			_sit_paws.append(Vector3(_paws[i].x * 0.9, _paw_height, top.z + _paws[i].z - _hips[i].z + (0.006 if i == 0 else -0.006)))
		else:
			var top := _sit_body + hip_at
			_sit_paws.append(Vector3(_paws[i].x + side * 0.055 * _size, _paw_height, top.z + 0.035 * _size + _lengths[i].z))
	var elbow_height: float = _body_rest.y + (_legs[0][1] as Node3D).position.y
	_lie_body = Vector3(0.0, _body_rest.y - elbow_height + 0.012 * _size, _body_rest.z - 0.03 * _size)
	_lie_paws.clear()
	for i in 4:
		var side := signf(_paws[i].x)
		var top := _hips[i] - _body_rest + _lie_body
		if i < 2:
			var fall := clampf(top.y - 0.045 * _size, 0.0, _lengths[i].x * 0.98)
			var back := sqrt(_lengths[i].x * _lengths[i].x - fall * fall)
			_lie_paws.append(Vector3(_paws[i].x * 0.95, _paw_height, top.z - back + _lengths[i].y + _lengths[i].z - (0.012 if i == 0 else 0.03) * _size))
		else:
			_lie_paws.append(Vector3(_paws[i].x + side * 0.05 * _size, _paw_height, top.z + (0.13 if i == 2 else 0.1) * _size))


func _rest(bone: StringName) -> Vector3:
	return _skeleton.get_bone_rest(_skeleton.find_bone(bone)).origin


func _joint(parent: Node3D, bone: StringName) -> Node3D:
	var joint := Node3D.new()
	var index := _skeleton.find_bone(bone)
	joint.name = bone
	joint.position = _skeleton.get_bone_rest(index).origin
	parent.add_child(joint)
	_joints.append(joint)
	_bones.append(index)
	return joint


func _link(parent: Node3D, bone: StringName, end: Vector3) -> Link:
	var link := Link.new()
	link.joint = Node3D.new()
	link.bone = _skeleton.find_bone(bone)
	link.joint.name = bone
	link.joint.position = _skeleton.get_bone_rest(link.bone).origin
	parent.add_child(link.joint)
	link.rest = end.normalized()
	link.aim = link.rest
	link.length = end.length()
	_links.append(link)
	return link
