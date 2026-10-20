@tool
class_name Wall
extends StaticBody3D
## A wall: one solid box, `width` along X, `height` up and `depth` along Z, that
## stands on its origin (the middle of its base), and can be bumped into. Change
## any of it in the Inspector and it is redrawn at once.
##
## It is drawn with a texture (with its relief and roughness) laid on each face
## at its true size, one tile every `tile_size` metres, so a bigger wall shows more
## concrete, not stretched concrete. So that a big wall does not look like the same
## square over and over, the texture is broken up (`break_up`): a slow noise across
## the wall chooses which shifted copy of it shows where, blended where they meet
## (shifted only, never turned, so formboard lines and ribs keep their way), and a
## broad, slow change of tone is laid over it all (`variation`).
##
## The looks are photographed concrete from Poly Haven (CC0; textures/polyhaven/,
## see its CREDITS.md), concretes made by tools/make_wall_textures.gd, and the old
## stone blocks; or Custom, to keep textures of your own. Wall.material_for gives
## the same surface to anything else (the maze's walls are drawn with it).

# (numbered, so that a wall saved with a look keeps it as more are added)
enum Look {
	CAST = 7, SLABS = 8, GROOVED = 9, ROUGH = 10, RIBBED = 11,
	CONCRETE = 6, CONCRETE_PANELS = 0, BOARD_MARKED = 1, WEATHERED = 2, MONOLITH = 3, STONE_BLOCKS = 4,
	CUSTOM = 5,
}
## How it is built: Basic is a plain box, the rest add mouldings and piers (see style_boxes).
enum Style { BASIC, CORNICE, PILASTERS, STEPPED }

## Each look's maps (a path with %s for diff, nor_gl and rough; or the name of a
## made texture and its _normal) and how many metres one tile of them covers.
const LOOKS := {
	Look.CAST: ["polyhaven/concrete_wall_007/concrete_wall_007_%s_2k.jpg", 2.16],
	Look.SLABS: ["polyhaven/concrete_slab_wall_02/concrete_slab_wall_02_%s_2k.jpg", 2.1],
	Look.GROOVED: ["polyhaven/concrete/concrete_%s_2k.jpg", 4.0],
	Look.ROUGH: ["polyhaven/rough_concrete/rough_concrete_%s_2k.jpg", 1.23],
	Look.RIBBED: ["polyhaven/ribbed_concrete_wall/ribbed_concrete_wall_%s_2k.jpg", 2.0],
	Look.CONCRETE: ["concrete", 6.0],
	Look.CONCRETE_PANELS: ["concrete_panels", 9.6],
	Look.BOARD_MARKED: ["concrete_boards", 7.0],
	Look.WEATHERED: ["concrete_weathered", 10.0],
	Look.MONOLITH: ["concrete_monolith", 12.0],
	Look.STONE_BLOCKS: ["stone_blocks", 8.0],
}

