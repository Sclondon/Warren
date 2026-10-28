extends SceneTree
## Runs a feral dog (creatures/dog) straight ahead at each of the given speeds
## and writes where its joints are every frame, as JSON, to compare its gaits
## with a real dog's (C:\Projects\reference\canine-motion: tools there read it
## as they read the mocap). Speeds are the model's own (m/s at scale 1).
##
##     godot --headless --path . --fixed-fps 60 -s res://tools/dog_gait_dump.gd -- <file.json> [speed ...] [--wolf]

const BONES: Array[StringName] = [&"pelvis", &"body", &"chest", &"neck", &"head", &"tail_1",
		&"upper_fl", &"paw_fl", &"upper_fr", &"paw_fr", &"upper_rl", &"paw_rl", &"upper_rr", &"paw_rr"]
const SETTLE := 2.0
const RECORD := 4.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var file := args[0] if args.size() > 0 else "user://dog_gait.json"
	var speeds: Array[float] = []
	for arg in args.slice(1):
		if arg.is_valid_float():
			speeds.append(float(arg))
	if speeds.is_empty():
		speeds = [1.6, 3.6]
	var runs := []
	for speed in speeds:
		runs.append(await _run(speed, args.has("--wolf")))
	var out := FileAccess.open(file, FileAccess.WRITE)
	out.store_string(JSON.stringify(runs))
	print("saved ", file)
	quit()


func _run(speed: float, wolf: bool) -> Dictionary:
	# (the wolf by its path: a game may have the dog without it)
	var dog: Dog = load("res://creatures/wolf/wolf.gd").new() if wolf else Dog.new()
	dog.measure_velocity = false
	if "sound" in dog:
		dog.set("sound", false)
	root.add_child(dog)
	await process_frame
	var skeleton: Skeleton3D = dog.find_children("*", "Skeleton3D", true, false)[0]
	var frames := []
	var time := 0.0
	while time < SETTLE + RECORD:
		var delta := 1.0 / 60.0
		dog.velocity = Vector3(0.0, 0.0, speed)
		dog.position += dog.velocity * delta
		await process_frame
		time += delta
		if time < SETTLE:
			continue
		var frame := {}
		for bone in BONES:
			var at := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
			frame[bone] = [at.x, at.y, at.z]
		frames.append(frame)
	dog.queue_free()
	await process_frame
	return {"speed": speed, "dt": 1.0 / 60.0, "frames": frames}
