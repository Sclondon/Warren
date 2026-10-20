@tool
class_name MazeBuilder
extends Node3D
## Puts a maze up in the world from its pieces (a MazeLayout, generated from a
## Maze or laid out by hand in the editor): the walls, piers and terraces merged
## into a few meshes of blocks, with a box to bump into for each, the ivy, vines
## and bridges (MazeFeatures), the ground and its grass, the pines, and a pale
## light standing up past the exit, seen over the walls.
##
## The walls are not made for people. The passages are wide enough for a cart,
## and the walls go up five times as high as that; the walls between rings (the
## clearing's own wall among them) are higher and thicker again.
##
## Build a new one for each maze; free the old one.

## The walls inside a ring, and the great walls between rings.
const WALL_HEIGHT := 34.0
const WALL_THICK := 3.2
const RING_HEIGHT := 46.0
const RING_THICK := 4.2

## How far the footing of a wall stands out from its face, and how high it is;
## the same for the cornice along its top. And how much wider a pier is than the
## walls it stands at, and how far it rises above them.
const FOOT := Vector2(0.7, 1.6)
const CORNICE := Vector2(0.6, 1.8)
const PIER := Vector2(2.2, 4.0)

## The walls are drawn in squares this many metres across, so that what is off
## the screen is not drawn, in Wall's concrete (see surface_of).
const CHUNK := 70.0

## How far the blocks' backs sit in from the face that is bumped into, how far
## they may stand proud of it or sink into it, the joint between them, and the
## chamfer on their edges. A course is between `COURSE` heights, a block between
## `BLOCK` lengths.
const BLOCK_INSET := 0.16
const PROUD := Vector2(-0.07, 0.14)
const JOINT := 0.07
const CHAMFER := 0.16
const COURSE := Vector2(2.6, 3.6)
const BLOCK := Vector2(4.5, 8.0)

var maze: Maze
## The pieces it was built from.
var layout: MazeLayout
## The light past the exit.
var beacon: Node3D
## The terraces, ivy, vines and bridges (MazeFeatures).
var features: MazeFeatures
## The vents, drains, boxes, barrels and old cables (MazeProps).
var props: MazeProps
## The ferns, bushes, moss and tufts of grass.
var undergrowth: Undergrowth
## The corn in rooms and stretches of hall (Corn).
var corn: Corn
## The ground's material (MazeStone.ground), for the weather to wet.
var ground_material: ShaderMaterial
## For the maze editor's live preview: only what shows the maze's rules (no grass,
## marsh or undergrowth: they do not run in the editor, and are only dressing).
var preview := false
## The round sections, if the maze has any.
var round_sections: RoundBuilder
## The standing water in the halls (Ponds).
var ponds: Ponds


## For a loading screen: with `stepwise` on, building stops for a frame between
## its stages and says which comes next (`building`), so that the screen is not
## frozen while the maze goes up. Off, it is all built at once, as before (and
## `build` and `realize` then finish before they return, awaited or not).
signal building(what: String)
var stepwise := false


func _breathe(what: String) -> void:
	building.emit(what)
	# (two frames: one to draw what it now says)
	await get_tree().process_frame
	await get_tree().process_frame


## What is in the desert ring's forest, swamp and plains quarters, built near the
## camera (Wilds), if it has any.
var wilds: Wilds


## Builds the maze `plan`, laid out as it generates.
func build(plan: Maze) -> void:
	if stepwise:
		await _breathe("Laying out the maze")
	layout = MazeLayout.new()
	layout.name = "Layout"
	add_child(layout)
	layout.lay_out(plan)
	await realize(layout, plan)


## Builds the maze laid out by `pieces` (a MazeLayout, which may be another
## node's: it is only read). The plan is read from where its walls stand, unless
## `plan` is given.
func realize(pieces: MazeLayout, plan: Maze = null) -> void:
	layout = pieces
	maze = plan if plan else pieces.plan()
	if stepwise:
		await _breathe("Raising the walls")
	var body := StaticBody3D.new()
	body.name = "Walls"
	# (its shapes all put in before it goes into the world: put in one by one
	# after, each would have the physics make the body over again)
	_walls(body, pieces)
	add_child(body)
	if stepwise:
		await _breathe("Growing the ivy and hanging the vines")
	features = MazeFeatures.new()
	features.name = "Features"
	add_child(features)
	features.realize(pieces)
	props = MazeProps.new()
	props.name = "Props"
	props.realize(pieces)
	add_child(props)
	if stepwise:
		await _breathe("Sowing the grass")
	if not preview:
		_grass()
	_ground()
	# (the standing water in the halls, and the flooded marsh gate's slot)
	ponds = Ponds.new()
	ponds.name = "Ponds"
	add_child(ponds)
	ponds.realize(maze, pieces, ground_material, preview)
	if not preview:
		_pond()
	if stepwise:
		await _breathe("Planting the trees")
	_trees(pieces)
	if not preview:
		_undergrowth(pieces)
		# (the corn in rooms and halls: Corn, MazeStyle "Plants")
		corn = Corn.plant_maze(maze, features.footprints)
		add_child(corn)
		corn.build()
	# The round sections outside the square ones, past the moor.
	if maze.round_rings:
		if stepwise:
			await _breathe("Building the round sections")
		round_sections = RoundBuilder.new()
		round_sections.name = "Round"
		round_sections.plan = maze.round_rings
		add_child(round_sections)
		beacon = round_sections.beacon
	for piece in pieces.pieces(MazePiece.Kind.BEACON):
		beacon = beacon_light()
		beacon.name = "Beacon"
		beacon.position = piece.position
		add_child(beacon)


