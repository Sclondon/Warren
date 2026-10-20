@tool
class_name RoundBuilder
extends Node3D
## Puts up the round sections of a maze (RoundMaze): the great circular walls
## between them, with their gates, and the walls of their passages, round and
## out; and the light past the way out of the last. Each wall is a box (a curved
## one, short straight lengths round the circle); they are merged into one mesh
## and one shape to walk into for each stretch of each section, so that a
## thousand-metre maze goes up in moments.
##
## A section of rotating doors (RoundStyle.Layout.ROTATING_DOORS) has, instead of
## passages, circles of wall broken by doorways, a great slab turning on a pivot in
## each (an AnimatableBody3D, so that it shoves whoever it meets); they turn by the
## round's clock (World.clock), so in step for everyone in a room. A tunnel section
## (TUNNEL) is roofed over from wall to wall, its inside lined in darker stone and
## lit only through slots in its roof.

## How many stretches each section is built in, round it (each its own mesh,
## drawn only when on the screen and near enough).
const STRETCHES := 32
## Curved walls are made of straight lengths no longer than this round, radians.
const STEP := 0.05
## Past this the walls are lost in the mist: not drawn.
const FAR := 700.0
## Doors nearer than this to the camera are turned every physics frame; the rest
## a few a frame, in turn (they are lost in the mist, and nobody is by them).
const DOORS_NEAR := 240.0
const DOORS_FAR_EACH_FRAME := 4
## Past this, a door is not drawn.
const DOORS_SHOWN := 420.0
## How thick a tunnel's roof is, how long round each slot in it, metres.
const ROOF_THICK := 2.4
const SKYLIGHT_LONG := 5.0

## What each part is made of: the maze's walls, the great walls, a tunnel's lining
## and roof, the shafts of light down from its slots (drawn only: nothing to walk into).
enum Part { MAZE, GREAT, LINING, LIGHT }

var plan: RoundMaze
## The light past the way out.
var beacon: Node3D
## Each rotating door: [body, where its pivot is, ring, its index in ring.doors, angle round].
var doors: Array = []
## Where the round's time comes from (the World: its clock); with none, its own.
var clock_from: Node
var _own_clock := 0.0
## (set, the doors stand at this time: for tests and pictures)
var time_fixed := -1.0
var _far_next := 0

# [part, section, stretch] -> [vertices, normals] (and colours, for the light) of
# the plain boxes, to walk into (the light's, only drawn).
var _parts := {}
# [part, section, stretch] -> WallMesh: the boxes as drawn, their edges worn round.
var _drawn := {}


