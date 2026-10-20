class_name GroundFog
extends Node3D
## A low fog lying on the ground some of the time (Weather.ground_fog says how
## much; the user, 2026-10-18: "We should also have some fog layers low to the
## ground sometimes that change heights and have animated scrolling snoise that
## you can leave a wake in"). Drawn over the whole screen by a shader that works
## out from the depth buffer how far each line of sight runs through the fog lying
## on the ground it meets (wherever the camera is, in it or over it): thin looking down at your feet, thick
## and white looking out across it, nothing where the ground rises out of it.
## Its top rolls (two layers of noise drifting with the wind), and it rises and
## sinks slowly (Weather says how high).
##
## Whoever walks through it leaves a wake: players, runners and the creatures
## near the camera drop a point every half metre or so they go (TRAIL of them at
## most, kept a few seconds), and round each the fog is pushed down and aside,
## filling in again as the point ages.
##
## The bodies that stir it are looked for once a second (a group and the
## hunters' own list, never the scene tree), the nearest few kept.

## How far round the camera it is drawn, metres (past that, the mist).
const REACH := 220.0
## How many points of wake are kept (on a phone, fewer), how long one lasts,
## seconds, and how far a body goes between them, metres.
const TRAIL := Vector2i(48, 24)
const WAKE_SECONDS := 7.0
const WAKE_STEP := 0.45
## How many bodies stir it at once, and how near the camera they must be, metres.
const STIRRERS := 6
const STIR_REACH := 40.0
## The ground's heights round the camera, for the fog to lie on (Maze.ground_height:
## the clearing's hills, the dunes, the ponds): a grid `GRID` points across `GRID_SPAN`
## metres, made again a few rows a frame once the camera is `GRID_MOVE` off its middle.
const GRID := 64
const GRID_SPAN := 256.0
const GRID_MOVE := 48.0
const GRID_ROWS_A_FRAME := 4

var world: Node
var _sheet: MeshInstance3D
var _look: ShaderMaterial
## The wake: [x, z, the second it was left, how wide] for each point, and where
## the same body left the point before it ([x, z]; the point itself if none), so
## that the wake is drawn as a track from one to the next, not as round holes
## (the user, 2026-10-19: "the fog wake looks more like circles appearring than a
## smooth break in the fog").
var _trail := PackedVector4Array()
var _trail_from := PackedVector2Array()
## From each stirring body's last point to where it is now ([x, z, x, z]), and how
## wide: the newest stretch of its wake, which follows it as it goes.
var _heads := PackedVector4Array()
var _head_wide := PackedFloat32Array()
var _trail_size := 32
var _next := 0
var _clock := 0.0
## The bodies stirring it, and where each last left a point.
var _stirrers: Array[Node3D] = []
var _last_at := {}
var _look_for := 0.0
## How high the ground is at a point (world y; Rain.ground_at: the water's top where there is
## water), for the grid; if unset, the maze's own ground.
var ground_of: Callable
var _heights: ImageTexture
var _heights_middle := Vector2.INF
## The grid being made (the next one), its middle, and the row it is up to (-1: none being made).
var _next_heights: Image
var _next_middle := Vector2.ZERO
var _next_row := -1


## Ground fog under `parent`, stirred by what is in `world` (its player, the
## maze_players and its hunters).
static func put(parent: Node3D, in_world: Node) -> GroundFog:
	var fog := GroundFog.new()
	fog.name = "GroundFog"
	fog.world = in_world
	parent.add_child(fog)
	return fog


func _ready() -> void:
	var low := Settings.low_poly or Grass.quality == Grass.Quality.LOW
	_trail_size = TRAIL.y if low else TRAIL.x
	for i in _trail_size:
		_trail.append(Vector4(0.0, 0.0, -1000.0, 1.0))
		_trail_from.append(Vector2.ZERO)
	for i in STIRRERS:
		_heads.append(Vector4.ZERO)
		_head_wide.append(0.0)
	# (a quad over the whole screen: the shader puts it there, and works the fog out
	# for each pixel, lying on whatever ground that pixel shows)
	var plane := QuadMesh.new()
	plane.size = Vector2(2.0, 2.0)
	var shader := Shader.new()
	shader.code = SHADER.replace("TRAIL_SIZE", str(_trail_size)).replace("STIRRERS", str(STIRRERS)).replace("//LOW", "#define LOW" if low else "")
	_look = ShaderMaterial.new()
	_look.shader = shader
	_look.set_shader_parameter(&"reach", REACH)
	_look.set_shader_parameter(&"wake_seconds", WAKE_SECONDS)
	_sheet = MeshInstance3D.new()
	_sheet.name = "Sheet"
	_sheet.mesh = plane
	_sheet.material_override = _look
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sheet.top_level = true
	_sheet.extra_cull_margin = 16384.0
	_sheet.visible = false
	add_child(_sheet)