## For the maze editor's live preview, which is built a zone at a time
## (MazeLayout.zone_views): the walls, ways up, props, trees and beacon of `pieces`
## alone, as realize builds them; the ground and water are realize_ground's. With
## `walls`, those walls (built before of the same stone) in place of building them.
func realize_zone(pieces: MazeLayout, plan: Maze, walls: Node = null) -> void:
	layout = pieces
	maze = plan
	if walls == null:
		var body := StaticBody3D.new()
		body.name = "Walls"
		_walls(body, pieces)
		walls = body
	add_child(walls)
	features = MazeFeatures.new()
	features.name = "Features"
	add_child(features)
	features.realize(pieces)
	props = MazeProps.new()
	props.name = "Props"
	props.realize(pieces)
	add_child(props)
	_trees(pieces)
	for piece in pieces.pieces(MazePiece.Kind.BEACON):
		beacon = beacon_light()
		beacon.name = "Beacon"
		beacon.position = piece.position
		add_child(beacon)


## For the live preview: the ground under all of `pieces` and the standing water
## in it, as realize builds them.
func realize_ground(pieces: MazeLayout, plan: Maze) -> void:
	layout = pieces
	maze = plan
	_ground()
	ponds = Ponds.new()
	ponds.name = "Ponds"
	add_child(ponds)
	ponds.realize(maze, pieces, ground_material, preview)


## The walls, piers and terraces, merged into squares of `CHUNK` metres, one mesh
## of blocks and one of plain boxes in each for every height of stone (the ivy
## curtains of the stone hang from its top, so each height has its own material).
func _walls(body: StaticBody3D, pieces: MazeLayout) -> void:
	# [look, square, section, a sewer's mouth] -> WallMesh (each section's walls their own moss:
	# MazeStyle.wall_moss_height, and their own rounding: wall_edge_rounding).
	var chunks := {}
	var boxes: Array[MazePiece] = pieces.pieces(MazePiece.Kind.WALL) + pieces.pieces(MazePiece.Kind.PIER) + pieces.pieces(MazePiece.Kind.TERRACE)
	for piece in boxes:
		var size := piece.box_size()
		var where := piece.box_transform()
		var look := _look_of(piece)
		var section := clampi(maze.ring_of(maze.cell_at(where.origin)), 1, maxi(maze.rings, 1))
		# (the sewers' modelled mouths in meshes of their own, their concrete laid on as
		# suits a curve: Wall.SHADER's `curved`)
		var key := [look, Vector2i(floori(where.origin.x / CHUNK), floori(where.origin.z / CHUNK)), section, piece.mouth != Vector3.ZERO]
		if not chunks.has(key):
			chunks[key] = WallMesh.new()
		var rounding := edge_rounding(_style_of(section), piece.great, look == LEDGE_LOOK)
		# (an arched span, a concrete bridge: drawn smooth, and bumped into as its deck and
		# a few blocks under it each way)
		if piece.arch > 0.0:
			(chunks[key] as WallMesh).add_arch(where, Vector3.UP * size.y * 0.5, size, piece.arch)
			var along_x := size.x >= size.z
			var long := (size.x if along_x else size.z)
			var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
			var flat := size - axis * long
			_collide(body, where, Vector3.UP * (size.y - piece.arch * 0.5), flat + axis * long + Vector3.UP * (piece.arch - size.y))
			for k in 8:
				var u := (k + 0.5) / 8.0 * 2.0 - 1.0
				var tall := (size.y - piece.arch) * u * u
				if tall < 0.05:
					continue
				_collide(body, where, axis * u * long * 0.5 + Vector3.UP * (size.y - piece.arch - tall * 0.5), flat + axis * long / 8.0 + Vector3.UP * (tall - size.y))
			continue
		# (the platform under a sewer pipe's mouth: the modelled mouth, a bell on a lip,
		# bumped into as a few boxes: SewerMouth)
		if piece.mouth != Vector3.ZERO:
			SewerMouth.add(chunks[key], where, size, piece.mouth)
			for part: Array in SewerMouth.colliders(where, size, piece.mouth):
				_collide(body, part[0], Vector3.ZERO, part[1])
			continue
		# (a wall in its style; piers and terraces always plain)
		var chosen: Wall.Style = piece.style if piece.kind == MazePiece.Kind.WALL else Wall.Style.BASIC
		for part: Array in Wall.style_boxes(chosen, size):
			# (its underside drawn if it stands up off the ground: a ledge, a bracket, a beam,
			# a bridge's deck, seen from under it; without it they were not there from below,
			# and the roots of the vines held under them hung in the air)
			var raised: bool = (where * (part[0] as Vector3)).y - (part[1] as Vector3).y * 0.5 > 0.3
			(chunks[key] as WallMesh).add_box(where, part[0], part[1], rounding, true, true, edge_spacing(piece.great), raised)
			_collide(body, where, part[0], part[1])
	var materials := {}
	for key: Array in chunks:
		var kind := [key[0], key[2], key[3]]
		var style := _style_of(key[2])
		if not materials.has(kind):
			# (laid on in the world's space, so that the pieces meet without seams)
			materials[kind] = Wall.material_for(key[0], true, LEDGE_TINT if key[0] == LEDGE_LOOK else Color.WHITE, true)
			if key[0] == GREAT_LOOK:
				# (the great walls are so big that their concrete is drawn bigger too)
				materials[kind].set_shader_parameter(&"tile_size", Wall.LOOKS[GREAT_LOOK][1] * GREAT_TILE_SCALE)
			moss(materials[kind], style)
			weather(materials[kind], style, key[0] == GREAT_LOOK, key[0] == LEDGE_LOOK)
			materials[kind].set_shader_parameter(&"curved", key[3])
			# (the maze walls' concrete laid on as big as the section says: MazeStyle.wall_texture_scale)
			if style and key[0] != GREAT_LOOK:
				materials[kind].set_shader_parameter(&"tile_size", Wall.LOOKS[key[0]][1] * style.wall_texture_scale)
		var walls := MeshInstance3D.new()
		walls.mesh = (chunks[key] as WallMesh).mesh()
		walls.material_override = materials[kind]
		# (lost in the mist past this; the editor, seen from high over it all, shows all;
		# and the great walls never, the clearing's and those between sections: they tower
		# over the rest and are seen from right across the clearing, the user, 2026-10-19)
		walls.visibility_range_end = 0.0 if Engine.is_editor_hint() or key[0] == GREAT_LOOK else WALL_FAR
		body.add_child(walls)