## The surface: in the box's own space, so the texture stays put on the wall
## wherever it stands. (With `world_space` on, in the world's instead, so that the
## many boxes of the maze's walls meet without seams.)
const SHADER := """
shader_type spatial;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = true;
uniform bool has_rough = false;
uniform bool world_space = false;
uniform float roughness = 0.9;
uniform float tile_size = 2.0;
uniform float relief = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float break_up = 1.0;
uniform float variation = 0.15;
uniform float weathering = 0.35;
// Moss (in the world's space, `world_space` on): up the foot of the wall to about
// `moss_foot` metres from the ground, its top edge ragged, and in patches higher
// up over about `moss_patches` of the face. 0 and 0: none, and none of its cost.
uniform float moss_foot = 0.0;
uniform float moss_patches = 0.0;
uniform vec3 moss_dark : source_color = vec3(0.08, 0.1, 0.05);
uniform vec3 moss_light : source_color = vec3(0.28, 0.31, 0.14);
// The weathering of its edges and top (for a mesh made by WallMesh, which puts
// how far each point is from its edges in UV and UV2): how far round they are,
// metres, and how weathered (0: none, and none of its cost).
uniform float edge_size = 0.0;
uniform float edge_weathering = 0.0;
// Curved (a sewer's modelled mouth: SewerMouth): its texture laid on square to
// whichever of the world's axes it faces most, not to its own face, which turns
// round the curve and smeared the texture far out of the world's middle.
uniform bool curved = false;
#ifdef LOOMING
// The mist, drawn by the wall itself (the maze's walls: Wall.looming_shader), as
// MazeLight.share_mist hands it on, so that far off the walls loom dark out of it
// rather than fading into the sky (`looming`, 0: just as the mist would draw them).
global uniform vec3 mist_colour;
global uniform float mist_density;
global uniform float mist_height;
global uniform float mist_height_density;
global uniform vec3 mist_sun;
global uniform vec3 mist_sun_colour;
// How brooding: 1 on a grey day, less on a sunny one (DayCycle), whose far walls stay light.
global uniform float mist_brood;
uniform float looming = 1.0;
#endif

varying vec3 at;
varying vec3 facing;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 s = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), s.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), s.x), s.y);
}

void vertex() {
	at = world_space ? (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz : VERTEX;
	facing = world_space ? mat3(MODEL_MATRIX) * NORMAL : NORMAL;
}

void fragment() {
	vec3 n = normalize(facing);
	// The face's own across and up: up the wall on its sides, and away on its top and bottom.
	vec3 v_axis = abs(n.y) > 0.5 ? vec3(0.0, 0.0, -1.0) : vec3(0.0, 1.0, 0.0);
	vec3 u_axis = normalize(cross(v_axis, n));
	if (curved) {
		vec3 a = abs(n);
		vec3 square = a.y >= a.x && a.y >= a.z ? vec3(0.0, sign(n.y), 0.0) : (a.x >= a.z ? vec3(sign(n.x), 0.0, 0.0) : vec3(0.0, 0.0, sign(n.z)));
		v_axis = abs(square.y) > 0.5 ? vec3(0.0, 0.0, -1.0) : vec3(0.0, 1.0, 0.0);
		u_axis = cross(v_axis, square);
	}
	vec2 metres = vec2(dot(at, u_axis), -dot(at, v_axis));
	vec2 uv = metres / tile_size;
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);

	// Which shifted copy shows here (Inigo Quilez's way of hiding repeats): a slow
	// noise picks between neighbouring offsets, and the two are blended where it turns.
	float k = noise(uv * 0.21) * 7.0 + noise(uv * 0.53) * 1.0;
	float i = floor(k);
	float f = fract(k);
	vec2 off_a = sin(vec2(3.0, 7.0) * i) * break_up;
	vec2 off_b = sin(vec2(3.0, 7.0) * (i + 1.0)) * break_up;
	vec4 a = textureGrad(albedo_map, uv + off_a, dx, dy);
	vec4 b = textureGrad(albedo_map, uv + off_b, dx, dy);
	float w = smoothstep(0.2, 0.8, f - 0.1 * dot(a.rgb - b.rgb, vec3(1.0))) * step(0.001, break_up);
	vec3 colour = mix(a.rgb, b.rgb, w);

	// A broad, slow change of tone across the whole wall, in metres, not tiles.
	float broad = noise(metres / 17.0) * 0.65 + noise(metres / 6.5 + 31.0) * 0.35;
	colour *= 1.0 + (broad - 0.5) * 2.0 * variation;
	// Weathering, as rain stains concrete: streaks that start at a ledge (every so
	// many metres down, at a place of their own), darkest where they start and
	// fading and narrowing as they run down; ragged and streaky at their edges, in
	// a brownish grime that darkens the concrete's own grain rather than laying a
	// shade over it; and now and then a pale one, where lime has washed out.
	float down = metres.y / 11.0 + noise(vec2(metres.x / 4.0, 2.0)) * 0.8;
	float band = floor(down);
	float along = fract(down);
	// Each stain is many thin drips: lines a few centimetres wide and metres long...
	float drips = noise(vec2(metres.x / 0.05, metres.y / 5.0)) * 0.65 + noise(vec2(metres.x / 0.018, metres.y / 1.6) + 5.0) * 0.35;
	float streaky = smoothstep(0.3, 0.8, drips);
	// ...gathered where the water ran off the ledge (each band its own places,
	// a metre or two across), the patch narrowing as it runs down,
	float zone = noise(vec2(metres.x / 1.6, band * 13.7)) * 0.75 + noise(vec2(metres.x / 0.5, band * 3.1)) * 0.25;
	float gathered = smoothstep(0.42 + 0.22 * along, 0.66 + 0.22 * along, zone);
	// ...coming on softly under the ledge, and fading as it goes.
	float fall = smoothstep(0.0, 0.08, along) * pow(1.0 - along, 1.3);
	float stain = gathered * streaky * fall;
	float lime_zone = noise(vec2(metres.x / 0.9, band * 5.3 + 40.0));
	float lime = smoothstep(0.78, 0.86, lime_zone) * streaky * fall * step(0.55, noise(vec2(band, 9.0)));
	float grain = dot(colour, vec3(0.33));
	vec3 grime = colour * vec3(0.5, 0.48, 0.43) * (0.85 + 0.3 * grain);
	colour = mix(colour, grime, clamp(stain * weathering * 2.2, 0.0, 1.0));
	colour = mix(colour, colour * vec3(1.22, 1.22, 1.2) + vec3(0.04), lime * weathering * 0.6);

	// Its edges and top, weathered: the worn rounding of each edge paler (the
	// skin of the concrete rubbed off it), raggedly, with chips out of it here
	// and there; grime under the top edge where the rain runs off it, in drips;
	// and the faces very slightly uneven (a slow lean of the normal, below).
	vec2 lean_face = vec2(0.0);
	if (edge_weathering > 0.0 && UV2.x > 0.0) {
		// (metres to the nearest edge across the face and up it: on a side, up is to its top)
		vec2 from_edge = UV2 - abs(UV);
		float nearest = min(from_edge.x, from_edge.y);
		float side = 1.0 - smoothstep(0.55, 0.8, n.y);
		float fine = 1.0 - smoothstep(0.01, 0.05, fwidth(metres.x));
		float ragged = noise(metres / 0.4 + 60.0);
		float worn = 1.0 - smoothstep(edge_size * (0.5 + ragged), edge_size * (1.3 + ragged * 1.8) + 0.03, nearest);
		float chips = noise(metres / 0.13 + 80.0) * 0.7 + noise(metres / 0.05 + 3.0) * 0.3;
		float chip = smoothstep(0.64, 0.7, chips) * (1.0 - smoothstep(edge_size * 0.7, edge_size * 2.2 + 0.05, nearest)) * fine;
		colour = mix(colour, colour * 1.16 + vec3(0.025), worn * (1.0 - chip) * edge_weathering * 0.9);
		colour *= 1.0 - chip * 0.4 * edge_weathering;
		float reach = (0.5 + edge_size * 5.0) * (0.45 + noise(vec2(metres.x / 2.3, 7.0)) * 1.3);
		float runoff = (1.0 - smoothstep(edge_size * 0.6, reach, from_edge.y)) * side * (0.4 + 0.6 * streaky);
		colour = mix(colour, colour * vec3(0.56, 0.54, 0.5), clamp(runoff * edge_weathering * 1.2, 0.0, 0.7));
		vec2 slow = metres / 3.2;
		float here = noise(slow);
		lean_face = vec2(noise(slow + vec2(0.2, 0.0)) - here, noise(slow + vec2(0.0, 0.2)) - here) * edge_weathering * 0.7;
		lean_face += vec2(chips - 0.5, ragged - 0.5) * chip * 0.8;
	}
	colour *= tint.rgb;

	// Moss: where it grows, how thick, and its cushions. It is in clumps a few
	// centimetres across, lighter on their tops and dark down between them, so
	// its edge breaks up into clumps and bare stone rather than a line; and it
	// darkens the damp stone just above it.
	float moss = 0.0;
	float clumps = 0.5;
	if ((moss_foot > 0.0 || moss_patches > 0.0) && abs(n.y) < 0.5) {
		float ragged = noise(vec2(metres.x / 1.4, 3.0)) * 0.75 + noise(vec2(metres.x / 0.5, 8.0)) * 0.25;
		float reach = moss_foot * (0.55 + ragged * 0.9);
		float foot = moss_foot > 0.0 ? 1.0 - smoothstep(reach * 0.55, reach, at.y) : 0.0;
		// (patches drawn out down the wall, as the damp runs, and more ragged than round)
		float spots = noise(vec2(metres.x / 2.2, metres.y / 5.5) + 17.0) * 0.65 + noise(vec2(metres.x / 0.7, metres.y / 1.4) + 3.0) * 0.35;
		// (more of it low down, and gathered where the rain runs: the stains)
		float wanted = 0.8 - moss_patches * 0.9 - stain * 0.12;
		float patch = smoothstep(wanted, wanted + 0.16, spots) * (1.0 - smoothstep(6.0, 60.0, at.y) * 0.6);
		moss = max(foot, patch);
		clumps = noise(metres / 0.055) * 0.6 + noise(metres / 0.021 + 2.0) * 0.4;
		// (too small to see far off: an even cushion there, not a flicker of dark and light)
		clumps = mix(clumps, 0.6, smoothstep(0.01, 0.04, fwidth(metres.x)));
		// (thin moss shows as scattered clumps; thick, as a whole cushion)
		// (its edge frays into tufts some hand-widths across, and those into clumps)
		float tufts = noise(metres / 0.22 + 9.0) * 0.6 + clumps * 0.4;
		float cover = smoothstep(0.3, 0.7, moss * 1.35 - (1.0 - tufts) * 0.75);
		float damp = smoothstep(0.0, 0.6, foot) * (1.0 - cover);
		colour *= 1.0 - damp * 0.35;
		vec3 cushion = mix(moss_dark, moss_light, smoothstep(0.2, 0.8, clumps * 0.6 + tufts * 0.4)) * (0.8 + 0.4 * noise(metres / 0.6 + 50.0));
		colour = mix(colour, cushion, cover);
		moss = cover;
	}
#ifdef LOOMING
	// Far off, what the texture can no longer show, drawn broader: the joints
	// between its slabs, upright, a pixel or two wide (gone where they would
	// crowd into a shimmer), and each slab a shade of its own; the whole wall a
	// little darker the further off it is, and its foot darker still, in the
	// gloom down there; and its top edge and corners a little paler, worn and lit
	// by the sky, so that its outline holds.
	float far_off = length(VERTEX);
	float loom = looming * mist_brood;
	float far = smoothstep(50.0, 260.0, far_off) * loom;
	if (far > 0.0 && abs(n.y) < 0.5) {
		float slabs = metres.x / tile_size;
		float fw = fwidth(slabs);
		float to_joint = abs(fract(slabs + 0.5) - 0.5);
		float joint = (1.0 - smoothstep(0.06 / tile_size, 0.06 / tile_size + fw * 1.2, to_joint)) * (1.0 - smoothstep(0.1, 0.25, fw));
		float later = smoothstep(100.0, 260.0, far_off) * looming;
		colour *= 1.0 - joint * 0.16 * later;
		colour *= 1.0 + (hash(vec2(floor(slabs), 7.0)) - 0.5) * 0.12 * later;
		float foot = 1.0 - smoothstep(0.0, 40.0, at.y);
		colour *= (1.0 - foot * 0.35 * far) * (1.0 - 0.25 * far);
		if (UV2.x > 0.0) {
			vec2 from_edge = UV2 - abs(UV);
			float rim = 1.0 - smoothstep(0.0, max(0.3, fwidth(metres.y) * 2.5), from_edge.y);
			float corner = 1.0 - smoothstep(0.0, max(0.3, fwidth(metres.x) * 1.5), from_edge.x);
			colour = mix(colour, colour * 1.5 + vec3(0.03), max(rim, corner * 0.5) * far);
		}
	}
#endif
	ALBEDO = colour;

	if (has_rough) {
		ROUGHNESS = mix(textureGrad(rough_map, uv + off_a, dx, dy).r, textureGrad(rough_map, uv + off_b, dx, dy).r, w);
	} else {
		ROUGHNESS = roughness;
	}
	// (moss is soft and dull: no shine on it)
	ROUGHNESS = mix(ROUGHNESS, 1.0, moss);
	SPECULAR = mix(0.3, 0.05, moss);

	vec3 bent = n;
	if (has_normal) {
		vec3 t = mix(textureGrad(normal_map, uv + off_a, dx, dy).rgb, textureGrad(normal_map, uv + off_b, dx, dy).rgb, w) * 2.0 - 1.0;
		t.xy *= relief;
		// (the maps are imported as compressed normal maps, which keep only red and
		// green: the blue, how far the normal stands out of the wall, is made again
		// here, or it reads as -1 and the wall is lit as if it faced the other way)
		t.z = sqrt(max(0.0, 1.0 - dot(t.xy, t.xy)));
		// (an OpenGL normal map: red across, green up the picture)
		bent = normalize(u_axis * t.x + v_axis * t.y + n * t.z);
	}
	bent = normalize(bent + (u_axis * lean_face.x + v_axis * lean_face.y));
	if (moss > 0.0) {
		// (the stone's bumps lost under it, and its own cushions in their place)
		float lean = noise(metres / 0.055 + vec2(0.31, 0.0)) - noise(metres / 0.055 - vec2(0.31, 0.0));
		float tip = noise(metres / 0.055 + vec2(0.0, 0.31)) - noise(metres / 0.055 - vec2(0.0, 0.31));
		bent = normalize(mix(bent, normalize(n + (u_axis * lean + v_axis * tip) * 1.2), moss));
	}
	NORMAL = normalize((VIEW_MATRIX * (world_space ? vec4(bent, 0.0) : MODEL_MATRIX * vec4(bent, 0.0))).xyz);
#ifdef LOOMING
	// The mist over it: as the World's mist has it (thickening with distance, and
	// below `mist_height`), but thinner high up, so that the tops loom out of it
	// while the feet are lost in it; and, high up and far off, darker and bluer
	// than the mist and never quite all mist, so that the walls stand against
	// the sky as dark slabs, and paler towards the sun.
	vec3 seen = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float up = smoothstep(mist_height, 110.0, seen.y) * loom;
	float amount = 1.0 - exp(min(0.0, -far_off * mist_density * mix(1.0, 0.7, up)));
	if (abs(mist_height_density) >= 0.0001) {
		amount = max(amount, 1.0 - exp(min(0.0, (seen.y - mist_height) * mist_height_density)));
	}
	float brood = up * smoothstep(40.0, 300.0, far_off);
	vec3 tone = mix(mist_colour, mist_colour * vec3(0.62, 0.67, 0.77), brood);
	float toward = pow(max(dot((seen - CAMERA_POSITION_WORLD) / max(far_off, 0.001), mist_sun), 0.0), 6.0);
	tone += mist_sun_colour * toward * 0.12 * looming;
	FOG = vec4(tone, amount * mix(1.0, 0.8, brood));
#endif
}
"""

