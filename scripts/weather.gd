class_name Weather
extends Node3D
## The weather over the maze: spells of the usual overcast, of heavy cloud, of
## clear sunny days (the user, 2026-10-18: "There should also be sunny days with
## blue sky": a blue sky, a bright sun and little mist, DayCycle.sunshine), and
## of rain (a light sprinkle, steady rain, a downpour, or a thunderstorm), one
## after another, each a few minutes long, changing over slowly. Clouds drift
## over high above the walls (a layer of them, drawn in the shader), thicker
## and darker as it clouds over; rain falls round the camera (Rain: streaks,
## droplets, distant sheets of it and splashes where it lands), more and faster
## and blown slantwise the harder it rains; the day is darker with it
## (DayCycle.gloom) and the ground wetter. Some spells, and some dawns, have a
## low fog lying on the ground (GroundFog), rising and sinking slowly, that
## whoever walks through it leaves a wake in. In a thunderstorm lightning flashes
## over the maze (lighting it from above and the clouds from inside) and the
## thunder rolls after it, the further off the longer after.
##
## The spells, the ground fog, and each flash of lightning, come from the room's seed and how
## long the round has gone, so it rains, and lightens, for everyone in a room
## at once.

enum Kind { OVERCAST, CLOUDY, SPRINKLE, RAIN, DOWNPOUR, THUNDERSTORM, SUNNY }

## How long a spell lasts, seconds (from, to), and how long one takes to turn
## into the next.
const SPELL := Vector2(100.0, 240.0)
const CHANGE_SECONDS := 25.0
## Each kind's [how clouded over, how hard it rains (0 to 1), how windy (0 to
## 1)], and how likely it is.
const LOOKS := {
	Kind.OVERCAST: [0.35, 0.0, 0.1], Kind.CLOUDY: [0.85, 0.0, 0.2], Kind.SPRINKLE: [0.82, 0.18, 0.1],
	Kind.RAIN: [1.0, 0.5, 0.25], Kind.DOWNPOUR: [1.0, 1.0, 0.45], Kind.THUNDERSTORM: [1.0, 0.85, 1.0],
	Kind.SUNNY: [0.12, 0.0, 0.12],
}
const CHANCES := {
	Kind.OVERCAST: 0.32, Kind.CLOUDY: 0.2, Kind.SPRINKLE: 0.11, Kind.SUNNY: 0.14,
	Kind.RAIN: 0.11, Kind.DOWNPOUR: 0.07, Kind.THUNDERSTORM: 0.05,
}
## How likely a spell of each kind is to have ground fog lying low (GroundFog):
## most in still grey weather, little in rain, none in a storm's wind. A dawn
## has it this often too, till DAWN_FOG_UNTIL o'clock, unless it pours.
const FOG_CHANCES := {
	Kind.OVERCAST: 0.4, Kind.CLOUDY: 0.35, Kind.SPRINKLE: 0.35, Kind.RAIN: 0.2,
	Kind.DOWNPOUR: 0.08, Kind.THUNDERSTORM: 0.0, Kind.SUNNY: 0.12,
}
const DAWN_FOG_CHANCE := 0.5
const DAWN_FOG_UNTIL := 8.5
## How high the ground fog's top is over the ground, metres: it rises and sinks
## slowly between these, over minutes.
const FOG_HEIGHT := Vector2(0.5, 1.4)
## Lightning in a thunderstorm: time is cut into slots this long, and in each
## there is a strike this often (at a point in it the seed picks); a flash
## lasts FLASH s (flickering), and thunder comes 0.4 to 4 s after (far or near).
const STRIKE_SLOT := 5.0
const STRIKE_CHANCE := 0.55
const FLASH := 0.45
## How high the clouds are, and how far they reach each way.
const CLOUD_HEIGHT := 420.0
const CLOUD_REACH := 5000.0

## Seconds since the round began.
var seconds := 0.0
## How clouded over it is (0 to 1), how hard it is raining (1 a downpour), how
## windy, and how bright the lightning is now (0 to 1).
var clouds := 0.35
var rain := 0.0
var wind := 0.1
var flash := 0.0
## How sunny it is (0 to 1): a clear blue day (DayCycle.sunshine).
var sunshine := 0.0
## How much ground fog is lying (0 to 1), and how high its top is over the ground, metres.
var ground_fog := 0.0
var ground_fog_height := 1.0
## How thick the clearing's fog banks are now (ClearingFog), 0 to 1.
var clearing_fog := 0.0
## For DevTools: a kind to have instead of the spells (-1: the spells).
var forced := -1
## For DevTools: ground fog or none instead of as the spells have it (-1: the spells, 0 none, 1 fog).
var forced_ground_fog := -1

