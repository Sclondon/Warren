class_name Rain
extends Node3D
## The rain round the camera, as Weather says how hard it rains (the user,
## 2026-10-18: "The rain particle needs some work too, and should slapsh when it
## hits the ground. Theyre too thick- and there shsould be multiple kinds of rain
## particles- little droplets- lines- distant sheets of animated rain"). Four
## things, all following the camera, all more of them the harder it rains:
## - streaks: thin lines of falling rain round the camera (GPUParticles3D), each
##   drawn about a pixel wide however far off, fainter for it rather than thicker,
##   and turned along the way it falls, so that a storm's rain is driven slantwise;
## - droplets: a few hundred short drops close round the camera, beads of water
##   rather than lines;
## - sheets: distant curtains of rain, a dozen big upright quads out past the
##   streaks, their streaks noise scrolled down them and their edges wandering,
##   drifting with the wind (one draw, a shader: no particles);
## - splashes: where the rain hits the ground near the camera, a ring spreading
##   and a few drops bouncing up (one MultiMesh, placed by its shader). On the
##   ground (Maze.ground_height and the water of ponds and the marsh), and on
##   whatever he stands on above it (a ledge, a wall top); one that would hang in
##   the air, over the edge of either, is not drawn (the depth buffer says so).
##
## Fewer of each on a phone (Settings.low_poly, or the grass at its lowest).

## How many streaks, droplets, sheets and splashes at most (and on a phone).
const STREAKS := Vector2i(6000, 2400)
const DROPLETS := Vector2i(520, 200)
const SHEETS := Vector2i(14, 7)
const SPLASHES := Vector2i(380, 150)
## How wide and high a box the streaks fall in round the camera, and the droplets, metres.
const STREAK_BOX := Vector3(22.0, 20.0, 22.0)
const DROPLET_BOX := Vector3(9.0, 8.0, 9.0)
## How far out the sheets are, metres (they fade in past SHEET_NEAR and out
## towards SHEET_REACH, and wrap round: walk on and new ones come up ahead).
const SHEET_NEAR := 13.0
const SHEET_REACH := 150.0
## How far round the camera the splashes are, metres.
const SPLASH_REACH := 9.0

var maze: Maze
## The streaks' and droplets' process materials, and the materials drawing them all.
var _streaks: GPUParticles3D
var _streak_process: ParticleProcessMaterial
var _streak_look: ShaderMaterial
var _droplets: GPUParticles3D
var _droplet_process: ParticleProcessMaterial
var _droplet_look: ShaderMaterial
var _sheets: MeshInstance3D
var _sheet_look: ShaderMaterial
var _splashes: MultiMeshInstance3D
var _splash_look: ShaderMaterial
var _splash_count := 0
## How far the wind has carried the sheets, metres.
var _drift := Vector2.ZERO
var _on := true


## Rain for `maze` (where its ground is), under `parent`.
static func put(parent: Node3D, plan: Maze) -> Rain:
	var rain := Rain.new()
	rain.name = "Rain"
	rain.maze = plan
	parent.add_child(rain)
	return rain


func _ready() -> void:
	var low := Settings.low_poly or Grass.quality == Grass.Quality.LOW
	var pick := func(counts: Vector2i) -> int: return counts.y if low else counts.x
	_streak_look = _drop_material(0.006, 0.7, 1.6, 16.0, 0.0)
	_streaks = _falling("Streaks", pick.call(STREAKS), STREAK_BOX, _streak_look)
	_streak_process = _streaks.process_material
	_droplet_look = _drop_material(0.007, 0.07, 0.35, 8.0, 1.0)
	_droplets = _falling("Droplets", pick.call(DROPLETS), DROPLET_BOX, _droplet_look)
	_droplet_process = _droplets.process_material
	_sheets = _sheet_curtains(pick.call(SHEETS))
	_splashes = _splash_field(pick.call(SPLASHES))
	_splash_count = _splashes.multimesh.instance_count
	_switch(false)