## The fog now: how much (0 to 1), its top this high over the ground under the
## camera, metres; the wind (0 to 1) and how light it is, the mist's colour.
func show_fog(amount: float, height: float, wind: float, light: float, mist: Color, eye: Vector3, ground: float, delta: float) -> void:
	var on := amount > 0.01
	_sheet.visible = on
	if not on:
		return
	_clock += delta
	_stir(eye, height, delta)
	_map_ground(eye)
	# (it lies on the ground everywhere, the same wherever the camera is, in it or over
	# it: the user, 2026-10-19, "the ground fog seems to follow the boys or the cameras height")
	_sheet.global_position = eye
	_look.set_shader_parameter(&"height", height)
	_look.set_shader_parameter(&"floor_y", ground)
	_look.set_shader_parameter(&"amount", amount * smoothstep(0.1, 0.4, height))
	_look.set_shader_parameter(&"colour", mist.lightened(0.12) * lerpf(0.6, 1.0, light))
	_look.set_shader_parameter(&"wind", Vector2(0.35, 0.12) * (1.0 + wind * 4.0))
	_look.set_shader_parameter(&"clock", _clock)
	_look.set_shader_parameter(&"trail", _trail)
	_look.set_shader_parameter(&"newest", (_next - 1 + _trail_size) % _trail_size)
	_look.set_shader_parameter(&"trail_from", _trail_from)
	_look.set_shader_parameter(&"heads", _heads)
	_look.set_shader_parameter(&"head_wide", _head_wide)


## The wake: a point left behind each body near the camera every WAKE_STEP it goes.
func _stir(eye: Vector3, height: float, delta: float) -> void:
	_look_for -= delta
	if _look_for <= 0.0:
		_look_for = 1.0
		_find_stirrers(eye)
	for k in STIRRERS:
		_head_wide[k] = 0.0
	for k in _stirrers.size():
		var body := _stirrers[k]
		if not is_instance_valid(body):
			continue
		var at := body.global_position
		# (only what is down in it, on the ground where it is)
		var maze: Maze = world.get(&"maze") if world else null
		if at.y > (maze.ground_height(at) if maze else 0.0) + height + 0.3:
			continue
		var wide := 0.9 if body is MazeEnemy else 0.7
		var last: Vector3 = _last_at.get(body, Vector3.INF)
		if last == Vector3.INF or at.distance_squared_to(last) > WAKE_STEP * WAKE_STEP:
			# (joined to its last point, unless it jumped: put somewhere, or a new body)
			var from := Vector2(last.x, last.z) if last != Vector3.INF and at.distance_to(last) < WAKE_STEP * 4.0 else Vector2(at.x, at.z)
			_last_at[body] = at
			_trail[_next] = Vector4(at.x, at.z, _clock, wide)
			_trail_from[_next] = from
			_next = (_next + 1) % _trail_size
			last = at
		_heads[k] = Vector4(last.x, last.z, at.x, at.z)
		_head_wide[k] = wide


## Keeps the grid of the ground's heights round the camera up to date: the first
## made at once, the next a few rows a frame once he has gone far enough from its middle.
func _map_ground(eye: Vector3) -> void:
	var maze: Maze = world.get(&"maze") if world else null
	if maze == null:
		return
	var flat := Vector2(eye.x, eye.z)
	if _next_row < 0 and (_heights_middle == Vector2.INF or flat.distance_to(_heights_middle) > GRID_MOVE):
		_next_heights = Image.create_empty(GRID, GRID, false, Image.FORMAT_RF)
		_next_middle = flat.snappedf(GRID_SPAN / GRID)
		_next_row = 0
	if _next_row < 0:
		return
	var rows := GRID if _heights == null else GRID_ROWS_A_FRAME
	var corner := _next_middle - Vector2.ONE * GRID_SPAN * 0.5
	var step := GRID_SPAN / (GRID - 1)
	for r in rows:
		if _next_row >= GRID:
			break
		for c in GRID:
			var at := Vector3(corner.x + c * step, 0.0, corner.y + _next_row * step)
			_next_heights.set_pixel(c, _next_row, Color(float(ground_of.call(at)) if ground_of.is_valid() else maze.ground_height(at), 0.0, 0.0))
		_next_row += 1
	if _next_row >= GRID:
		_next_row = -1
		if _heights == null:
			_heights = ImageTexture.create_from_image(_next_heights)
		else:
			_heights.update(_next_heights)
		_heights_middle = _next_middle
		_look.set_shader_parameter(&"heights", _heights)
		_look.set_shader_parameter(&"heights_rect", Vector4(corner.x, corner.y, GRID_SPAN, GRID_SPAN))