func _ready() -> void:
	var body := StaticBody3D.new()
	body.name = "Walls"
	# The great walls across the desert ring from the square's corners to the first
	# circle, unbroken: its quarters are walled apart.
	if plan.desert:
		var corner := plan.square_half * sqrt(2.0)
		for a: float in RoundMaze.DIAGONALS:
			_radial(0, a, corner, plan.inner_radius, MazeBuilder.RING_THICK, plan.desert.diagonal_wall_height, Part.GREAT)
		# (the desert ring the last built: its far wall, with a way out of each quarter)
		if plan.rings.is_empty():
			_circle(0, plan.inner_radius, MazeBuilder.RING_THICK, plan.desert.far_wall_height, plan.desert_gates)
	for k in plan.rings.size():
		var ring: RoundMaze.Ring = plan.rings[k]
		var style := ring.style
		# The great wall round its inside, with its gates: the outer wall of the
		# circle inside it, or for the first the desert's far wall.
		var inside_high := plan.rings[k - 1].style.section_border_wall_height if k > 0 else (plan.desert.far_wall_height if plan.desert else MazeBuilder.RING_HEIGHT)
		_circle(k, ring.inner, MazeBuilder.RING_THICK, inside_high, ring.gates_in)
		if k == plan.rings.size() - 1:
			_circle(k, ring.outer, MazeBuilder.RING_THICK, style.section_border_wall_height, ring.gates_out)
		match ring.layout:
			RoundStyle.Layout.ROTATING_DOORS:
				_door_circles(k, ring)
				continue
			RoundStyle.Layout.TUNNEL:
				_tunnel(k, ring)
				continue
		var thick := style.maze_wall_diameter
		var high := style.maze_wall_height
		for i in ring.rows.size():
			var row: Array = ring.rows[i]
			var cells: int = row[2]
			for j in cells:
				# Out from the middle between it and the next round, where they are not joined.
				if not RoundMaze.joined(ring, Vector2i(i, j), Vector2i(i, (j + 1) % cells)):
					_radial(k, RoundMaze.angle_of(j + 1, cells), row[0], row[1], thick, high)
				# Round between it and the cells of the next row out that it touches.
				if i + 1 < ring.rows.size():
					for touch: Array in RoundMaze.touching(j, cells, ring.rows[i + 1][2]):
						if not RoundMaze.joined(ring, Vector2i(i, j), Vector2i(i + 1, touch[0])):
							_arc(k, row[1], touch[1], touch[2], thick, high)
	# (the tunnel's lining and its light, one of each; the maze and great walls one
	# of each for each section: its own moss and size of concrete, as its style says)
	var shared := {Part.LINING: _lining_material(), Part.LIGHT: _light_material()}
	(shared[Part.LINING] as ShaderMaterial).set_shader_parameter(&"tile_size", Wall.LOOKS[MazeBuilder.GREAT_LOOK][1] * MazeBuilder.GREAT_TILE_SCALE * 0.5)
	for ring: RoundMaze.Ring in plan.rings:
		if ring.layout == RoundStyle.Layout.TUNNEL:
			(shared[Part.LIGHT] as ShaderMaterial).set_shader_parameter(&"top", (ring.style as RoundStyle).tunnel_height)
	var materials := {}
	for key: Array in _parts:
		if shared.has(key[0]):
			materials[[key[0], key[1]]] = shared[key[0]]
		elif not materials.has([key[0], key[1]]):
			var great: bool = key[0] == Part.GREAT
			# (drawing their own mist, to loom out of it far off: Wall.looming_shader)
			var made := Wall.material_for(MazeBuilder.GREAT_LOOK if great else MazeBuilder.MAZE_LOOK, true, Color.WHITE, true)
			var style: MazeStyle = plan.rings[key[1]].style if key[1] < plan.rings.size() else null
			if great:
				made.set_shader_parameter(&"tile_size", Wall.LOOKS[MazeBuilder.GREAT_LOOK][1] * MazeBuilder.GREAT_TILE_SCALE)
			elif style:
				made.set_shader_parameter(&"tile_size", Wall.LOOKS[MazeBuilder.MAZE_LOOK][1] * style.wall_texture_scale)
			MazeBuilder.moss(made, style)
			MazeBuilder.weather(made, style, great)
			materials[[key[0], key[1]]] = made
	for key: Array in _parts:
		var part: Array = _parts[key]
		var mesh: ArrayMesh
		if _drawn.has(key):
			mesh = (_drawn[key] as WallMesh).mesh()
		else:
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = part[0]
			arrays[Mesh.ARRAY_NORMAL] = part[1]
			if part.size() > 2:
				arrays[Mesh.ARRAY_COLOR] = part[2]
			mesh = ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var shown := MeshInstance3D.new()
		shown.mesh = mesh
		shown.material_override = materials[[key[0], key[1]]]
		# (in the editor, seen from far over the whole maze, always)
		shown.visibility_range_end = 0.0 if Engine.is_editor_hint() else FAR
		if key[0] == Part.LIGHT:
			shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shown.visibility_range_end = 0.0 if Engine.is_editor_hint() else 260.0
			add_child(shown)
			continue
		add_child(shown)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(part[0])
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
	# (its shapes all in before it goes into the world: see MazeBuilder.realize)
	add_child(body)
	_put_doors()
	# The light past the way out.
	beacon = MazeBuilder.beacon_light()
	beacon.name = "Beacon"
	beacon.position = Vector3(cos(plan.exit_angle), 0.0, sin(plan.exit_angle)) * (plan.outermost() + 22.0)
	add_child(beacon)


## A point `r` out at angle `a`, on the ground.
static func at(a: float, r: float) -> Vector3:
	return Vector3(cos(a), 0.0, sin(a)) * r