## The rain now: how hard (0 to 1), how windy (0 to 1), the lightning (0 to 1),
## how light it is (DayCycle.daylight), and the mist's colour; round `eye`, with
## `feet` where he stands if it is above the ground (else NAN).
func show_rain(rain: float, wind: float, flash: float, light: float, mist: Color, eye: Vector3, _ahead: Vector3, feet: float, delta: float) -> void:
	# (not there at all unless it is raining: idle, it still costs a lot to draw)
	var raining := rain > 0.02
	if raining != _on:
		_switch(raining)
	if not raining:
		return
	var way := Vector3(0.15 + wind * 0.55, -1.0, 0.05 + wind * 0.2)
	var speed := lerpf(11.0, 22.0, rain) + wind * 4.0
	var lit := lerpf(0.22, 1.0, light)
	# Streaks: a sprinkle a few slow fine lines falling nearly straight; a
	# downpour sheets of them, fast, and a storm's driven slantwise.
	_streaks.global_position = eye + Vector3.UP * STREAK_BOX.y * 0.45
	_streaks.amount_ratio = clampf(rain, 0.05, 1.0)
	_streak_process.direction = way
	_streak_process.initial_velocity_min = speed
	_streak_process.initial_velocity_max = speed + 4.0
	_streak_look.set_shader_parameter(&"streak", lerpf(0.5, 1.0, rain))
	_streak_look.set_shader_parameter(&"tint", Color(Color(0.86, 0.89, 0.91) * lit, lerpf(0.38, 0.6, rain) + flash * 0.4))
	# Droplets: beads close by, more of them in a sprinkle than its streaks are.
	_droplets.global_position = eye + Vector3.UP * DROPLET_BOX.y * 0.45
	_droplets.amount_ratio = clampf(0.25 + rain, 0.0, 1.0)
	_droplet_process.direction = way
	_droplet_process.initial_velocity_min = speed * 0.8
	_droplet_process.initial_velocity_max = speed
	_droplet_look.set_shader_parameter(&"tint", Color(Color(0.86, 0.89, 0.92) * lit, 0.55 + flash * 0.3))
	# Sheets: only once it rains properly, and thick in a downpour.
	var sheets := smoothstep(0.22, 0.8, rain)
	_sheets.visible = sheets > 0.01
	_drift += Vector2(way.x, way.z) * (2.0 + wind * 10.0) * delta
	var ground := ground_at(eye)
	_sheet_look.set_shader_parameter(&"eye", eye)
	_sheet_look.set_shader_parameter(&"base", ground)
	_sheet_look.set_shader_parameter(&"drift", _drift)
	_sheet_look.set_shader_parameter(&"amount", sheets)
	_sheet_look.set_shader_parameter(&"slant", Vector2(way.x, way.z))
	_sheet_look.set_shader_parameter(&"fall", speed * 0.9)
	_sheet_look.set_shader_parameter(&"colour", (mist.darkened(0.38) * lerpf(0.4, 1.0, light)).lerp(Color(0.85, 0.88, 1.0), flash * 0.6))
	# Splashes: the ground round the camera as a slope (its height under him,
	# and how it rises each way), and where he stands if that is higher.
	var east := ground_at(eye + Vector3(2.0, 0.0, 0.0))
	var north := ground_at(eye + Vector3(0.0, 0.0, 2.0))
	_splash_look.set_shader_parameter(&"eye", eye)
	_splash_look.set_shader_parameter(&"ground", Vector3(ground, (east - ground) * 0.5, (north - ground) * 0.5))
	_splash_look.set_shader_parameter(&"upper", feet if not is_nan(feet) and feet > ground + 0.6 else -10000.0)
	_splash_look.set_shader_parameter(&"tint", Color(Color(0.86, 0.89, 0.92) * lit, 0.42))
	_splashes.multimesh.visible_instance_count = int(_splash_count * clampf(rain * 1.15, 0.12, 1.0))


## How high the ground (or the water on it) is under a point.
func ground_at(point: Vector3) -> float:
	if maze == null:
		return 0.0
	var height := maze.ground_height(point)
	var pond := maze.pond_at(point)
	if not pond.is_empty():
		height = maxf(height, float(pond.level))
	if maze.clearing_style and maze.clearing_style.marsh_rect().has_point(Vector2(point.x, point.z)):
		height = maxf(height, ClearingStyle.MARSH_LEVEL)
	return height


func _switch(on: bool) -> void:
	_on = on
	for part: Node3D in [_streaks, _droplets, _sheets, _splashes]:
		part.visible = on
		part.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	_streaks.emitting = on
	_droplets.emitting = on


## Rain falling in a box round the camera: `count` drops at most, each drawn by `look`.
func _falling(what: String, count: int, box: Vector3, look: ShaderMaterial) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = what
	particles.amount = count
	particles.lifetime = box.y / 18.0
	particles.preprocess = particles.lifetime
	particles.local_coords = false
	particles.visibility_aabb = AABB(-box, box * 2.0)
	particles.emitting = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(box.x * 0.5, 0.5, box.z * 0.5)
	process.direction = Vector3(0.15, -1.0, 0.05)
	process.spread = 2.0
	process.initial_velocity_min = 20.0
	process.initial_velocity_max = 24.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.8
	process.scale_max = 1.2
	# (each one's up turned the way it falls, for the shader to draw it along)
	process.particle_flag_align_y = true
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.material = look
	particles.draw_pass_1 = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	return particles