@export_range(0.1, 200.0, 0.1, "or_greater", "suffix:m") var width := 14.0:
	set(value):
		width = value
		_build()
@export_range(0.1, 200.0, 0.1, "or_greater", "suffix:m") var height := 34.0:
	set(value):
		height = value
		_build()
@export_range(0.1, 50.0, 0.1, "or_greater", "suffix:m") var depth := 3.2:
	set(value):
		depth = value
		_build()
## How it is built: a plain box (Basic), or with a footing and cornice, pilasters, or a stepped base.
@export var style := Style.BASIC:
	set(value):
		style = value
		_build()
## Its surface, chosen from LOOKS (which sets the textures and a fitting tile
## size), or Custom to keep textures of your own.
@export var look := Look.CAST:
	set(value):
		look = value
		if look != Look.CUSTOM and LOOKS.has(look):
			var maps := maps_for(look)
			texture = maps[0]
			normal_map = maps[1]
			roughness_map = maps[2]
			tile_size = LOOKS[look][1]
		_build()
@export var texture: Texture2D:
	set(value):
		texture = value
		_build()
## Its relief: a normal map (OpenGL, green up), laid on as the texture is, and how strong.
@export var normal_map: Texture2D:
	set(value):
		normal_map = value
		_build()
@export_range(0.0, 4.0, 0.05) var relief := 1.0:
	set(value):
		relief = value
		_build()