var day: DayCycle
var ground: ShaderMaterial
## The maze it is over (for where its ground is, under the rain).
var maze: Maze
var _seed := 0
# [start second, kind, whether there is ground fog] for each spell.
var _spells: Array = []
var _cloud_material: ShaderMaterial
var _rain: Rain
var _ground_fog: GroundFog
var _clearing_fog: ClearingFog
var _lightning: DirectionalLight3D
var _thunder: AudioStreamPlayer
## The strike now under way: when it began (INF: none), and its thunder still to come.
var _struck_at := INF
var _struck_slot := -1
var _thunder_at := INF
var _thunder_loud := 0.0
var _thunder_task := -1
var _thunder_made: AudioStreamWAV


## Puts the weather under `world`, for a round of `seed_value`.
static func put(world: Node3D, seed_value: int, day_cycle: DayCycle, ground_material: ShaderMaterial) -> Weather:
	var weather := Weather.new()
	weather.name = "Weather"
	weather.day = day_cycle
	weather.ground = ground_material
	weather.maze = world.get(&"maze") as Maze
	weather._plan(seed_value)
	world.add_child(weather)
	return weather


func _plan(seed_value: int) -> void:
	_seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("weather/%d" % seed_value)
	var at := 0.0
	# (the first is always the usual overcast, so a round does not begin in rain)
	var kind := Kind.OVERCAST
	while at < 4.0 * 3600.0:
		# (and whether there is ground fog in it: a roll of its own, so that the
		# spells are the same whether or not it is looked at)
		var fog_roll := RandomNumberGenerator.new()
		fog_roll.seed = hash("ground fog/%d/%d" % [seed_value, _spells.size()])
		_spells.append([at, kind, fog_roll.randf() < FOG_CHANCES[kind]])
		at += rng.randf_range(SPELL.x, SPELL.y)
		var pick := rng.randf()
		for each: Kind in CHANCES:
			pick -= CHANCES[each]
			if pick <= 0.0:
				kind = each
				break


## The kind of weather `at` seconds into the round.
func kind_at(at: float) -> Kind:
	var found: Kind = Kind.OVERCAST
	for spell: Array in _spells:
		if spell[0] > at:
			break
		found = spell[1]
	return found


## Whether there is ground fog `at` seconds into the round (as the spells have
## it, or every dawn), at `hour` o'clock.
func ground_fog_at(at: float, hour: float) -> bool:
	var fog := false
	for spell: Array in _spells:
		if spell[0] > at:
			break
		fog = spell[2]
	if fog or hour < DayCycle.DAWN - 0.5 or hour >= DAWN_FOG_UNTIL:
		return fog
	# (a misty dawn, or not, for each day)
	var each_day := day.day_seconds + day.night_seconds if day else 600.0
	var roll := RandomNumberGenerator.new()
	var which_day := floori(day.seconds / each_day) if day else floori(at / each_day)
	roll.seed = hash("dawn fog/%d/%d" % [_seed, which_day])
	return roll.randf() < DAWN_FOG_CHANCE


func _ready() -> void:
	_cloud_layer()
	_rain = Rain.put(self, maze)
	_ground_fog = GroundFog.put(self, get_parent())
	# (lying on the ground as the rain splashes on it: the water's top where there is water)
	_ground_fog.ground_of = _rain.ground_at
	if maze:
		_clearing_fog = ClearingFog.put(self, maze)
		# (there from the start, as thick as a morning has it)
		clearing_fog = _clearing_fog.style.clearing_fog_thickness
	_storm()