## A great wall round the circle `r` out, but for a gap `gap_wide` across at each
## of `gates` (angles); standing from `base` up.
func _circle(k: int, r: float, thick: float, high: float, gates: Array[float], part := Part.GREAT, gap_wide := RoundMaze.GATE_WIDE, base := 0.0) -> void:
	var gap := gap_wide * 0.5 / r
	var count := ceili(TAU / STEP)
	for n in count:
		var a0 := TAU * n / count
		var a1 := TAU * (n + 1) / count
		var lo := a0
		var hi := a1
		var whole := true
		for g: float in gates:
			# (the stretch of this length inside the gap, if any, is left out)
			var g0 := g - gap
			var g1 := g + gap
			for shift: float in [-TAU, 0.0, TAU]:
				var s0 := g0 + shift
				var s1 := g1 + shift
				if s1 <= lo or s0 >= hi:
					continue
				whole = false
				if s0 > lo:
					_arc(k, r, lo, s0, thick, high, part, base)
				lo = maxf(lo, s1)
		if whole or lo < hi:
			_arc(k, r, lo, hi, thick, high, part, base)


## A wall round the circle `r` out from angle `a0` to `a1`, in straight lengths.
func _arc(k: int, r: float, a0: float, a1: float, thick: float, high: float, part := Part.MAZE, base := 0.0) -> void:
	var lengths := maxi(ceili((a1 - a0) / STEP), 1)
	for n in lengths:
		var b0 := a0 + (a1 - a0) * n / lengths
		var b1 := a0 + (a1 - a0) * (n + 1) / lengths
		var middle := (b0 + b1) * 0.5
		var half := (b1 - b0) * 0.5
		# (a little longer than the chord, so that the lengths meet round the outside)
		var long := 2.0 * r * sin(half) + thick * tan(half) * 2.0 + 0.05
		_box(k, middle, r * cos(half), Vector3(long, high, thick), part, base, false)


## A wall out from `r0` to `r1` at angle `a` (as long again as the walls it meets are thick, to meet them).
func _radial(k: int, a: float, r0: float, r1: float, thick: float, high: float, part := Part.MAZE) -> void:
	_box(k, a, (r0 + r1) * 0.5, Vector3(thick, high, r1 - r0 + thick), part)


## Section `k`'s style (null if it has none).
func _style(k: int) -> MazeStyle:
	return plan.rings[k].style if k < plan.rings.size() else null


## A box `size` (along the circle, high, out) standing with its middle `r` out
## at angle `a`, from `base` up. Drawn with its edges worn round
## (MazeStyle.wall_edge_rounding; a tunnel's lining not), but for its ends along
## the circle unless `round_ends` (a length of a curved wall runs on into the next).
func _box(k: int, a: float, r: float, size: Vector3, part := Part.MAZE, base := 0.0, round_ends := true) -> void:
	var out := Vector3(cos(a), 0.0, sin(a))
	var along := Vector3(-out.z, 0.0, out.x)
	var middle := out * r + Vector3.UP * base
	var stretch := posmod(floori(a / TAU * STRETCHES), STRETCHES)
	var key := [part, k, stretch]
	if not _parts.has(key):
		_parts[key] = [PackedVector3Array(), PackedVector3Array()]
		_drawn[key] = WallMesh.new()
	var great := part == Part.GREAT
	var rounding := 0.0 if part == Part.LINING else MazeBuilder.edge_rounding(_style(k), great)
	(_drawn[key] as WallMesh).add_box(Transform3D(Basis(along, Vector3.UP, -out), middle), Vector3.UP * size.y * 0.5, size,
		rounding, round_ends, true, MazeBuilder.edge_spacing(great), base > 0.0)
	var bits: Array = _parts[key]
	var points: PackedVector3Array = bits[0]
	var normals: PackedVector3Array = bits[1]
	var hx := along * size.x * 0.5
	var hz := out * size.z * 0.5
	var top := Vector3.UP * size.y
	# (each face as two triangles, wound so that its outside is its front)
	for face: Array in [[hz, hx, top], [-hz, -hx, top], [hx, -hz, top], [-hx, hz, top]]:
		var n: Vector3 = face[0]
		var w: Vector3 = face[1]
		var c := middle + n
		var p0 := c - w
		var p1 := c + w
		var p2 := c + w + top
		var p3 := c - w + top
		_quad(points, normals, p0, p1, p2, p3, n.normalized())
	var corner := [middle - hx - hz, middle + hx - hz, middle + hx + hz, middle - hx + hz]
	_quad(points, normals, corner[3] + top, corner[2] + top, corner[1] + top, corner[0] + top, Vector3.UP)
	# (one up off the ground has an underside: a roof)
	if base > 0.0:
		_quad(points, normals, corner[0], corner[1], corner[2], corner[3], Vector3.DOWN)
	bits[0] = points
	bits[1] = normals


