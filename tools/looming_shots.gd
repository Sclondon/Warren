extends SceneTree
## Pictures of the far walls in the mist (the user, 2026-10-19: "The Maze walls kind of just becom ugly featureless
## gray blobs in the distance"; and 2026-10-19, "specifically test in the swamp, plains and desert"): low in the clearing looking across at its wall, from the clearing's middle looking
## up at it, down the longest straight hall of the first ring, from a ledge 30 m up in that hall, and from high
## over the maze walls above that hall; in each quarter of the desert ring, back at the great wall and on out across it; overcast, sunny, in rain, at dusk and at night. Then, with `cost`, what the
## far views cost the GPU (the least of 90 frames, overcast). Only some: `overcast`, `sunny`, `rain`, `dusk`, `night`.
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/looming_shots.gd -- <folder> [kinds...] [cost] [plain]
## (`plain`: the walls drawn with the plain Wall shader and the World's own mist, as before 2026-10-19)

var main: Node
var world
var camera: Camera3D
var weather: Weather


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://looming_shots"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	# (the same maze every run, as fps_probe has it)
	seed(1)
	main.start_solo()
	for i in 30:
		await physics_frame
	world = main.world
	world.player.visible = false
	camera = Camera3D.new()
	camera.fov = 65.0
	camera.far = 4000.0
	world.add_child(camera)
	camera.make_current()
	weather = world.weather
	# (`plain`: the walls as they were before they drew their own mist, to compare)
	if args.has("plain"):
		for mesh: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
			var material := mesh.material_override as ShaderMaterial
			if material and material.shader == Wall.looming_shader():
				material.shader = Wall.shader()
	var views := _views()
	var all := ["overcast", "sunny", "rain", "dusk", "night"]
	var kinds := []
	for a: String in args.slice(1):
		if a in all:
			kinds.append(a)
	if kinds.is_empty() and not args.has("cost"):
		kinds = all
	for kind: String in kinds:
		_weather(kind)
		for view: Array in views:
			camera.position = view[1]
			camera.look_at(view[2])
			await _shot("%s/%s_%s.png" % [folder, kind, view[0]])
	if args.has("cost"):
		await _costs(views)
	quit()


## [name, from, looking at] for each view.
func _views() -> Array:
	var maze: Maze = world.maze
	var spot: Transform3D = world.gate_spot(maxi(maze.clearing_style.entrances.find(ClearingStyle.Entrance.CLEAR), 0))
	var out := spot.basis.z
	# (the longest clear sight down the middle of a hall of the first ring, 4 to 20 m wide, at head height)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var best := [Vector3.ZERO, Vector3.FORWARD, 0.0, 0.0]
	for x in maze.size:
		for y in maze.size:
			var cell := Vector2i(x, y)
			if maze.ring_of(cell) != 1 or maze.in_room(cell) or maze.solid.has(cell):
				continue
			var from := maze.world(cell) + Vector3.UP * (maze.ground_height(maze.world(cell)) + 1.8)
			for step: Vector2i in Maze.STEPS:
				var way := Vector3(step.x, 0.0, step.y)
				var clear := _clear(space, from, way, 1500.0)
				if clear <= best[2] or maze.ring_of(maze.cell_at(from + way * clear * 0.5)) == 0:
					continue
				var side := Vector3(-way.z, 0.0, way.x)
				var left := _clear(space, from, side, 30.0)
				var right := _clear(space, from, -side, 30.0)
				var middle := from + side * (left - right) * 0.5
				if left + right < 4.0 or left + right > 20.0:
					continue
				clear = _clear(space, middle, way, 1500.0)
				if clear > best[2]:
					best = [middle, way, clear, left + right]
	var hall: Vector3 = best[0]
	var along: Vector3 = best[1]
	print("hall at %s, %.0f m clear, %.1f m wide" % [hall, best[2], best[3]])
	var maze_top := maze.maze_wall_height(1)
	var views := [
		["across", spot.origin - out * 40.0 + Vector3.UP * 5.0, -spot.origin + Vector3.UP * 40.0],
		["clearing", Vector3(0.0, 1.7, 0.0), spot.origin + Vector3.UP * 60.0],
		["hall", hall, hall + along * 200.0 + Vector3.UP * 12.0],
		["ledge", hall + Vector3.UP * 30.0, hall + along * 200.0 + Vector3.UP * 30.0],
		["over", hall + Vector3.UP * (maze_top + 25.0), hall + along * 400.0 + Vector3.UP * (maze_top * 0.4)],
	]
	# Each quarter of the desert ring (named by its biome: desert, forest, swamp,
	# plains), from some way out into it: back at the square maze's great wall
	# looming over it, and on out across it (the dunes, the plains, the marsh).
	var outer: RoundMaze = maze.round_rings
	if outer and maze.desert_style:
		for q in outer.doors.size():
			var door := Vector3(outer.doors[q].x, 0.0, outer.doors[q].y)
			var way := Vector3(outer.ways_in[q].x, 0.0, outer.ways_in[q].y)
			var at := door + way * 260.0
			at.y = maze.ground_height(at) + 2.0
			var biome := String(DesertStyle.Biome.keys()[maze.desert_style.biome_at(at.x, at.z)]).to_lower()
			views.append(["%s_back" % biome, at, door + Vector3.UP * 70.0])
			views.append(["%s_out" % biome, at, at + way * 600.0 + Vector3.UP * 25.0])
	return views


func _weather(kind: String) -> void:
	var weather_kind := Weather.Kind.OVERCAST
	var hour := 12.0
	match kind:
		"sunny":
			weather_kind = Weather.Kind.SUNNY
		"rain":
			weather_kind = Weather.Kind.RAIN
		"dusk":
			hour = 18.7
		"night":
			hour = 22.5
	weather.forced = weather_kind
	var look: Array = Weather.LOOKS[weather_kind]
	weather.clouds = look[0]
	weather.rain = look[1]
	weather.wind = look[2]
	weather.sunshine = 1.0 if weather_kind == Weather.Kind.SUNNY else 0.0
	weather.forced_ground_fog = 0
	weather.ground_fog = 0.0
	world.day.set_hour(hour)


func _shot(path: String, frames := 40) -> void:
	if weather.rain > 0.02:
		await create_timer(1.4).timeout
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _costs(views: Array) -> void:
	_weather("overcast")
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	for view: Array in views:
		camera.position = view[1]
		camera.look_at(view[2])
		await create_timer(1.5).timeout
		var gpu := INF
		for i in 90:
			await process_frame
			gpu = minf(gpu, RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		print("cost %-9s gpu %.2f ms  draws %d" % [view[0], gpu, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


func _clear(space: PhysicsDirectSpaceState3D, from: Vector3, way: Vector3, reach: float) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + way * reach, 0xFFFFFFFF, [world.player.get_rid()]))
	return from.distance_to(hit["position"]) if hit else reach