## Section `section`'s style (counting from 1; null if it has none).
func _style_of(section: int) -> MazeStyle:
	return maze.styles[section - 1] if section >= 1 and section - 1 < maze.styles.size() else null


## How far a wall's edges are worn round, metres, as `style` says
## (MazeStyle.wall_edge_rounding, border_wall_edge_rounding; a ledge half a wall's).
static func edge_rounding(style: MazeStyle, great: bool, ledge := false) -> float:
	if style == null:
		return 0.4 if great else 0.14
	if great:
		return style.border_wall_edge_rounding
	return style.wall_edge_rounding * (0.5 if ledge else 1.0)


## How far apart the vertices along a wall's edges are, metres (so that its
## rounding can wander along it): further on the great walls.
static func edge_spacing(great: bool) -> float:
	return 6.0 if great else 3.0


## Gives a wall material the weathering of its edges and tops `style` says
## (MazeStyle.wall_weathering), and how far round they are.
static func weather(material: ShaderMaterial, style: MazeStyle, great: bool, ledge := false) -> void:
	material.set_shader_parameter(&"edge_size", edge_rounding(style, great, ledge))
	material.set_shader_parameter(&"edge_weathering", style.wall_weathering if style else 0.5)


## Gives a wall material the moss `style` says (MazeStyle.wall_moss_height and
## wall_moss_patches; none without a style).
static func moss(material: ShaderMaterial, style: MazeStyle) -> void:
	material.set_shader_parameter(&"moss_foot", style.wall_moss_height if style else 0.0)
	material.set_shader_parameter(&"moss_patches", style.wall_moss_patches if style else 0.0)


## What the ledges along the walls (and the beams the vines hang from) are made
## of: rougher, darker concrete than the walls, so that from below they stand out
## against the wall behind them.
const LEDGE_LOOK := Wall.Look.ROUGH
const LEDGE_TINT := Color(0.55, 0.52, 0.47)
## How many times bigger the great walls' concrete is drawn than the texture's own size.
const GREAT_TILE_SCALE := 4.0
## Past this, walls are lost in the mist: not drawn.
const WALL_FAR := 550.0
const GREAT_LOOK := Wall.Look.CAST
const MAZE_LOOK := Wall.Look.SLABS


static func _look_of(piece: MazePiece) -> Wall.Look:
	if piece.ledge or (piece.kind == MazePiece.Kind.PIER and piece.position.y > 0.5):
		return LEDGE_LOOK
	return surface_of(piece)


## The concrete a piece is made of (one of Wall's looks): the great walls between
## rings cast concrete, the maze walls precast slabs.
static func surface_of(piece: MazePiece) -> Wall.Look:
	return GREAT_LOOK if piece.great else MAZE_LOOK