static func _quad(points: PackedVector3Array, normals: PackedVector3Array, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, normal: Vector3) -> void:
	# (Godot's fronts are wound clockwise as seen from in front)
	var tris := [p0, p2, p1, p0, p3, p2]
	if (p1 - p0).cross(p2 - p0).dot(normal) < 0.0:
		tris = [p0, p1, p2, p0, p2, p3]
	for p: Vector3 in tris:
		points.append(p)
		normals.append(normal)


# --- Rotating doors -----------------------------------------------------------

## The circles of wall across a section of rotating doors, a doorway at each of its doors.
func _door_circles(k: int, ring: RoundMaze.Ring) -> void:
	var by_circle := {}
	for door: Array in ring.doors:
		if not by_circle.has(door[0]):
			by_circle[door[0]] = [] as Array[float]
		(by_circle[door[0]] as Array[float]).append(door[1])
	var high := ring.style.maze_wall_height
	var thick := ring.style.maze_wall_diameter
	for c in ring.door_radii.size():
		var r := ring.door_radii[c]
		var gaps: Array[float] = by_circle.get(c, [] as Array[float])
		_circle(k, r, thick, high, gaps, Part.MAZE, ring.doorway)
		# (a lintel over each doorway, that its door hangs from)
		var half := (ring.doorway * 0.5 + 0.5) / r
		for a: float in gaps:
			_arc(k, r, a - half, a + half, thick, LINTEL, Part.MAZE, high - LINTEL)


## How deep the lintel over a doorway is, and the gap under it over its door, metres.
const LINTEL := 3.0
const UNDER_LINTEL := 0.8


## The doors themselves: a slab on a pivot in each doorway, moved by the clock.
func _put_doors() -> void:
	var holder: Node3D = null
	var material: ShaderMaterial = null
	for k in plan.rings.size():
		var ring: RoundMaze.Ring = plan.rings[k]
		if ring.layout != RoundStyle.Layout.ROTATING_DOORS or ring.doors.is_empty():
			continue
		if holder == null:
			holder = Node3D.new()
			holder.name = "Doors"
			add_child(holder)
			# (darker cast stone than the walls, so that they stand out from them)
			material = Wall.material_for(MazeBuilder.GREAT_LOOK, false, Color(0.62, 0.6, 0.56))
		var high := ring.style.maze_wall_height - LINTEL - UNDER_LINTEL
		var size := Vector3(ring.door_long, high, ring.door_thick)
		var mesh := BoxMesh.new()
		mesh.size = size
		var shape := BoxShape3D.new()
		shape.size = size
		for n in ring.doors.size():
			var door: Array = ring.doors[n]
			var a: float = door[1]
			var pivot := at(a, ring.door_radii[door[0]])
			var slab := AnimatableBody3D.new()
			slab.name = "Door%d_%d" % [k, n]
			# (moved in step with the physics, so that it carries and shoves)
			slab.sync_to_physics = true
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.position.y = high * 0.5
			slab.add_child(collider)
			var shown := MeshInstance3D.new()
			shown.mesh = mesh
			shown.material_override = material
			shown.position.y = high * 0.5
			shown.visibility_range_end = 0.0 if Engine.is_editor_hint() else DOORS_SHOWN
			slab.add_child(shown)
			slab.transform = _door_transform(ring, n, pivot, a, _time())
			holder.add_child(slab)
			doors.append([slab, pivot, ring, n, a])
	set_physics_process(not doors.is_empty() and not Engine.is_editor_hint())