static func _drop_material(width: float, streak: float, near: float, far: float, bead: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader("drops", DROP_SHADER)
	material.set_shader_parameter(&"width", width)
	material.set_shader_parameter(&"streak", streak)
	material.set_shader_parameter(&"near", near)
	material.set_shader_parameter(&"far", far)
	material.set_shader_parameter(&"bead", bead)
	return material


## The sheets: `count` upright quads, each kept as one point (its anchor, the
## quad's corner in its UV, its size in UV2) for the shader to stand up facing
## the camera.
func _sheet_curtains(count: int) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	var sizes := PackedVector2Array()
	for i in count:
		var anchor := Vector3(rng.randf_range(-SHEET_REACH, SHEET_REACH), 0.0, rng.randf_range(-SHEET_REACH, SHEET_REACH))
		var size := Vector2(rng.randf_range(34.0, 70.0), rng.randf_range(60.0, 95.0))
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
			points.append(anchor)
			uvs.append(corner)
			sizes.append(size)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = sizes
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_sheet_look = ShaderMaterial.new()
	_sheet_look.shader = _shader("sheets", SHEET_SHADER)
	_sheet_look.set_shader_parameter(&"reach", SHEET_REACH)
	_sheet_look.set_shader_parameter(&"near", SHEET_NEAR)
	var sheets := MeshInstance3D.new()
	sheets.name = "Sheets"
	sheets.mesh = mesh
	sheets.material_override = _sheet_look
	sheets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (the shader moves them round the camera: never culled)
	sheets.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	sheets.top_level = true
	add_child(sheets)
	return sheets


## The splashes: `count` of them, each a flat quad (the ring) and an upright one
## (the drops bouncing), told apart by the vertex colour; each instance's number
## in its transform, for the shader to place it anew each time it splashes.
func _splash_field(count: int) -> MultiMeshInstance3D:
	var points := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	for upright in 2:
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
			var across := corner.x * 2.0 - 1.0
			points.append(Vector3(across, 1.0 - corner.y, 0.0) if upright else Vector3(across, 0.0, corner.y * 2.0 - 1.0))
			colours.append(Color(float(upright), 0.0, 0.0))
			uvs.append(corner)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	for i in count:
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(float(i), 0.0, 0.0)))
	_splash_look = ShaderMaterial.new()
	_splash_look.shader = _shader("splashes", SPLASH_SHADER)
	_splash_look.set_shader_parameter(&"reach", SPLASH_REACH)
	var splashes := MultiMeshInstance3D.new()
	splashes.name = "Splashes"
	splashes.multimesh = multimesh
	splashes.material_override = _splash_look
	splashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	splashes.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	splashes.top_level = true
	add_child(splashes)
	return splashes


static var _shaders := {}


static func _shader(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var shader := Shader.new()
		shader.code = code.replace("//COMMON", COMMON)
		_shaders[key] = shader
	return _shaders[key]


const COMMON := """
float hash1(float n) {
	return fract(sin(n * 12.9898 + 4.1414) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Where in the camera's space the thing drawn at a point of the screen is (as Water has it).
vec3 unproject(vec2 screen_uv, float depth, mat4 inv_projection) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(screen_uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
#endif
	vec4 view = inv_projection * vec4(ndc, 1.0);
	return view.xyz / view.w;
}
"""

## A streak or a droplet: a quad stood along the way it falls (its particle's
## up, turned so by the process material) and turned about that to face the
## camera; never thinner on the screen than about a pixel, fainter instead, so
## that far ones do not flicker in and out.
const DROP_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, world_vertex_coords;

// How wide and long, metres; faded out nearer than `near` and further than `far`;
// `bead` 1 for a droplet's round ends, 0 a streak's tapering tail.
uniform float width = 0.0045;
uniform float streak = 0.6;
uniform float near = 0.9;
uniform float far = 24.0;
uniform float bead = 0.0;
uniform vec4 tint : source_color = vec4(0.8, 0.83, 0.85, 0.35);

varying float fade;
varying float soft;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 along = normalize(MODEL_MATRIX[1].xyz);
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 to_eye = CAMERA_POSITION_WORLD - centre;
	float dist = max(length(to_eye), 0.01);
	vec3 side = normalize(cross(along, to_eye));
	float pixel = dist * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float wide = width * size;
	float drawn = max(wide, pixel * 2.6);
	soft = 1.0;
	fade = sqrt(wide / drawn) * smoothstep(near * 0.4, near, dist) * (1.0 - smoothstep(far * 0.6, far, dist));
	VERTEX = centre + side * (UV.x - 0.5) * drawn + along * (0.5 - UV.y) * streak * size;
}