## The nearest few bodies to the camera: the players and runners, and the hunters.
func _find_stirrers(eye: Vector3) -> void:
	var near: Array = []
	var flat := Vector2(eye.x, eye.z)
	var consider := func(body: Node3D) -> void:
		if is_instance_valid(body) and body.is_inside_tree() and body.visible:
			var d := Vector2(body.global_position.x, body.global_position.z).distance_squared_to(flat)
			if d < STIR_REACH * STIR_REACH:
				near.append([d, body])
	for body in get_tree().get_nodes_in_group(&"maze_players"):
		consider.call(body)
	var enemies: Variant = world.get(&"enemies") if world else null
	if enemies:
		for enemy: Node3D in enemies.enemies:
			consider.call(enemy)
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_stirrers.clear()
	for pair: Array in near.slice(0, STIRRERS):
		_stirrers.append(pair[1])
	# (untyped: one may have been freed since)
	for body: Variant in _last_at.keys():
		if not is_instance_valid(body) or not _stirrers.has(body):
			_last_at.erase(body)


## Stirs the fog at a point now (for tests and pictures).
func stir_at(at: Vector3, wide := 0.7) -> void:
	_trail[_next] = Vector4(at.x, at.z, _clock, wide)
	_trail_from[_next] = Vector2(at.x, at.z)
	_next = (_next + 1) % _trail_size


const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;
//LOW

// How high the fog lies over the ground, metres, how far its top rolls below that, and
// how thick it is (1 - its share of the light that gets through each metre).
uniform float height = 1.0;
// The floor under the camera (world y): the fog lies on what is seen only near it (not up on ledges).
uniform float floor_y = 0.0;
// The ground's heights round the camera (world y in red), over [x, z, width, depth] of the world.
uniform sampler2D heights : filter_linear, repeat_disable;
uniform vec4 heights_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform float roll = 0.6;
uniform float density = 0.5;
uniform float amount = 1.0;
uniform vec3 colour : source_color = vec3(0.75, 0.78, 0.78);
uniform vec2 wind = vec2(0.35, 0.12);
uniform float reach = 220.0;
uniform float clock = 0.0;
uniform float wake_seconds = 7.0;
// [x, z, the clock when it was left, how wide] for each point of the wake.
uniform vec4 trail[TRAIL_SIZE];
// Where the same body left the point before each ([x, z]): each point is the end of a stretch from it.
uniform vec2 trail_from[TRAIL_SIZE];
// Which of them was left last: the oldest few fade out as they come round to be
// left again, so that running, the end of the wake closes up, not snaps shut.
uniform int newest = 0;
// The newest stretch of each stirring body's wake, from its last point to it ([x, z, x, z]), and how wide (0: none).
uniform vec4 heads[STIRRERS];
uniform float head_wide[STIRRERS];
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;


float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

// From `p` to the nearest point of the stretch from `a` to `b`.
vec2 off_stretch(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
	return p - (a + ab * t);
}

vec3 unproject(vec2 screen_uv, float depth, mat4 inv_projection) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(screen_uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
#endif
	vec4 view = inv_projection * vec4(ndc, 1.0);
	return view.xyz / view.w;
}

void vertex() {
	// (over the whole screen: the fog is worked out for each pixel from what is behind it)
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}