## Where door `n` of `ring` stands at `time`: on its pivot, turned from along its circle.
static func _door_transform(ring: RoundMaze.Ring, n: int, pivot: Vector3, a: float, time: float) -> Transform3D:
	# (turned -a - half a turn about the up, its length lies along the circle)
	return Transform3D(Basis(Vector3.UP, -a - PI * 0.5 + RoundMaze.door_turn(ring, n, time)), pivot)


## The round's time: the World's clock (the same on every machine in a room).
func _time() -> float:
	if time_fixed >= 0.0:
		return time_fixed
	if clock_from == null:
		var up := get_parent()
		while up and not (&"clock" in up):
			up = up.get_parent()
		clock_from = up
		if clock_from == null:
			clock_from = self
	return float(clock_from.get(&"clock")) if clock_from != self else _own_clock


func _physics_process(delta: float) -> void:
	_own_clock += delta
	var time := _time()
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera else Vector3.INF
	var far_left := DOORS_FAR_EACH_FRAME
	for d in doors.size():
		var door: Array = doors[d]
		var pivot: Vector3 = door[1]
		if camera == null or Vector2(eye.x - pivot.x, eye.z - pivot.z).length() < DOORS_NEAR:
			(door[0] as AnimatableBody3D).transform = _door_transform(door[2], door[3], pivot, door[4], time)
	# (the far ones a few at a time, in turn)
	if camera:
		while far_left > 0 and not doors.is_empty():
			far_left -= 1
			_far_next = (_far_next + 1) % doors.size()
			var door: Array = doors[_far_next]
			(door[0] as AnimatableBody3D).transform = _door_transform(door[2], door[3], door[1], door[4], time)


## Puts every door where it is at `time` at once (for tests and pictures).
func set_doors_at(time: float) -> void:
	time_fixed = time
	for door: Array in doors:
		(door[0] as AnimatableBody3D).transform = _door_transform(door[2], door[3], door[1], door[4], time)


# --- Tunnel -------------------------------------------------------------------

## A tunnel section: a roof from wall to wall with slots in it, its walls and the
## roof's underside lined in darker stone, and a faint shaft of light down from
## each slot.
func _tunnel(k: int, ring: RoundMaze.Ring) -> void:
	var style := ring.style as RoundStyle
	var high := style.tunnel_height
	var near := ring.inner + MazeBuilder.RING_THICK * 0.5
	var far := ring.outer - MazeBuilder.RING_THICK * 0.5
	var middle := (near + far) * 0.5
	var lining := 0.3
	# (the linings, just inside the walls, with the gates' gaps)
	_circle(k, near + lining * 0.5 + 0.02, lining, high, ring.gates_in, Part.LINING)
	_circle(k, far - lining * 0.5 - 0.02, lining, high, ring.gates_out, Part.LINING)
	# (and its floor: flagstones, a few centimetres up)
	_circle(k, middle, far - near, 0.05, [] as Array[float], Part.LINING)
	# The roof: over both walls, with a slot across it every so often.
	var slots: Array[float] = []
	var count := maxi(roundi(TAU * middle / style.tunnel_skylight_spacing), 8)
	for n in count:
		slots.append(TAU * (n + 0.5) / count)
	_circle(k, middle, far - near + MazeBuilder.RING_THICK, ROOF_THICK - 0.6, slots, Part.LINING, SKYLIGHT_LONG, high)
	# (its top, seen from up on the walls, the great walls' stone in the mist)
	_circle(k, middle, far - near + MazeBuilder.RING_THICK, 0.6, slots, Part.GREAT, SKYLIGHT_LONG, high + ROOF_THICK - 0.6)
	# (a shaft of light down from each slot, a little narrower than it, fading
	# toward the floor: two crossed sheets of faint glow)
	for a: float in slots:
		_shaft(k, a, middle, far - near - 2.0, high)