## Where it is rough and where smoother; without one, `roughness` all over.
@export var roughness_map: Texture2D:
	set(value):
		roughness_map = value
		_build()
@export_range(0.0, 1.0, 0.01) var roughness := 0.9:
	set(value):
		roughness = value
		_build()
## How many metres one tile of the texture covers.
@export_range(0.25, 50.0, 0.01, "or_greater", "suffix:m") var tile_size := 2.16:
	set(value):
		tile_size = value
		_build()
## How much the texture is broken up so that its repeats do not show (0: not at all).
@export_range(0.0, 1.0, 0.01) var break_up := 1.0:
	set(value):
		break_up = value
		_build()
## How much its tone wanders across the wall, broadly and slowly.
@export_range(0.0, 0.5, 0.01) var variation := 0.22:
	set(value):
		variation = value
		_build()
## How much rain has stained it: grimy streaks running down from ledges, and a few pale ones.
@export_range(0.0, 1.0, 0.01) var weathering := 0.35:
	set(value):
		weathering = value
		_build()
## How far round its top edges and corners are worn, metres (unevenly; 0: square).
@export_range(0.0, 1.5, 0.01, "suffix:m") var edge_rounding := 0.14:
	set(value):
		edge_rounding = value
		_build()
## How weathered its edges and top are: grime run off the top, paler worn
## corners with chips out of them, and its faces very slightly uneven.
@export_range(0.0, 1.0, 0.01) var edge_weathering := 0.5:
	set(value):
		edge_weathering = value
		_build()