// The wake at `here`: how much of the fog it has pushed away, and which way (to swirl it).
float wake(vec2 here, out vec2 push) {
	// (each stretch of track clears a soft band along it, widening and closing up
	// as it ages; overlapping ones blend, not the strongest alone, so no edges)
	float kept = 1.0;
	push = vec2(0.0);
	for (int i = 0; i < TRAIL_SIZE; i++) {
		vec4 point = trail[i];
		float age = (clock - point.z) / wake_seconds;
		if (age < 1.0) {
			vec2 off = off_stretch(here, trail_from[i], point.xy);
			float wide = point.w * mix(1.0, 2.2, age);
			float d = length(off);
			// (how many have been left since: the oldest half fade away before their turn comes round)
			float since = float((newest - i + TRAIL_SIZE) % TRAIL_SIZE);
			float left = 1.0 - smoothstep(float(TRAIL_SIZE) * 0.45, float(TRAIL_SIZE) - 1.0, since);
			float c = pow(1.0 - smoothstep(0.0, wide, d), 2.0) * pow(1.0 - age, 1.6) * left;
			kept *= 1.0 - c;
			push += off / max(d, 0.001) * c * (1.0 - age);
		}
	}
	for (int k = 0; k < STIRRERS; k++) {
		if (head_wide[k] > 0.0) {
			vec2 off = off_stretch(here, heads[k].xy, heads[k].zw);
			float d = length(off);
			float c = pow(1.0 - smoothstep(0.0, head_wide[k], d), 2.0);
			kept *= 1.0 - c;
			push += off / max(d, 0.001) * c;
		}
	}
	push = push / max(length(push), 1.0);
	return 1.0 - kept;
}

// How far along a line of sight `length` long from `eye` (y) to `end` (y) runs under `top`.
float under_top(float eye_y, float end_y, float length_of, float top) {
	if (eye_y <= top && end_y <= top) {
		return length_of;
	}
	if (eye_y > top && end_y > top) {
		return 0.0;
	}
	float t = clamp((top - eye_y) / (end_y - eye_y), 0.0, 1.0);
	return length_of * (eye_y > top ? 1.0 - t : t);
}

void fragment() {
	vec3 behind = unproject(SCREEN_UV, texture(depth_texture, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	vec3 under = (INV_VIEW_MATRIX * vec4(behind, 1.0)).xyz;
	vec3 eye = CAMERA_POSITION_WORLD;
	float far = length(behind);
	float l = min(far, reach);
	vec3 way = (under - eye) / max(far, 0.001);
	vec3 end = eye + way * l;
	// The ground it lies on here: the ground's own height under what the line of
	// sight meets (grass, a boy, a wall's foot), from the grid round the camera, so
	// that it lies on the ground wherever he is and however high the camera, not
	// on a sheet at his height.
	vec2 cell = (end.xz - heights_rect.xy) / max(heights_rect.zw, vec2(0.001));
	float base = (heights_rect.z > 0.0 && cell.x >= 0.0 && cell.y >= 0.0 && cell.x <= 1.0 && cell.y <= 1.0) ? texture(heights, cell).r : floor_y;
	// (where the line of sight meets the fog's top, or a little way in if he is in it: its noise and wake there)
	float level = base + height;
	float meets = under_top(eye.y, end.y, l, level);
	float t_in = eye.y > level ? (l - meets) : 0.0;
	vec2 here = (eye + way * clamp(t_in + 2.0, 0.0, l)).xz;
	vec2 push;
	float cleared = wake(here, push);
	// Its top: two layers of noise drifting with the wind, the wake swirling them aside and pushing it down.
	vec2 p = here + push * cleared * 1.5;
	float n = vnoise(p * 0.11 + wind * clock * 0.11) * 0.6 + vnoise(p * 0.31 - wind.yx * clock * 0.23) * 0.4;
#ifndef LOW
	n = n * 0.8 + vnoise(p * 0.9 + vec2(clock * 0.07, -clock * 0.05)) * 0.2;
#endif
	float top = base + height - roll * (1.0 - n) - cleared * height * 0.8;
	float inside = under_top(eye.y, end.y, l, top);
	float thick = density * mix(0.15, 1.6, smoothstep(0.2, 0.85, n));
	float a = 1.0 - exp(-inside * thick);
	float edge = 1.0 - smoothstep(reach * 0.55, reach * 0.95, length(here - eye.xz));
	ALBEDO = colour * mix(0.9, 1.06, n);
	ALPHA = clamp(a * amount * edge * (1.0 - cleared * 0.45), 0.0, 1.0);
}
"""