func _process(delta: float) -> void:
	seconds += delta
	var kind: Kind = now()
	var look: Array = LOOKS[kind]
	clouds = move_toward(clouds, look[0], delta / CHANGE_SECONDS)
	wind = move_toward(wind, look[2], delta / CHANGE_SECONDS)
	# (the rain comes once it has clouded over, and stops before it clears)
	rain = move_toward(rain, look[1] if clouds > 0.75 else 0.0, delta / (CHANGE_SECONDS * 0.6))
	_lightening(delta, kind == Kind.THUNDERSTORM and clouds > 0.9)
	# (the sun comes out as the cloud thins, and goes in before it thickens)
	sunshine = move_toward(sunshine, 1.0 if kind == Kind.SUNNY and clouds < 0.4 else 0.0, delta / CHANGE_SECONDS)
	var light := day.daylight if day else 1.0
	if day:
		day.gloom = clampf((clouds - 0.35) / 0.65, 0.0, 1.0) * 0.45 + rain * 0.55
		day.flash = flash
		day.sunshine = sunshine
	if ground:
		ground.set_shader_parameter(&"wetness", 0.45 - sunshine * 0.25 + sqrt(rain) * 0.5)
	_cloud_material.set_shader_parameter(&"cover", clouds)
	_cloud_material.set_shader_parameter(&"light", lerpf(0.12, 1.0, light) * (1.0 - rain * 0.45))
	_cloud_material.set_shader_parameter(&"flash", flash)
	_cloud_material.set_shader_parameter(&"sunshine", sunshine * light)
	_cloud_material.set_shader_parameter(&"wind", Vector2(4.0, 1.5) * (1.0 + wind * 4.0))
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera else Vector3.ZERO
	# (where he stands, if he is standing on something: the splashes on it too)
	var feet := NAN
	var player := get_parent().get(&"player") as CharacterBody3D if get_parent() else null
	if player and player.is_on_floor():
		feet = player.global_position.y
	var mist := day.mist if day else Color(0.66, 0.7, 0.69)
	_rain.show_rain(rain, wind, flash, light, mist, eye, -camera.global_basis.z if camera else Vector3.FORWARD, feet, delta)
	# Ground fog, as the spells have it (or every dawn), but not in heavy rain
	# or a storm's wind; its top rising and sinking slowly, the same for everyone.
	var fog_wanted := ground_fog_at(seconds, day.hour if day else 12.0) and rain < 0.7 and wind < 0.6
	if forced_ground_fog >= 0:
		fog_wanted = forced_ground_fog == 1
	ground_fog = move_toward(ground_fog, 1.0 if fog_wanted else 0.0, delta / CHANGE_SECONDS)
	var swell := 0.5 + 0.32 * sin(seconds / 61.0 + float(_seed % 13)) + 0.18 * sin(seconds / 23.0 + float(_seed % 7))
	ground_fog_height = lerpf(FOG_HEIGHT.x, FOG_HEIGHT.y, clampf(swell, 0.0, 1.0))
	if ground_fog > 0.01:
		_ground_fog.show_fog(smoothstep(0.0, 1.0, ground_fog), ground_fog_height, wind, light, mist, eye, _rain.ground_at(eye), delta)
	else:
		_ground_fog.show_fog(0.0, 0.0, 0.0, 0.0, mist, eye, 0.0, delta)
	if _clearing_fog:
		_fog_banks(light, mist, eye, delta)


## The clearing's fog banks: thickest at dawn, thinner by day, all but burnt
## off on a sunny day, beaten down by rain and torn by a storm's wind; drawn
## only while the camera is in the clearing or over it, and the mist thicker
## round the camera while it is in a bank.
func _fog_banks(light: float, mist: Color, eye: Vector3, delta: float) -> void:
	var hour := day.hour if day else 12.0
	var by_hour := 0.75 + 0.25 * (1.0 - smoothstep(8.0, 10.5, hour)) * smoothstep(4.0, 6.0, hour) + 0.12 * smoothstep(17.0, 19.5, hour)
	if hour < 4.0 or hour >= 19.5:
		by_hour = 0.85
	var wanted := _clearing_fog.style.clearing_fog_thickness * by_hour * (1.0 - sunshine * 0.8) * (1.0 - rain * 0.45) * (1.0 - clampf(wind - 0.5, 0.0, 0.5))
	clearing_fog = move_toward(clearing_fog, wanted, delta / CHANGE_SECONDS)
	# (none of it seen from the halls round the clearing, past its high wall)
	var over := maxf(absf(eye.x), absf(eye.z)) < _clearing_fog.half + 2.0 or eye.y > _clearing_fog.style.clearing_wall_height * 0.8
	_clearing_fog.show_fog(clearing_fog if over else 0.0, light, mist, wind, delta)
	if day:
		day.thicken = clearing_fog * _clearing_fog.in_bank(eye, _rain.ground_at(eye)) * 2.2 if over else 0.0


## The kind of weather now (as the spells have it, or as DevTools forces it).
func now() -> Kind:
	return forced as Kind if forced >= 0 else kind_at(seconds)