## Multiplied over the texture.
@export var tint := Color.WHITE:
	set(value):
		tint = value
		_build()

static var _shader: Shader
static var _looming_shader: Shader

var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	_build()


## A look's [colour, normal, roughness] textures (null where it has none).
static func maps_for(chosen: Look) -> Array:
	var path: String = LOOKS[chosen][0]
	if "%s" in path:
		return [load("res://textures/" + path % "diff"), load("res://textures/" + path % "nor_gl"), load("res://textures/" + path % "rough")]
	var rough := "res://textures/%s_rough.png" % path
	return [load("res://textures/%s.png" % path), load("res://textures/%s_normal.png" % path), load(rough) if ResourceLoader.exists(rough) else null]


## The surface of a look, as a material for anything (`world_space`: laid on in the
## world's space, so that many boxes meet without seams; `looming`: with the
## looming_shader, for the maze's walls).
static func material_for(chosen: Look, world_space := false, tint := Color.WHITE, looming := false) -> ShaderMaterial:
	var maps := maps_for(chosen)
	var material := ShaderMaterial.new()
	material.shader = looming_shader() if looming else shader()
	_apply(material, maps[0], maps[1], maps[2], 0.9, LOOKS[chosen][1], 1.0, tint, 1.0, 0.22, 0.35)
	material.set_shader_parameter(&"world_space", world_space)
	return material