## A faint shaft of light down from a slot in the roof, `wide` across the tunnel
## and `high` from the floor, at angle `a`, and the pale patch it makes on the floor.
## (Each corner's colour carries how bright it is, and whether it is on the floor.)
func _shaft(k: int, a: float, r: float, wide: float, high: float) -> void:
	var out := Vector3(cos(a), 0.0, sin(a))
	var along := Vector3(-out.z, 0.0, out.x)
	var key := [Part.LIGHT, k, posmod(floori(a / TAU * STRETCHES), STRETCHES)]
	if not _parts.has(key):
		_parts[key] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
	var bits: Array = _parts[key]
	var points: PackedVector3Array = bits[0]
	var normals: PackedVector3Array = bits[1]
	var colours: PackedColorArray = bits[2]
	var centre := out * r
	var half_long := SKYLIGHT_LONG * 0.4
	var half_wide := wide * 0.5
	# (a sheet across the tunnel, and one along it)
	for sheet: Array in [[out * half_wide, along], [along * half_long, out]]:
		var w: Vector3 = sheet[0]
		var n: Vector3 = sheet[1]
		var p0 := centre - w
		var p1 := centre + w
		var p2 := centre + w + Vector3.UP * high
		var p3 := centre - w + Vector3.UP * high
		for p: Vector3 in [p0, p1, p2, p0, p2, p3]:
			points.append(p)
			normals.append(n)
			colours.append(Color(1.0, 0.0, 0.0))
	# The patch on the floor: bright in its middle, fading out to its edges.
	var lift := Vector3.UP * 0.09
	var inner: Array[Vector3] = []
	var outer: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		inner.append(centre + lift + out * corner.x * (half_wide - 4.0) + along * corner.y * SKYLIGHT_LONG * 0.3)
		outer.append(centre + lift + out * corner.x * half_wide + along * corner.y * SKYLIGHT_LONG * 0.9)
	var lit := Color(1.0, 1.0, 0.0)
	var dark := Color(0.0, 1.0, 0.0)
	var tris: Array = [[inner[0], inner[1], inner[2], lit, lit, lit], [inner[0], inner[2], inner[3], lit, lit, lit]]
	for i in 4:
		var j := (i + 1) % 4
		tris.append([inner[i], outer[i], outer[j], lit, dark, dark])
		tris.append([inner[i], outer[j], inner[j], lit, dark, lit])
	for tri: Array in tris:
		for m in 3:
			points.append(tri[m])
			normals.append(Vector3.UP)
			colours.append(tri[m + 3])
	bits[0] = points
	bits[1] = normals
	bits[2] = colours


## A tunnel's lining: the great walls' cast stone, much darker, not lit up by the
## mist and hardly by the sun (their light would make the inside as bright as out,
## past where the sun's shadows reach); the slots' light is the shafts'.
static func _lining_material() -> ShaderMaterial:
	var from := Wall.material_for(MazeBuilder.GREAT_LOOK, true, Color(0.5, 0.5, 0.48))
	var shader := Shader.new()
	shader.code = Wall.shader().code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode fog_disabled;") + """
void light() {
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI * 0.08;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	for uniform: Dictionary in Wall.shader().get_shader_uniform_list():
		material.set_shader_parameter(uniform.name, from.get_shader_parameter(uniform.name))
	return material


## The faint shafts' look: pale, added to what is behind, fading out toward the
## floor and at its edges, and with distance.
static func _light_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(0.62, 0.66, 0.64, 1.0);
uniform float strength = 0.45;
uniform float floor_strength = 0.3;
uniform float top = 18.0;
varying float up;
void vertex() {
	up = clamp(VERTEX.y / top, 0.0, 1.0);
}
void fragment() {
	// (lost with distance, as the mist would)
	float d = length(VERTEX);
	float seen = 1.0 - smoothstep(35.0, 90.0, d);
	// A shaft: brightest at the roof, fading toward the floor; not right up close,
	// and softer seen edge on.
	float shaft = up * (1.0 - smoothstep(0.92, 1.0, up) * 0.5) * smoothstep(1.5, 6.0, d)
		* smoothstep(0.0, 0.7, abs(dot(NORMAL, VIEW))) * strength;
	// The patch on the floor, to its edges.
	float patch = COLOR.r * floor_strength;
	ALBEDO = tint.rgb * mix(shaft, patch, COLOR.g) * COLOR.r * seen;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