void fragment() {
	// (soft across, over two or three pixels at least, or a thin slanting line breaks into dots)
	float across = mix(1.0, 1.0 - pow(abs(UV.x * 2.0 - 1.0), 2.0), soft);
	// (the head, at the bottom, bright; a streak's tail fainter; a droplet round at both ends)
	float tail = mix(mix(1.0, 0.2, UV.y), 1.0 - pow(abs(UV.y * 2.0 - 1.0), 3.0), bead);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * fade * across * tail;
}
"""

## The sheets: each a tall quad stood facing the camera round its anchor, the
## anchors wrapped round the camera so that there are always some out there;
## the rain in them streaks of noise stretched tall and scrolled down, their
## edges and gaps a broader noise that drifts, faded into the ground and the
## walls where they meet (the depth buffer), and in nearby and far off.
const SHEET_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 eye;
uniform float base = 0.0;
uniform vec2 drift = vec2(0.0);
uniform vec2 slant = vec2(0.0);
uniform float reach = 150.0;
uniform float near = 26.0;
uniform float amount = 1.0;
uniform float fall = 18.0;
uniform vec3 colour : source_color = vec3(0.5, 0.53, 0.54);
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

varying float seen;
varying vec2 metres;
varying float tall;
//COMMON

void vertex() {
	vec2 anchor = VERTEX.xz + drift;
	vec2 rel = mod(anchor - eye.xz + reach, 2.0 * reach) - reach;
	float dist = length(rel);
	seen = smoothstep(near, near * 1.8, dist) * (1.0 - smoothstep(reach * 0.65, reach * 0.95, dist));
	vec2 facing = rel / max(dist, 0.01);
	vec2 side = vec2(-facing.y, facing.x);
	float wide = UV2.x;
	tall = UV2.y;
	float up = (1.0 - UV.y) * tall;
	// (leaning with the wind, its top upwind)
	vec2 foot = eye.xz + rel + side * (UV.x - 0.5) * wide - slant * up * 0.6;
	VERTEX = vec3(foot.x, base - 3.0 + up, foot.y);
	metres = vec2((UV.x - 0.5) * wide + dot(anchor, vec2(1.3, 0.7)), up);
}

void fragment() {
	// The rain in it: fine streaks, noise squeezed tall and scrolled down.
	float lines = vnoise(vec2(metres.x * 1.7, (metres.y + TIME * fall) * 0.05));
	lines = lines * 0.65 + vnoise(vec2(metres.x * 4.1 + 7.0, (metres.y + TIME * fall * 1.3) * 0.11)) * 0.35;
	// Its curtains: gaps and thicker folds along it that drift.
	float folds = vnoise(vec2(metres.x * 0.05 + TIME * 0.05, 3.7)) * 0.7 + vnoise(vec2(metres.x * 0.13 - TIME * 0.08, 9.1)) * 0.3;
	float curtain = smoothstep(0.32, 0.75, folds);
	float sides = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	// (thinning upwards into the cloud, and away into the ground where it meets it)
	float rise = smoothstep(1.0, 0.0, metres.y / tall);
	vec3 behind = unproject(SCREEN_UV, texture(depth_texture, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	float soft = clamp((length(behind) - length(VERTEX)) / 8.0, 0.0, 1.0);
	ALBEDO = colour;
	ALPHA = clamp(amount * seen * sides * rise * soft * curtain * (0.35 + 0.65 * smoothstep(0.35, 0.8, lines)) * 0.85, 0.0, 1.0);
}
"""

## A splash: each instance (its number the x of its transform) splashes over
## and over, somewhere new round the camera each time; a ring spreading on the
## ground and, stood up facing the camera, a little crown and three drops that
## bounce up and fall back. On the ground's slope round the camera, or (every
## other one) where he stands if that is higher; not drawn where there is
## nothing under it (the depth buffer, at its foot).
const SPLASH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 eye;
// The ground's height under the camera, and how much it rises a metre east and north.
uniform vec3 ground = vec3(0.0);
uniform float upper = -10000.0;
uniform float reach = 9.0;
// How long one splash lasts, and how often it comes round, seconds.
uniform float life = 0.34;
uniform float period = 0.55;
uniform vec4 tint : source_color = vec4(0.86, 0.89, 0.92, 0.75);
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