## The wall's shader, made once.
static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader


## The wall's shader drawing its own mist (the maze's walls, laid on in the
## world's space), so that far off they loom out of it as dark slabs against the
## sky instead of fading to grey blobs (the user, 2026-10-19: "The Maze walls
## kind of just becom ugly featureless gray blobs in the distance- is there a way
## we can spruce up how the fog affects them so that we get amore brooding looming
## cinematic visual?"). The mist is the World's, handed on by MazeLight.share_mist.
static func looming_shader() -> Shader:
	if _looming_shader == null:
		_looming_shader = Shader.new()
		_looming_shader.code = SHADER.replace("shader_type spatial;", "shader_type spatial;\n#define LOOMING")
	return _looming_shader


static func _apply(material: ShaderMaterial, colour: Texture2D, bump: Texture2D, rough: Texture2D, rough_value: float, tile: float, strength: float, shade: Color, broken: float, wander: float, rain := 0.35) -> void:
	material.set_shader_parameter(&"weathering", rain)
	material.set_shader_parameter(&"albedo_map", colour)
	material.set_shader_parameter(&"normal_map", bump)
	material.set_shader_parameter(&"has_normal", bump != null)
	material.set_shader_parameter(&"rough_map", rough)
	material.set_shader_parameter(&"has_rough", rough != null)
	material.set_shader_parameter(&"roughness", rough_value)
	material.set_shader_parameter(&"tile_size", tile)
	material.set_shader_parameter(&"relief", strength)
	material.set_shader_parameter(&"tint", shade)
	material.set_shader_parameter(&"break_up", broken)
	material.set_shader_parameter(&"variation", wander)


func _build() -> void:
	_fill_missing()
	if not is_inside_tree():
		return
	# (its own mesh and shape, found again if the script was reloaded in the editor, never made twice)
	if _mesh == null or not is_instance_valid(_mesh):
		_mesh = _own_child("Mesh", MeshInstance3D) as MeshInstance3D
	if _shape == null or not is_instance_valid(_shape):
		_shape = _own_child("Shape", CollisionShape3D) as CollisionShape3D
	var size := Vector3(width, height, depth)
	var boxes := style_boxes(style, size)
	var drawn := WallMesh.new()
	for part: Array in boxes:
		drawn.add_box(Transform3D.IDENTITY, part[0], part[1], edge_rounding)
	_mesh.mesh = drawn.mesh()
	_mesh.position = Vector3.ZERO
	# A box to bump into for each part (the first is the one made before styles).
	var shapes: Array[CollisionShape3D] = [_shape]
	for child in get_children(true):
		if child is CollisionShape3D and child != _shape and String(child.name).begins_with("Part"):
			shapes.append(child)
	while shapes.size() < boxes.size():
		var more := CollisionShape3D.new()
		more.name = "Part%d" % shapes.size()
		add_child(more, false, Node.INTERNAL_MODE_BACK)
		shapes.append(more)
	for i in shapes.size():
		shapes[i].disabled = i >= boxes.size()
		if i < boxes.size():
			var shape := BoxShape3D.new()
			shape.size = boxes[i][1]
			shapes[i].shape = shape
			shapes[i].position = boxes[i][0]
	var material := _mesh.material_override as ShaderMaterial
	if material == null:
		material = ShaderMaterial.new()
		material.shader = shader()
		_mesh.material_override = material
	_apply(material, texture, normal_map, roughness_map, roughness, tile_size, relief, tint, break_up, variation, weathering)
	material.set_shader_parameter(&"edge_size", edge_rounding)
	material.set_shader_parameter(&"edge_weathering", edge_weathering)