## A box to bump into, `size` round `middle` in the space of `where`.
static func _collide(body: StaticBody3D, where: Transform3D, middle: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = where * Transform3D(Basis.IDENTITY, middle)
	body.add_child(collider)


## A wall's stepped footing and the cornice standing out along its top, for a
## wall `size` standing on the origin, long along whichever of x and z it is
## longer in. As [middle, size] boxes.
static func mouldings(size: Vector3) -> Array:
	var wide := Vector3(1.0 if size.x < size.z else 0.0, 0.0, 1.0 if size.z < size.x else 0.0)
	return [
		[Vector3(0.0, FOOT.y * 0.5, 0.0), size * Vector3(1, 0, 1) + wide * FOOT.x * 2.0 + Vector3.UP * FOOT.y],
		[Vector3(0.0, size.y - CORNICE.y * 0.5, 0.0), size * Vector3(1, 0, 1) + wide * CORNICE.x * 2.0 + Vector3.UP * CORNICE.y],
	]


## Five faces of a box (no bottom), facing out.
static func box(tool: SurfaceTool, at: Vector3, size: Vector3, tint := Color.WHITE) -> void:
	var h := size * 0.5
	var faces := [
		# (each face's across x up is its outward way, so that all are wound alike)
		[Vector3.UP, Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3.RIGHT, Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3.LEFT, Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3.BACK, Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3.FORWARD, Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var u: Vector3 = face[1] * h
		var v: Vector3 = face[2] * h
		var centre: Vector3 = at + normal * h
		var a := centre - u - v
		var b := centre + u - v
		var c := centre + u + v
		var d := centre - u + v
		tool.set_normal(normal)
		tool.set_color(tint)
		# (clockwise seen from outside, as Godot faces are)
		for corner: Vector3 in [a, c, b, a, d, c]:
			tool.add_vertex(corner)


## A box of dressed stone, `size` round `at`: a dark core set in, with its four
## sides laid in courses of blocks, each a chamfered slab standing a little proud
## or sunk, in its own tone. Its top is the core's. `seed_value` chooses the blocks.
static func masonry(tool: SurfaceTool, at: Vector3, size: Vector3, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	box(tool, at, size - Vector3(BLOCK_INSET * 2.0, 0.0, BLOCK_INSET * 2.0), Color(0.5, 0.5, 0.5))
	var h := size * 0.5
	var bottom := at.y - h.y
	for face: Array in [[Vector3.RIGHT, Vector3.BACK, h.x, size.z], [Vector3.LEFT, Vector3.FORWARD, h.x, size.z],
			[Vector3.BACK, Vector3.LEFT, h.z, size.x], [Vector3.FORWARD, Vector3.RIGHT, h.z, size.x]]:
		var n: Vector3 = face[0]
		var a: Vector3 = face[1]
		var plane: Vector3 = Vector3(at.x, bottom, at.z) + n * float(face[2])
		var long: float = face[3]
		var v := 0.0
		while v < size.y - 0.3:
			var tall := minf(rng.randf_range(COURSE.x, COURSE.y), size.y - v)
			if size.y - v - tall < 0.9:
				tall = size.y - v
			var u := -long * 0.5
			# (each course starts at its own place, so the joints do not line up)
			var first := rng.randf_range(0.3, 1.0)
			while u < long * 0.5 - 0.3:
				var wide := minf(rng.randf_range(BLOCK.x, BLOCK.y) * (first if u == -long * 0.5 else 1.0), long * 0.5 - u)
				if long * 0.5 - u - wide < 1.0:
					wide = long * 0.5 - u
				var tone := rng.randf_range(0.82, 1.08)
				_block(tool, plane, n, a, u, u + wide, v, v + tall, rng.randf_range(PROUD.x, PROUD.y), Color(tone, tone, tone))
				u += wide
			v += tall


## One block on a face: `plane` the bottom of the face's middle, `n` out of it,
## `a` along it; from `u0` to `u1` along and `v0` to `v1` up, its front `proud`
## out from the face.
static func _block(tool: SurfaceTool, plane: Vector3, n: Vector3, a: Vector3, u0: float, u1: float, v0: float, v1: float, proud: float, tint: Color) -> void:
	var at := func(u: float, v: float, out: float) -> Vector3:
		return plane + a * u + Vector3.UP * v + n * out
	var g := JOINT * 0.5
	var c := minf(CHAMFER, minf(u1 - u0, v1 - v0) * 0.3)
	var back := -BLOCK_INSET
	var b0: Vector3 = at.call(u0 + g, v0 + g, back)
	var b1: Vector3 = at.call(u1 - g, v0 + g, back)
	var b2: Vector3 = at.call(u1 - g, v1 - g, back)
	var b3: Vector3 = at.call(u0 + g, v1 - g, back)
	var f0: Vector3 = at.call(u0 + g + c, v0 + g + c, proud)
	var f1: Vector3 = at.call(u1 - g - c, v0 + g + c, proud)
	var f2: Vector3 = at.call(u1 - g - c, v1 - g - c, proud)
	var f3: Vector3 = at.call(u0 + g + c, v1 - g - c, proud)
	tool.set_color(tint)
	_quad(tool, f0, f1, f2, f3, n)
	for side: Array in [[b0, b1, f1, f0], [b1, b2, f2, f1], [b2, b3, f3, f2], [b3, b0, f0, f3]]:
		var p: Array = side
		# (the chamfer faces out and sideways: its normal is between the two)
		var facing: Vector3 = ((p[0] + p[1]) * 0.5 - (b0 + b2) * 0.5)
		facing = (facing - n * facing.dot(n)).normalized()
		_quad(tool, p[0], p[1], p[2], p[3], (facing + n).normalized())


## Two triangles, wound so that the side `normal` points to is their front.
static func _quad(tool: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, normal: Vector3) -> void:
	tool.set_normal(normal)
	for tri: Array in [[p0, p1, p2], [p0, p2, p3]]:
		var p: Vector3 = tri[0]
		var q: Vector3 = tri[1]
		var r: Vector3 = tri[2]
		# (Godot's front faces are the ones whose (q - p) x (r - p) points away from the viewer)
		if (q - p).cross(r - p).dot(normal) > 0.0:
			var swap := q
			q = r
			r = swap
		tool.add_vertex(p)
		tool.add_vertex(q)
		tool.add_vertex(r)


func _ground() -> void:
	var size := Maze.ring_extent(maze.rings + 1, maze.styles, maze.clearing_style) + 80.0
	if maze.round_rings:
		size = (maze.round_rings.outermost() + 300.0) * 2.0
	var body := StaticBody3D.new()
	body.name = "Ground"
	# (grass grows back along the foot of each wall, where nobody walks)
	var boxes: Array[MazePiece] = layout.pieces(MazePiece.Kind.WALL) + layout.pieces(MazePiece.Kind.PIER) + layout.pieces(MazePiece.Kind.TERRACE)
	ground_material = MazeStone.ground(maze.clearing * Maze.CELL * 0.5, maze.extent() * 0.5, WALL_THICK, boxes)
	var material := ground_material
	# Flat ground everywhere, or with a hole for the clearing where its ground is
	# shaped (it may go down below level, into the marsh).
	var shaped := maze.clearing_style.shaped()
	var hole := maze.clearing * Maze.CELL * 0.5 - 1.0 if shaped else 0.0
	# (cut away over the standing water, whose ground is lower: Ponds; then all
	# of it one mesh)
	var parts := _framed(size * 0.5, hole)
	var wet := Ponds.holes(maze)
	if not wet.is_empty():
		parts = Ponds.cut(parts, wet)
		body.add_child(Ponds.flat(parts, material))
	for part: Rect2 in parts:
		var shape := BoxShape3D.new()
		shape.size = Vector3(part.size.x, 2.0, part.size.y)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = Vector3(part.get_center().x, -1.0, part.get_center().y)
		body.add_child(collider)
		if not wet.is_empty():
			continue
		var plane := PlaneMesh.new()
		plane.size = part.size
		var visual := MeshInstance3D.new()
		visual.mesh = plane
		visual.position = Vector3(part.get_center().x, 0.0, part.get_center().y)
		visual.material_override = material
		# (the ground casts no shadow: there is nothing under it to shade, and with
		# the sun low it shaded itself, in fine stripes over the grass: "lines in the
		# ground")
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(visual)
	# The clearing's hills over it, and a heightmap to walk on them.
	if shaped:
		var field := hills(maze.clearing_style, maze.maze_seed, material)
		body.add_child(field)
		var heights := HeightMapShape3D.new()
		var across := field.get_meta(&"points") as int
		heights.map_width = across
		heights.map_depth = across
		var data := PackedFloat32Array()
		data.resize(across * across)
		var half := (across - 1) * HILL_STEP * 0.5
		for j in across:
			for i in across:
				# (in heightmap units: the shape is scaled up by HILL_STEP; sunk
				# under the marsh, which has its own)
				data[i + j * across] = maze.clearing_style.coarse_height_at(i * HILL_STEP - half, j * HILL_STEP - half, maze.maze_seed) / HILL_STEP
		heights.map_data = data
		var on_hills := CollisionShape3D.new()
		on_hills.shape = heights
		on_hills.scale = Vector3.ONE * HILL_STEP
		body.add_child(on_hills)
	# The desert's dunes outside the square maze, if there are round sections.
	if maze.round_rings:
		var look := maze.round_rings.desert
		material.set_shader_parameter(&"desert_radius", maze.round_rings.inner_radius)
		material.set_shader_parameter(&"quarter_biomes", Vector4(look.biome_of(Vector2i(0, -1)), look.biome_of(Vector2i(1, 0)), look.biome_of(Vector2i(0, 1)), look.biome_of(Vector2i(-1, 0))))
		# (in the game, Outside's sand in each desert quarter; the editor, which
		# cannot run it, shows plain dunes)
		if Engine.is_editor_hint():
			_dunes(body, material)
		else:
			material.set_shader_parameter(&"sand_laid", 1.0)
			_sand_quarters()
		material.set_shader_parameter(&"swamp_level", look.swamp_water_depth)
		# (and the forest, swamp and plains quarters dressed, near the camera)
		if not preview and not Engine.is_editor_hint() and maze.round_rings.wilds:
			wilds = Wilds.new()
			wilds.name = "Wilds"
			add_child(wilds)
			wilds.realize(maze.round_rings.wilds, material)
	add_child(body)


## Sand (SandGround, from GameCommon's godot/sand, after Outside) in each quarter
## of the desert ring that is desert (DesertStyle.Biome), its dunes the ring's own
## (RoundMaze.desert_height): a ground over the quarter, trimmed to its wedge
## between the square maze, the diagonal walls and the first circle.
func _sand_quarters() -> void:
	var plan := maze.round_rings
	var near := plan.square_half
	var far := plan.inner_radius
	for side: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		if plan.desert.biome_of(Vector2i(side)) != DesertStyle.Biome.DESERT:
			continue
		var sand := SandGround.new()
		sand.name = "Sand"
		var middle := side * (near + far) * 0.5
		sand.position = Vector3(middle.x, 0.0, middle.y)
		var deep := (far - near) * 0.5
		var wide := far * sqrt(0.5)
		sand.half = Vector2(wide, deep) if side.x == 0.0 else Vector2(deep, wide)
		# (dunes a hundred metres apart want no finer grid, and fast runners furrows, not boot prints)
		sand.cell = 4.0
		sand.dent_cell = 0.1
		sand.clip = true
		sand.wedge = Vector4(side.angle(), PI * 0.25, near, far)
		sand.wedge_apex = Vector2.ZERO
		sand.height = func(x: float, z: float) -> float: return plan.desert_height(x + middle.x, z + middle.y)
		add_child(sand)


## The marsh in front of the flooded entrance (ClearingStyle.Entrance.MARSH), if
## there is one (Marsh: its finer ground, its water, sedges, reeds and the rest).
## (Named for the pond that was there before it.)
func _pond() -> void:
	if maze.clearing_style.entrance(ClearingStyle.Entrance.MARSH).is_empty():
		return
	var marsh := Marsh.new()
	marsh.name = "Marsh"
	add_child(marsh)
	marsh.realize(maze)


## A square `half` metres each way from the middle, as rects (x, z): the whole of
## it, or (with `hole`) the four round a square hole `hole` metres each way.
static func _framed(half: float, hole: float) -> Array[Rect2]:
	if hole <= 0.0:
		return [Rect2(-half, -half, half * 2.0, half * 2.0)]
	return [Rect2(-half, -half, half * 2.0, half - hole), Rect2(-half, hole, half * 2.0, half - hole),
		Rect2(-half, -hole, half - hole, hole * 2.0), Rect2(hole, -hole, half - hole, hole * 2.0)]


## Metres between the points of the clearing's ground over the hills.
const HILL_STEP := 3.0
## How far the drawn hills stand over the ground walked on (so that where they
## are level they are not drawn into the flat ground under them).
const HILL_LIFT := 0.03


## The clearing's ground, over its hills (ClearingStyle.height_at), drawn in
## `material`: a grid of points HILL_STEP apart (how many along a side is its
## meta "points"), level with the flat ground at its edges.
static func hills(look: ClearingStyle, seed_value: int, material: Material) -> MeshInstance3D:
	var across := ceili(Maze.CLEARING * Maze.CELL / HILL_STEP) + 1
	var half := (across - 1) * HILL_STEP * 0.5
	var heights := PackedFloat32Array()
	heights.resize(across * across)
	for j in across:
		for i in across:
			heights[i + j * across] = look.coarse_height_at(i * HILL_STEP - half, j * HILL_STEP - half, seed_value)
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	points.resize(across * across)
	normals.resize(across * across)
	for j in across:
		for i in across:
			var at := i + j * across
			points[at] = Vector3(i * HILL_STEP - half, heights[at] + HILL_LIFT, j * HILL_STEP - half)
			var dx := heights[mini(i + 1, across - 1) + j * across] - heights[maxi(i - 1, 0) + j * across]
			var dz := heights[i + mini(j + 1, across - 1) * across] - heights[i + maxi(j - 1, 0) * across]
			normals[at] = Vector3(-dx, 2.0 * HILL_STEP, -dz).normalized()
	var order := PackedInt32Array()
	for j in across - 1:
		for i in across - 1:
			var a := i + j * across
			order.append_array([a, a + 1, a + across, a + 1, a + across + 1, a + across])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = order
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shown := MeshInstance3D.new()
	shown.name = "Hills"
	shown.mesh = mesh
	shown.material_override = material
	# (no shadow of its own, as the flat ground: it striped itself with the sun low)
	shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shown.set_meta(&"points", across)
	return shown


## The pines, each where a tree piece stands, as big as its scale: a MultiMesh for
## each of a few kinds of pine in each square of `TREE_SQUARE` metres (so squares
## off the screen are not drawn, nor drawn into the shadows), the whole tree near
## and a plainer one without a shadow past `TREE_NEAR` metres.
const TREE_SQUARE := 48.0
const TREE_NEAR := 70.0


func _trees(pieces: MazeLayout) -> void:
	var pine := PineTree.new()
	pine.height = 13.0
	pine.seed = maze.maze_seed % 1000
	var plain := pine.simple()
	var kinds := 3
	# [square, kind] -> transforms
	var groups := {}
	for piece in pieces.pieces(MazePiece.Kind.TREE):
		var k := absi(hash(piece.position.snappedf(0.1))) % kinds
		var key := [Vector2i(floori(piece.position.x / TREE_SQUARE), floori(piece.position.z / TREE_SQUARE)), k]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(piece.transform)
	for key: Array in groups:
		var placed: Array = groups[key]
		for detailed: bool in [true, false]:
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = pine.mesh(key[1]) if detailed else plain.mesh(key[1])
			multi.instance_count = placed.size()
			for i in placed.size():
				multi.set_instance_transform(i, placed[i])
			var trees := MultiMeshInstance3D.new()
			trees.multimesh = multi
			trees.material_override = pine._material()
			trees.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			if detailed:
				trees.visibility_range_end = TREE_NEAR
				trees.visibility_range_end_margin = 10.0
			else:
				trees.visibility_range_begin = TREE_NEAR
				trees.visibility_range_begin_margin = 10.0
				trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(trees)


## The pale light that stands up past the exit: a tall faint beam and a lamp at its foot.
static func beacon_light() -> Node3D:
	var light := Node3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = 0.6
	beam.bottom_radius = 1.2
	beam.height = 110.0
	beam.cap_top = false
	beam.cap_bottom = false
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(0.55, 0.75, 0.9, 0.12)
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.disable_fog = true
	var visual := MeshInstance3D.new()
	visual.mesh = beam
	visual.material_override = glow
	visual.position.y = 55.0
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.add_child(visual)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.6, 0.8, 1.0)
	lamp.omni_range = 12.0
	lamp.light_energy = 1.5
	lamp.position.y = 1.5
	light.add_child(lamp)
	return light


## Real grass over the clearing (GameCommon's Grass), up to the foot of its wall
## and round the terraces, but not under them. The ground shader's grass goes on
## under it and beyond, so its edge is not seen.
func _grass() -> void:
	var gate: Array = maze.gates[0][0]
	var half := maze.clearing * Maze.CELL * 0.5 - maze.wall_thick(gate[0], gate[1]) * 0.5 - FOOT.x - 0.2
	var field := Rect2(-half, -half, half * 2.0, half * 2.0)
	# (only the terraces in the field: it is asked of every tuft)
	var footprints: Array[Rect2] = []
	for footprint: Rect2 in features.footprints:
		if footprint.grow(0.25).intersects(field):
			footprints.append(footprint.grow(0.25))
	var look := maze.clearing_style
	# (giving way to the marsh's own sedges, Marsh)
	var dry := func(p: Vector2) -> bool:
		if look.marsh_keeps_grass_out(p, maze.maze_seed):
			return false
		for footprint: Rect2 in footprints:
			if footprint.has_point(p):
				return false
		return true
	Grass.field(self, field, 1.0, {
		"mask": func(p: Vector2) -> float: return 1.0 - look.tall_grass_at(p) if dry.call(p) else 0.0,
		"height": func(p: Vector2) -> float: return maze.ground_height(Vector3(p.x, 0.0, p.y)) + HILL_LIFT,
		"ground": Color(0.13, 0.2, 0.09),
		# (knee high, dark and damp: the clearing is as grey as the rest)
		"blade_height": 0.4,
		"body": Color(0.14, 0.22, 0.09),
		"tip": Color(0.3, 0.37, 0.17),
		"dry": Color(0.36, 0.35, 0.2),
		"translucency": 0.08,
		"flowers": 0.03,
		"seed": maze.maze_seed % 1000,
	})
	# Grass up to his chest round the tall grass entrance, where the knee high
	# grass gives way to it.
	var tall := look.entrance(ClearingStyle.Entrance.TALL_GRASS)
	if tall.is_empty():
		return
	var around := look.tall_grass_rect().intersection(field)
	Grass.field(self, around, 0.8, {
		"mask": func(p: Vector2) -> float: return look.tall_grass_at(p) if dry.call(p) else 0.0,
		"height": func(p: Vector2) -> float: return maze.ground_height(Vector3(p.x, 0.0, p.y)) + HILL_LIFT,
		"ground": Color(0.13, 0.2, 0.09),
		"blade_height": look.tall_grass_height,
		"blade_width": 0.05,
		"lean": 0.25,
		"body": Color(0.16, 0.22, 0.1),
		"tip": Color(0.38, 0.4, 0.22),
		"dry": Color(0.42, 0.4, 0.24),
		"dryness": 0.55,
		"translucency": 0.08,
		"flowers": 0.0,
		"seed": maze.maze_seed % 1000 + 1,
	})


## The low plants. Along the foot of the walls in the rings, as thick as each
## ring's style says (MazeStyle.plant_density): ferns a little out from the wall,
## moss right at its foot, tufts of grass between. In the clearing, as its style
## says: ferns and moss round the foot of the pines (so thickest in the woods)
## and bushes over the field, most of them near the trees. All from the seed.
func _undergrowth(pieces: MazeLayout) -> void:
	undergrowth = Undergrowth.new()
	undergrowth.name = "Undergrowth"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("undergrowth/%d" % maze.maze_seed)
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		var ring := maze.ring_of(cell)
		if ring < 1 or ring > maze.rings or maze.solid.has(cell) or maze.entrances.has(cell):
			continue
		var thick: float = maze.styles[ring - 1].amount(&"plant_density")
		var grassy: float = maze.styles[ring - 1].amount(&"wall_grass_share")
		if thick <= 0.0 and grassy <= 0.0:
			continue
		for step: Vector2i in Maze.STEPS:
			if not maze.blocked(cell, step):
				continue
			var s := Vector3(step.x, 0.0, step.y)
			var side := Vector3(-s.z, 0.0, s.x)
			var face := maze.world(cell) + s * (Maze.CELL * 0.5 - maze.wall_thick(cell, step) * 0.5)
			# (in front of the step of ledge along its foot, if it has one)
			var style: MazeStyle = maze.styles[ring - 1]
			if maze.has_ledge(cell, step):
				face -= s * style.level_depth(0)
			# Short grass along the foot of some faces: a run of close clumps a few metres long.
			if rng.randf() < grassy:
				var from := rng.randf_range(-0.5, 0.2) * Maze.CELL
				var to := minf(from + rng.randf_range(3.0, 10.0), Maze.CELL * 0.5)
				var run := from
				while run < to:
					var at := face - s * rng.randf_range(0.15, 0.7) + side * run
					if not _on_terrace(at):
						undergrowth.add(Undergrowth.Kind.GRASS, _plant(at, rng, Undergrowth.Kind.GRASS))
					run += rng.randf_range(0.55, 0.85)
			var along := -Maze.CELL * 0.5
			while along < Maze.CELL * 0.5:
				along += rng.randf_range(0.7, 1.8)
				if rng.randf() >= thick:
					continue
				var pick := rng.randf()
				var kind := Undergrowth.Kind.MOSS if pick < 0.3 else (Undergrowth.Kind.FERN if pick < 0.65 else Undergrowth.Kind.TUFT)
				var out := rng.randf_range(0.2, 0.6) if kind == Undergrowth.Kind.MOSS else rng.randf_range(0.5, 1.8)
				var at := face - s * out + side * along
				if _on_terrace(at):
					continue
				undergrowth.add(kind, _plant(at, rng, kind))
	var look := maze.clearing_style
	var half := maze.clearing * Maze.CELL * 0.5 - 8.0
	var near_trees: Array[Vector3] = []
	for piece in pieces.pieces(MazePiece.Kind.TREE):
		var foot := piece.position
		if maxf(absf(foot.x), absf(foot.z)) > half:
			continue
		near_trees.append(foot)
		for f in int(look.ferns_per_tree) + (1 if rng.randf() < fmod(look.ferns_per_tree, 1.0) else 0):
			var round_about := rng.randf() * TAU
			var at := foot + Vector3(cos(round_about), 0.0, sin(round_about)) * rng.randf_range(1.2, 4.5)
			undergrowth.add(Undergrowth.Kind.FERN, _plant(at, rng, Undergrowth.Kind.FERN))
		if rng.randf() < look.moss_per_tree_chance:
			undergrowth.add(Undergrowth.Kind.MOSS, _plant(foot + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)), rng, Undergrowth.Kind.MOSS))
	for b in look.bush_count:
		var at: Vector3
		if not near_trees.is_empty() and rng.randf() < 0.75:
			var round_about := rng.randf() * TAU
			at = near_trees[rng.randi() % near_trees.size()] + Vector3(cos(round_about), 0.0, sin(round_about)) * rng.randf_range(2.5, 7.0)
		else:
			at = Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
		if Vector2(at.x, at.z).length() < look.treeless_radius or maxf(absf(at.x), absf(at.z)) > half or look.kept_clear(Vector2(at.x, at.z)):
			continue
		undergrowth.add(Undergrowth.Kind.BUSH, _plant(at, rng, Undergrowth.Kind.BUSH))
	undergrowth.build()
	add_child(undergrowth)


## Where a plant of `kind` stands at `at` (on the ground there), turned and sized at random.
func _plant(at: Vector3, rng: RandomNumberGenerator, kind: Undergrowth.Kind) -> Transform3D:
	var sizes := {Undergrowth.Kind.FERN: Vector2(1.1, 2.0), Undergrowth.Kind.BUSH: Vector2(0.9, 1.8), Undergrowth.Kind.MOSS: Vector2(1.0, 2.4), Undergrowth.Kind.TUFT: Vector2(1.0, 1.7), Undergrowth.Kind.GRASS: Vector2(0.8, 1.3)}
	var range_of: Vector2 = sizes[kind]
	var big := rng.randf_range(range_of.x, range_of.y)
	at.y = maze.ground_height(at)
	return Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * big), at)