varying float age;
varying float upright;
varying float seed;
varying vec4 foot_clip;
varying float foot_far;
varying float faded;
//COMMON

void vertex() {
	float id = MODEL_MATRIX[3].x;
	float every = period * mix(0.75, 1.3, hash1(id + 0.37));
	float t = TIME / every + hash1(id * 3.3);
	float cycle = floor(t);
	age = fract(t) * every / life;
	seed = hash1(id * 1.31 + cycle * 7.7);
	// (a spot fixed in the world for this splash, of the copies of it every `span`
	// across, the one nearest the camera: so it stays where it fell as he moves, not
	// carried along with him, the user, 2026-10-19: "the rain splash decals move with
	// the player when they shouldnt"; round the camera itself, not the way it looks,
	// so turning it moves none of them: "they still seem to move around when I rotate
	// the camera")
	float span = 2.0 * reach;
	vec2 centre = eye.xz;
	vec2 spot = vec2(hash1(id * 1.7 + cycle * 3.1), hash1(id * 2.3 + cycle * 5.7)) * span;
	vec2 where = centre + mod(spot - centre + span * 0.5, span) - span * 0.5;
	float y = ground.x + dot(ground.yz, where - eye.xz);
	if (mod(id, 2.0) > 0.5 && upper > y) {
		y = upper;
	}
	vec3 at = vec3(where.x, y + 0.015, where.y);
	upright = COLOR.r;
	float size = mix(0.7, 1.3, seed);
	vec3 world = at;
	if (age < 1.0) {
		if (upright < 0.5) {
			world = at + vec3(VERTEX.x, 0.0, VERTEX.z) * mix(0.03, 0.17, sqrt(age)) * size;
		} else {
			vec3 to_eye = CAMERA_POSITION_WORLD - at;
			vec3 side = normalize(vec3(-to_eye.z, 0.0, to_eye.x) + vec3(0.0001, 0.0, 0.0));
			world = at + side * VERTEX.x * 0.13 * size + vec3(0.0, VERTEX.y * 0.16 * size, 0.0);
		}
	}
	float dist = length(at - CAMERA_POSITION_WORLD);
	// (gone before the edge of the patch round the camera, where they come round anew)
	faded = 1.0 - smoothstep(reach * 0.55, reach * 0.95, length(at.xz - eye.xz));
	foot_clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(at, 1.0);
	foot_far = length((VIEW_MATRIX * vec4(at, 1.0)).xyz);
	VERTEX = world - MODEL_MATRIX[3].xyz;
}

void fragment() {
	// (nothing under its foot: it would hang in the air)
	vec2 foot_uv = foot_clip.xy / foot_clip.w * 0.5 + 0.5;
	vec3 behind = unproject(foot_uv, texture(depth_texture, foot_uv).r, INV_PROJECTION_MATRIX);
	float on = 1.0 - smoothstep(0.25, 0.6, length(behind) - foot_far);
	float a = 0.0;
	if (upright < 0.5) {
		float d = length(UV * 2.0 - 1.0);
		float width = mix(0.24, 0.1, age);
		a = smoothstep(1.0 - width * 2.0, 1.0 - width, d) * (1.0 - smoothstep(1.0 - width * 0.5, 1.0, d)) * pow(1.0 - age, 1.5);
	} else {
		vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
		// The crown, a ragged little cup at the start.
		float cup = smoothstep(0.55, 0.35, abs(abs(p.x) - 0.3)) * step(p.y, 0.35 * (1.0 - age) * (0.6 + 0.4 * hash1(floor(p.x * 9.0) + seed)));
		a = cup * (1.0 - age) * 0.6 * smoothstep(0.0, 0.08, age + 0.04);
		// And drops thrown up and falling back.
		for (int i = 0; i < 3; i++) {
			float k = float(i);
			float outward = (hash1(seed * 13.0 + k) - 0.5) * 1.6;
			float up = mix(2.2, 3.6, hash1(seed * 17.0 + k * 3.0));
			vec2 drop = vec2(outward * age, up * age - 3.4 * age * age);
			a = max(a, smoothstep(0.11, 0.05, length((p - drop) * vec2(1.0, 0.8))) * step(0.0, drop.y) * (1.0 - age * 0.7));
		}
	}
	ALBEDO = tint.rgb;
	ALPHA = clamp(a * tint.a * on * faded, 0.0, 1.0);
}
"""