## The boxes a wall of `style`, `size` overall body (width along X, height,
## depth along Z, standing on the origin), is built of, as [middle, size]. The
## first is always the body itself; the rest stand out from it.
static func style_boxes(chosen: Style, size: Vector3) -> Array:
	var h := size.y
	var body := [Vector3(0.0, h * 0.5, 0.0), size]
	match chosen:
		Style.CORNICE:
			# A stepped footing (two courses) and a deep cornice with a band under it.
			return [body,
				[Vector3(0.0, 0.8, 0.0), Vector3(size.x + 1.6, 1.6, size.z + 1.6)],
				[Vector3(0.0, 2.1, 0.0), Vector3(size.x + 0.8, 1.0, size.z + 0.8)],
				[Vector3(0.0, h - 0.9, 0.0), Vector3(size.x + 1.4, 1.8, size.z + 1.4)],
				[Vector3(0.0, h - 2.4, 0.0), Vector3(size.x + 0.6, 1.2, size.z + 0.6)]]
		Style.PILASTERS:
			# Square piers standing out of both faces, every 6 m or so along it, and at its ends.
			var parts := [body]
			var long := size.x >= size.z
			var length := size.x if long else size.z
			var count := maxi(roundi(length / 6.0), 1)
			for i in count + 1:
				var along := -length * 0.5 + length * float(i) / count
				var at := Vector3(along, h * 0.5, 0.0) if long else Vector3(0.0, h * 0.5, along)
				var wide := 1.4
				var out := (size.z if long else size.x) + 1.2
				parts.append([at, Vector3(wide, h, out) if long else Vector3(out, h, wide)])
			return parts
		Style.STEPPED:
			# A heavy base in two setbacks, a third and two thirds of the way up.
			return [body,
				[Vector3(0.0, h * 0.17, 0.0), Vector3(size.x + 2.4, h * 0.34, size.z + 2.4)],
				[Vector3(0.0, h * 0.34, 0.0), Vector3(size.x + 1.2, h * 0.68, size.z + 1.2)]]
	return [body]


## Gives any setting that is empty its default. (When the editor reloads this
## script after it has changed, a wall already in an open scene can come back with
## settings it did not have before left empty.)
func _fill_missing() -> void:
	var defaults := {
		"width": 14.0, "height": 34.0, "depth": 3.2, "style": Style.BASIC, "look": Look.CAST, "relief": 1.0, "roughness": 0.9,
		"tile_size": 2.16, "break_up": 1.0, "variation": 0.22, "weathering": 0.35, "tint": Color.WHITE,
		"edge_rounding": 0.14, "edge_weathering": 0.5,
	}
	for key: String in defaults:
		if get(key) == null:
			set(key, defaults[key])
	if look != Look.CUSTOM and LOOKS.has(look) and texture == null:
		var maps := maps_for(look)
		texture = maps[0]
		if normal_map == null:
			normal_map = maps[1]
		if roughness_map == null:
			roughness_map = maps[2]


## The internal child called `called` of class `kind`, made if there is none (and
## any others of that name, left over, taken away).
func _own_child(called: String, kind: Variant) -> Node:
	var found: Node = null
	for child in get_children(true):
		if String(child.name).begins_with(called) and is_instance_of(child, kind):
			if found == null:
				found = child
			else:
				child.queue_free()
	if found == null:
		found = kind.new()
		found.name = called
		add_child(found, false, Node.INTERNAL_MODE_BACK)
	return found