func _on_terrace(at: Vector3) -> bool:
	# (the footprints by the square of FOOTPRINT_SQUARE metres they are in, made
	# once: there are thousands, and this is asked of every plant)
	if _footprints_by_square.is_empty():
		for footprint: Rect2 in features.footprints:
			var grown := footprint.grow(0.3)
			for sx in range(floori(grown.position.x / FOOTPRINT_SQUARE), floori(grown.end.x / FOOTPRINT_SQUARE) + 1):
				for sz in range(floori(grown.position.y / FOOTPRINT_SQUARE), floori(grown.end.y / FOOTPRINT_SQUARE) + 1):
					var key := Vector2i(sx, sz)
					if not _footprints_by_square.has(key):
						_footprints_by_square[key] = []
					(_footprints_by_square[key] as Array).append(grown)
	var flat := Vector2(at.x, at.z)
	for footprint: Rect2 in _footprints_by_square.get(Vector2i((flat / FOOTPRINT_SQUARE).floor()), []):
		if footprint.has_point(flat):
			return true
	return false


const FOOTPRINT_SQUARE := 20.0
var _footprints_by_square := {}


## Metres between the points of the desert's dunes, and how many points along
## each side of a stretch of them (each its own mesh and shape).
const DUNE_STEP := 8.0
const DUNE_STRETCH := 48