## Lightning, in a storm: a strike in this slot of time (as the seed says),
## flickering bright, then its thunder.
func _lightening(delta: float, storming: bool) -> void:
	var slot := floori(seconds / STRIKE_SLOT)
	if storming and slot != _struck_slot:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("lightning/%d/%d" % [_seed, slot])
		var strikes := rng.randf() < STRIKE_CHANCE
		var at := (slot + rng.randf_range(0.0, 0.8)) * STRIKE_SLOT
		var far := rng.randf()
		if not strikes:
			_struck_slot = slot
		elif seconds >= at:
			_struck_slot = slot
			_struck_at = seconds
			_thunder_at = seconds + lerpf(0.4, 4.0, far)
			_thunder_loud = lerpf(1.0, 0.35, far)
			_lightning.rotation = Vector3(deg_to_rad(rng.randf_range(-80.0, -50.0)), rng.randf_range(-PI, PI), 0.0)
	flash = 0.0
	var since := seconds - _struck_at
	if since >= 0.0 and since < FLASH:
		# (two or three flickers, the first the brightest)
		var flicker := absf(sin(since * 38.0)) * (1.0 - since / FLASH)
		flash = clampf(flicker * _thunder_loud * 1.4, 0.0, 1.0)
	_lightning.visible = flash > 0.01
	_lightning.light_energy = flash * 3.0
	if _thunder_task >= 0 and WorkerThreadPool.is_task_completed(_thunder_task):
		WorkerThreadPool.wait_for_task_completion(_thunder_task)
		_thunder_task = -1
		_thunder.stream = _thunder_made
	if seconds >= _thunder_at:
		_thunder_at = INF
		_thunder.volume_db = linear_to_db(_thunder_loud) - 6.0
		_thunder.pitch_scale = lerpf(0.75, 1.05, _thunder_loud)
		_thunder.play()


func _exit_tree() -> void:
	if _thunder_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_thunder_task)
		_thunder_task = -1


## Lightning strikes now, near, its thunder after (for pictures and tests).
func strike() -> void:
	_struck_at = seconds
	_thunder_at = seconds + 0.8
	_thunder_loud = 1.0


func _storm() -> void:
	_lightning = DirectionalLight3D.new()
	_lightning.name = "Lightning"
	_lightning.light_color = Color(0.82, 0.86, 1.0)
	_lightning.shadow_enabled = false
	_lightning.visible = false
	add_child(_lightning)
	_thunder = AudioStreamPlayer.new()
	_thunder.name = "Thunder"
	# (made on another thread: some forty milliseconds of sums, kept off the start of the round)
	_thunder_task = WorkerThreadPool.add_task(func() -> void: _thunder_made = _thunder_sound())
	add_child(_thunder)


## A roll of thunder (made once): a crack, then a low rumble that swells and
## dies away over several seconds, of noise smoothed darker and darker.
static func _thunder_sound() -> AudioStreamWAV:
	var rate := 22050
	var length := 6.5
	var count := int(rate * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low := 0.0
	var lower := 0.0
	for i in count:
		var t := float(i) / rate
		var white := rng.randf_range(-1.0, 1.0)
		low += (white - low) * 0.06
		lower += (low - lower) * 0.02
		var crack := white * exp(-t * 14.0) * 0.35
		var rumble := lower * 9.0 * smoothstep(0.0, 0.5, t) * exp(-t * 0.55) * (0.75 + 0.25 * sin(t * 5.3) * sin(t * 2.1))
		data.encode_s16(i * 2, int(clampf(crack + rumble, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


func _cloud_layer() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * CLOUD_REACH * 2.0
	var shader := Shader.new()
	shader.code = CLOUD_SHADER
	_cloud_material = ShaderMaterial.new()
	_cloud_material.shader = shader
	var layer := MeshInstance3D.new()
	layer.name = "Clouds"
	layer.mesh = plane
	layer.material_override = _cloud_material
	layer.position.y = CLOUD_HEIGHT
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(layer)


const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// How clouded over (0 a few thin wisps, 1 all of it), and how lit (night 0.1).
uniform float cover = 0.35;
uniform float light = 1.0;
// Lightning inside the clouds now (0 to 1).
uniform float flash = 0.0;
// How sunny (0 to 1): the few clouds there are white and bright in the sun.
uniform float sunshine = 0.0;
uniform vec2 wind = vec2(4.0, 1.5);
uniform float scale = 0.0022;

varying vec3 place;

void vertex() {
	place = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float weight = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += noise(p) * weight;
		p = p * 2.03 + vec2(1.7, 9.2);
		weight *= 0.5;
	}
	return sum;
}

void fragment() {
	vec2 at = (place.xz + wind * TIME) * scale;
	float n = fbm(at) + fbm(at * 2.7 - TIME * 0.004) * 0.35;
	// (more of the sky is cloud as it clouds over; heavy cloud is darker underneath)
	float edge = mix(0.78, 0.25, cover);
	float thick = smoothstep(edge, edge + 0.22, n);
	float under = mix(0.82, 0.42, cover * thick);
	// (thinning out far off, where the sky's own haze takes over)
	float far = 1.0 - smoothstep(1200.0, 4500.0, length(place.xz - CAMERA_POSITION_WORLD.xz));
	under = mix(under, 1.0, sunshine * 0.75);
	ALBEDO = mix(vec3(0.78, 0.8, 0.8), vec3(1.0, 0.99, 0.97), sunshine) * under * light + vec3(0.75, 0.8, 0.95) * flash * (0.4 + 0.6 * thick);
	ALPHA = thick * mix(0.55, 0.95, cover) * far;
}
"""