## The desert's dunes (RoundMaze.desert_height), over the flat ground under them:
## a grid of points DUNE_STEP apart, in stretches, each a mesh and a shape to walk
## on, only where the sand rises (the flat ground is the rest).
func _dunes(body: StaticBody3D, material: Material) -> void:
	var plan := maze.round_rings
	var reach := plan.inner_radius
	var across := ceili(reach * 2.0 / DUNE_STEP) + 1
	var start := -reach
	var heights := PackedFloat32Array()
	heights.resize(across * across)
	for j in across:
		for i in across:
			heights[i + j * across] = plan.desert_height(start + i * DUNE_STEP, start + j * DUNE_STEP)
	var height_of := func(i: int, j: int) -> float:
		return heights[clampi(i, 0, across - 1) + clampi(j, 0, across - 1) * across]
	for sj in range(0, across - 1, DUNE_STRETCH):
		for si in range(0, across - 1, DUNE_STRETCH):
			var points := PackedVector3Array()
			var normals := PackedVector3Array()
			for j in range(sj, mini(sj + DUNE_STRETCH, across - 1)):
				for i in range(si, mini(si + DUNE_STRETCH, across - 1)):
					var corners := [height_of.call(i, j), height_of.call(i + 1, j), height_of.call(i + 1, j + 1), height_of.call(i, j + 1)]
					if corners.max() <= 0.0:
						continue
					var quad: Array[Vector3] = []
					var faces: Array[Vector3] = []
					for c: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
						quad.append(Vector3(start + c.x * DUNE_STEP, height_of.call(c.x, c.y) + HILL_LIFT, start + c.y * DUNE_STEP))
						var dx: float = height_of.call(c.x + 1, c.y) - height_of.call(c.x - 1, c.y)
						var dz: float = height_of.call(c.x, c.y + 1) - height_of.call(c.x, c.y - 1)
						faces.append(Vector3(-dx, 2.0 * DUNE_STEP, -dz).normalized())
					# (wound so that the top is the front)
					for k: int in [0, 1, 2, 0, 2, 3]:
						points.append(quad[k])
						normals.append(faces[k])
			if points.is_empty():
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = points
			arrays[Mesh.ARRAY_NORMAL] = normals
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var shown := MeshInstance3D.new()
			shown.name = "Dunes"
			shown.mesh = mesh
			shown.material_override = material
			shown.visibility_range_end = RoundBuilder.FAR
			body.add_child(shown)
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(points)
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
