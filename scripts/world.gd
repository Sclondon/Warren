class_name World
extends Node3D
## One maze and everyone in it: the sky and light, the maze (MazeBuilder), this
## player (Outside's boy, scripts/player.gd) with his camera and touch controls,
## and a RemotePlayer for each of the others.
##
## Online, every game sends where its own player is a dozen times a second.
## A guest can only talk to the host, so the host passes each guest's news on
## to everyone (packets carry the seat they are about, not only who sent them).
## Nothing else needs sending to set up a maze: every copy builds the same one
## from the room's code and the round (Maze.seed_for).

signal escaped(slot: int, seconds: float)
## This player was caught, and is back in the clearing.
signal caught(slot: int)

const Flags := preload("res://scripts/flags.gd")
const K_STATE := 83  # S
const SEND_EVERY := 1.0 / 12.0
## How many rings a generated maze has round the clearing, the desert counting as one
## (the flag rings=<n> for another number).
const RINGS := 7
## The host's news of what hunts the maze: MazeEnemies.pack(), then the Griever's state.
const K_ENEMIES := 69  # E
const ENEMIES_EVERY := 0.1
## The host's news of the runners: MazeRunners.pack(), as often.
const K_RUNNERS := 82  # R

## This player's seat (0 when playing alone).
var slot := 0
var online := false
var maze: Maze
var player: Player
var camera: FollowCamera
var touch: TouchControls
## slot -> RemotePlayer
var remotes := {}
## Seconds since the round began.
var clock := 0.0
## Seats that have got out, and how long each took.
var out := {}

## What hunts the maze (see _enemies).
var enemies: MazeEnemies
## The animals that hunt nobody: herds of deer and elk in the clearing and the halls (see Wildlife).
var wildlife: Wildlife
var griever: Griever
## The others in the maze (see _runners).
var runners: MazeRunners
## Tame chickens in the clearing (and the maze), hunting nobody (the other peaceful animals are in `wildlife`).
var tame_chickens: Array[TameChickens] = []
## What lies about to be found, the camps, and this player's inventory (Loot).
var loot: Loot
## Moths, flies and dragonflies (Insects), hunting nobody.
var insects: Insects
## The birds that hunt nobody: blue jays and crows in the clearing's pines, ravens on the walls (see Birds).
var birds: Birds
## God mode and the rest (DevTools), when it is on for this run.
var dev: DevTools
## The hour, the light with it, and the doors of the clearing (put once the walls stand).
var day: DayCycle
var gates: ClearingGates
var weather: Weather
var ecology: Ecology
## Keeps the maze about the players inhabited, in waves (where the hunters are run).
var director: MazeDirector
## Everyone starts in front of a gate instead of in the middle (with dev tools on,
## unless the flag `start=middle` is given).
var start_at_gate := false
## How many times as many of what hunts as the styles say (the maze editor's
## MazeLayout.monster_multiplier; the flag `monsters=<x>` overrides it).
var monster_multiplier := MazeLayout.MONSTER_MULTIPLIER
## Only the clearing, for testing in (set before `setup`, or the flag `clearing`, or
## `rings=0`): no maze round it past its wall, its gates kept shut, nothing that
## hunts and no runners; its own wildlife, loot and the rest as ever (Maze.clearing_only).
var clearing_only := false

var _send_in := 0.0
var _enemies_in := 0.0


## For the loading screen (Main): with `stepwise` on, `setup` stops for a frame
## between its stages and says which comes next (`building`), so that the screen
## is not frozen while the round is made. Off (tests and tools), it is all done at
## once and `setup` has finished when it returns.
signal building(what: String)
var stepwise := false


func _breathe(what: String) -> void:
	building.emit(what)
	await get_tree().process_frame
	await get_tree().process_frame


## Builds the maze for `seed_value` and puts everyone in the clearing.
## `players` is [{slot, look}] for everyone, this player included.
## `layout_path`, if given, is a maze laid out in the editor (see Mazes) to play
## instead of generating one.
func setup(seed_value: int, my_slot: int, players: Array, is_online: bool, layout_path := "") -> void:
	slot = my_slot
	online = is_online
	if Flags.value("clearing") != "" or Flags.value("rings") == "0":
		clearing_only = true
	_lap("")
	_sky()
	var builder := MazeBuilder.new()
	builder.name = "Maze"
	builder.stepwise = stepwise
	builder.building.connect(func(what: String) -> void: building.emit(what))
	add_child(builder)
	var laid_out: MazeLayout = null
	if layout_path != "" and not clearing_only:
		var scene := load(layout_path) as PackedScene
		laid_out = scene.instantiate() as MazeLayout if scene else null
	if laid_out:
		laid_out.name = "Layout"
		builder.add_child(laid_out)
		monster_multiplier = laid_out.monster_multiplier
		await builder.realize(laid_out)
		maze = builder.maze
	else:
		# (by the rules set in the maze editor: Mazes.rules)
		var rules := Mazes.rules()
		maze = Maze.generate(seed_value, 0 if clearing_only else int(Flags.value("rings", str(RINGS))), rules[0], rules[1], rules[2])
		await builder.build(maze)
	_lap("the maze (MazeBuilder)")
	start_at_gate = DevTools.enabled() and Flags.value("start") != "middle"
	if stepwise:
		await _breathe("Day, weather and the gates")
	# Day and night, and the clearing's gates shut through the night.
	day = DayCycle.put(self)
	day.dawn.connect(_shut_gates.bind(false))
	day.sunset.connect(_shut_gates.bind(true))
	weather = Weather.put(self, seed_value, day, builder.ground_material)
	# (footprints in the mud of the maze floor, splashes in its puddles)
	if not clearing_only:
		MudSteps.put(self, maze, builder.ground_material)
	_put_gates()
	_lap("day, weather, gates")

	if stepwise:
		await _breathe("Waking everyone in the clearing")
	for entry: Dictionary in players:
		var seat := int(entry["slot"])
		var look: Dictionary = Looks.decode(str(entry.get("look", "")), seat)
		if seat == slot:
			player = load("res://player.tscn").instantiate()
			player.name = "Player"
			player.add_to_group(&"bridge_weights")
			# (the hunters' bodies stop him, as the walls do: layer 4, and theirs that another machine runs)
			player.collision_mask |= 4 | MazeEnemy.PUPPET_LAYER
			Grass.push(player)
			add_child(player)
			player.global_position = spawn(seat)
			# (the grass round him there now; the rest as the camera comes near it)
			for field: Grass in get_tree().get_nodes_in_group(Grass.FIELDS):
				field.fill_near(player.global_position, 25.0)
			player.rotation.y = spawn_yaw(seat)
			Looks.apply(player.get_node("Rig") as CharacterRig, look)
			# (sprinting is a button of its own here, and an all-out run after The Maze Runner)
			player.auto_sprint = false
			player.sprint_speed = 6.3
			(player.get_node("Rig") as CharacterRig).cap_hand = false
		else:
			var other := RemotePlayer.new()
			other.name = "Remote%d" % seat
			other.slot = seat
			other.add_to_group(&"bridge_weights")
			Grass.push(other)
			add_child(other)
			other.place(spawn(seat), spawn_yaw(seat))
			Looks.apply(other.rig, look)
			other.rig.cap_hand = false
			remotes[seat] = other

	camera = FollowCamera.new()
	camera.target = player
	camera.mode = FollowCamera.Mode.ORBIT
	camera.indoors = true
	camera.distance = 5.0
	# (low, and looking a little above him, so that the walls tower)
	camera.look_height = 1.8
	camera.orbit_fov = 62.0
	camera._pitch = 0.16
	add_child(camera)
	camera.make_current()
	camera.snap()
	_lap("the players and the camera")

	var hud := CanvasLayer.new()
	hud.layer = 0
	add_child(hud)
	touch = TouchControls.new()
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(touch)
	# (the hand button cuts a strung vine as well, as the act key does: see try_cut)
	touch.act_pressed.connect(func() -> void: try_cut())

	if stepwise:
		await _breathe("Letting loose what hunts the maze")
	_enemies(seed_value)
	_lap("hunters and runners")
	if stepwise:
		await _breathe("The animals, the birds and what lies about")
	wildlife = Wildlife.new()
	wildlife.name = "Wildlife"
	add_child(wildlife)
	wildlife.populate(maze, hash("wildlife/%d" % seed_value))
	_lap("wildlife")
	tame_chickens = TameChickens.populate(self, maze, hash("chickens/%d" % seed_value))
	_lap("tame chickens")
	# What lies about to be found, and the camps (Loot), with the inventory on the HUD.
	loot = Loot.put(self, seed_value, hud)
	_lap("loot")
	insects = Insects.new()
	insects.name = "Insects"
	add_child(insects)
	insects.populate(maze, hash("insects/%d" % seed_value), self)
	_lap("insects")
	# The hunters' own lives: hunger, the hunted and the hunters, the dead coming back
	# (run where the hunters are: alone, or the host)
	if not (online and not Net.is_host):
		ecology = Ecology.put(self, seed_value, insects)
	_lap("ecology")
	birds = Birds.put(self, maze, hash("birds/%d" % seed_value))
	_lap("birds")
	if DevTools.enabled():
		dev = DevTools.new(self)
		hud.add_child(dev)
	_lap("dev tools")

	if online:
		Net.packet.connect(_on_packet)
		Net.left.connect(_on_left)


## What hunts the maze: as many of each kind as the first ring's style says
## (MazeStyle, "What hunts it": Apophis, packs of mummies, ghouls, centipedes,
## spiders and the rest, put in by MazeEnemies) and a Griever, all placed from
## the seed, so every copy has the same ones in the same places.
## Alone, or as the host, they are run here; a guest's are puppets that follow the
## host's news (K_ENEMIES).
func _enemies(seed_value: int) -> void:
	player.add_to_group(&"maze_players")
	for seat: int in remotes:
		remotes[seat].add_to_group(&"maze_players")
	enemies = MazeEnemies.new()
	enemies.name = "Enemies"
	add_child(enemies)
	var style: MazeStyle = maze.styles[0].crowded(float(Flags.value("monsters", str(monster_multiplier))))
	enemies.populate(maze, hash("enemies/%d" % seed_value), style.mummy_packs, style.snakes)
	enemies.add_hunters(style, hash("hunters/%d" % seed_value))
	# (and the tame coyotes of the clearing, run and sent with them)
	enemies.add_wildlife(maze.clearing_style, hash("coyotes/%d" % seed_value))
	griever = Griever.new()
	griever.name = "Griever"
	add_child(griever)
	# (in the dead end furthest round the walls from the snake and the mummies)
	var nav := MazeNav.new(maze)
	var taken: Array[Vector2i] = []
	for enemy: MazeEnemy in enemies.enemies:
		taken.append(maze.cell_at(enemy.global_position))
	var lair := maze.exit
	var best := -1
	for cell: Vector2i in nav.lairs(4):
		var apart := 1000
		for other: Vector2i in taken:
			apart = mini(apart, absi(cell.x - other.x) + absi(cell.y - other.y))
		if nav.dead_end(cell) and apart > best:
			best = apart
			lair = cell
	griever.setup(maze, lair, 0.0)
	if clearing_only:
		# (nothing hunts in the clearing alone: the Griever is kept, as so much asks
		# for it, but asleep, hidden, out of the groups that would wake it and, as one
		# felled by a shot is, left alone by the dev panel and World._sleep_far)
		griever.set_meta(&"felled", true)
		griever.remove_from_group(&"pursuers")
		griever.remove_from_group(&"grievers")
		griever.process_mode = Node.PROCESS_MODE_DISABLED
		griever.visible = false
	var puppets := online and not Net.is_host
	enemies.set_puppet(puppets)
	# (where they are run, a director keeps the players' surroundings inhabited, in waves)
	# (the flag director=off goes without, to compare)
	if not puppets and Flags.value("director", "on") != "off":
		director = MazeDirector.put(self, seed_value)
	griever.puppet = puppets
	enemies.caught.connect(func(who: Node3D, _enemy: MazeEnemy) -> void: _on_caught(who))
	griever.caught.connect(_on_caught)
	Grass.push(griever, 1.6)
	for enemy: Node3D in enemies.enemies:
		Grass.push(enemy, 1.0)
	var away := taken.duplicate()
	away.append(lair)
	_runners(seed_value, away, puppets)


## The others in the maze (MazeRunners): as many in each ring as its style says
## ("Who else is in it"), placed from the seed away from where the hunters start.
## Alone or as the host they are run here and hunted like players; a guest's
## are puppets that follow the host's news (K_RUNNERS).
func _runners(seed_value: int, away: Array[Vector2i], puppets: bool) -> void:
	runners = MazeRunners.new()
	runners.name = "Runners"
	add_child(runners)
	runners.puppet = puppets
	runners.populate(maze, hash("runners/%d" % seed_value), maze_features().climbs, away)


## How near his hands a strung vine has to be for him to cut it, metres.
const CUT_REACH := 2.2


## The act button: cuts the strung vine (VineStrand) he is on or by, where he
## is, and tells the others. True if there was one.
func try_cut() -> bool:
	var hands := player.global_position + Vector3.UP * 1.0
	var strands := maze_features().strands
	for i in strands.size():
		var strand := strands[i]
		if is_instance_valid(strand) and strand.distance_to(hands) < CUT_REACH:
			var on_it := player.is_on_floor() and strand._nearest(player.global_position) >= 0
			var made := cut_strand(i, hands)
			# (if he was on it, he keeps hold of the end of the half
			# nearest him, and swings down on it)
			if on_it and not made.is_empty():
				var his := made[0]
				for vine in made:
					if vine.distance_to(hands) < his.distance_to(hands):
						his = vine
				player._hold_rope(his, his.length - 0.2, player.velocity)
			if online:
				Net.send_json(Net.BROADCAST, {"cut": i, "at": [hands.x, hands.y, hands.z]})
			return true
	# (a hydra's head near his hands is cut off, where the hunters are run: two grow back)
	for enemy: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		if enemy is MazeHydra and (enemy as MazeHydra).cut(hands):
			return true
	return false


## Cuts strung vine `index` (the same on every copy) nearest `at`.
func cut_strand(index: int, at: Vector3) -> Array[Vine]:
	var strands := maze_features().strands
	if index >= 0 and index < strands.size() and is_instance_valid(strands[index]):
		return strands[index].cut(at)
	return []


func maze_features() -> MazeFeatures:
	return (get_node(^"Maze") as MazeBuilder).features


## Something has caught `who`. Here (alone or as the host, where they are run):
## this player goes back to the clearing, and a guest is told to.
func _on_caught(who: Node3D) -> void:
	if who is MazeRunner:
		(who as MazeRunner).take()
		return
	if who == player and dev and dev.god:
		return
	if who == player:
		_back_to_the_clearing()
	elif online and Net.is_host:
		for seat: int in remotes:
			if remotes[seat] == who:
				Net.send_json(Net.BROADCAST, {"caught": seat})


## Caught: put back in the middle of the clearing, to try again.
func _back_to_the_clearing() -> void:
	put_player(spawn(slot), spawn_yaw(slot))
	caught.emit(slot)


## Puts this player straight down at `at`, facing `yaw` (off any ivy or vine).
func put_player(at: Vector3, yaw: float) -> void:
	if player.state == player.State.LADDER:
		player._leave_ladder()
	elif player.state == player.State.ROPE:
		player._leave_rope()
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	player.facing_yaw = yaw
	camera.snap()
	for field: Grass in get_tree().get_nodes_in_group(Grass.FIELDS):
		field.fill_near(at, 25.0)
	# (and the desert ring's woods, swamp or plains round him, if he is put there)
	var wilds := (get_node(^"Maze") as MazeBuilder).wilds
	if wilds:
		wilds.fill_near(at, 90.0)
	# (and the bridges and strung vines round him solid at once, not a few a step)
	RopeBridge.bodies_now(get_tree())


## Where a seat starts: round the middle of the clearing, facing out (or in
## front of the first gate, with `start_at_gate`, unless `middle`).
func spawn(seat: int, middle := false) -> Vector3:
	if start_at_gate and not middle:
		return gate_spot(0, seat).origin
	var angle := seat * TAU / 4.0 + PI * 0.25
	return Vector3(sin(angle), 0.0, cos(angle)) * 2.2 + Vector3.UP * 0.05


func spawn_yaw(seat: int, middle := false) -> float:
	if start_at_gate and not middle:
		return gate_spot(0, seat).basis.get_euler().y
	return seat * TAU / 4.0 + PI * 0.25


## Standing in the clearing a few metres in front of gate `gate` out of it,
## facing it; seats side by side.
func gate_spot(gate: int, seat := 0) -> Transform3D:
	var way: Array = maze.gates[0][gate % maze.gates[0].size()]
	var step: Vector2i = way[1]
	var out := Vector3(step.x, 0.0, step.y)
	var side := Vector3(-out.z, 0.0, out.x)
	var across: float = [0.0, 1.6, -1.6, 3.2][seat % 4]
	var at := maze.world(way[0]) - out * 4.0 + side * across + Vector3.UP * 0.05
	return Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), at)


## The light, after Inside (see MazeLight), and the edges of the picture darkened
## (see _vignette).
func _sky() -> void:
	MazeLight.put(self)
	_vignette()


## The edges of the picture darkened, as through a lens, and a faint grain over
## it all. Under the controls.
func _vignette() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = -1
	add_child(layer)
	var cover := ColorRect.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float strength = 0.55;
uniform float grain = 0.035;
void fragment() {
	vec2 from_middle = (UV - 0.5) * vec2(1.0, 1.15);
	float dark = smoothstep(0.32, 0.85, length(from_middle)) * strength;
	float noise = fract(sin(dot(FRAGCOORD.xy + fract(TIME) * 61.0, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	// Dark towards the edges, and each pixel a touch lighter or darker at random.
	float speck = noise * grain;
	float cover = clamp(dark + abs(speck), 0.0, 1.0);
	vec3 tint = vec3(0.03, 0.035, 0.035) * dark + vec3(speck > 0.0 ? abs(speck) : 0.0);
	COLOR = vec4(tint / max(cover, 0.001), cover);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	cover.material = material
	layer.add_child(cover)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	clock += delta
	_sleep_in -= delta
	if _sleep_in <= 0.0:
		_sleep_in = 0.5
		_sleep_far()
	if Input.is_action_just_pressed(&"act"):
		try_cut()
	if not out.has(slot) and maze.escaped(player.global_position):
		_got_out(slot, clock)
		if online:
			Net.send_json(Net.BROADCAST, {"out": slot, "time": clock})
	if online:
		_send_in -= delta
		if _send_in <= 0.0:
			_send_in = SEND_EVERY
			var news := _state(slot, player.global_position, player.velocity, player.facing_yaw, player.is_on_floor())
			# (and what he is doing, for the others to see him do it)
			news.append_array(RemotePlayer.doings_of(player))
			Net.send(Net.BROADCAST, K_STATE, news)
		if Net.is_host:
			_enemies_in -= delta
			if _enemies_in <= 0.0:
				_enemies_in = ENEMIES_EVERY
				var news := enemies.pack()
				news.append_array(griever.state_bytes())
				Net.send(Net.BROADCAST, K_ENEMIES, news)
				Net.send(Net.BROADCAST, K_RUNNERS, runners.pack())


func _got_out(seat: int, seconds: float) -> void:
	if out.has(seat):
		return
	out[seat] = seconds
	if remotes.has(seat):
		remotes[seat].escaped = true
	# (nothing hunts anyone who is out)
	if seat == slot:
		player.remove_from_group(&"maze_players")
	escaped.emit(seat, seconds)


## Whether everyone in the maze has got out.
func all_out() -> bool:
	if not out.has(slot):
		return false
	for seat: int in remotes:
		if not out.has(seat):
			return false
	return true


static func _state(seat: int, at: Vector3, moving: Vector3, yaw: float, grounded: bool) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(30)
	data[0] = seat
	data.encode_float(1, at.x)
	data.encode_float(5, at.y)
	data.encode_float(9, at.z)
	data.encode_float(13, moving.x)
	data.encode_float(17, moving.y)
	data.encode_float(21, moving.z)
	data.encode_float(25, yaw)
	data[29] = 1 if grounded else 0
	return data


func _on_packet(from: int, kind: int, data: PackedByteArray) -> void:
	if kind == K_STATE and data.size() >= 30:
		var seat := data[0]
		# (a guest speaks only for itself)
		if Net.is_host and from != slot:
			seat = from
			data[0] = from
			Net.send(Net.BROADCAST, K_STATE, data)
		if seat == slot or not remotes.has(seat):
			return
		remotes[seat].hear(
			Vector3(data.decode_float(1), data.decode_float(5), data.decode_float(9)),
			Vector3(data.decode_float(13), data.decode_float(17), data.decode_float(21)),
			data.decode_float(25), data[29] == 1)
		if data.size() > 30:
			remotes[seat].hear_doings(data.slice(30))
	elif kind == K_ENEMIES and not Net.is_host:
		var at := enemies.unpack(data, 0)
		if data.size() >= at + Griever.STATE_SIZE:
			griever.from_bytes(data, at)
	elif kind == K_RUNNERS and not Net.is_host:
		runners.unpack(data, 0)
	elif kind == Net.K_JSON:
		var message: Variant = JSON.parse_string(data.get_string_from_utf8())
		if not (message is Dictionary):
			return
		if message.has("loot") and loot:
			loot.hear(message, from)
			return
		if message.has("cut"):
			# (a guest's cut is passed on to the others by the host)
			if Net.is_host and from != slot:
				Net.send_json(Net.BROADCAST, message)
			var spot: Array = message.get("at", [0, 0, 0])
			cut_strand(int(message["cut"]), Vector3(spot[0], spot[1], spot[2]))
		if message.has("caught") and int(message["caught"]) == slot:
			_back_to_the_clearing()
		if message.has("out"):
			var seat := int(message["out"])
			if Net.is_host and from != slot:
				seat = from
				message["out"] = from
				Net.send_json(Net.BROADCAST, message)
			_got_out(seat, float(message.get("time", 0.0)))


func _on_left(seat: int) -> void:
	if remotes.has(seat):
		remotes[seat].queue_free()
		remotes.erase(seat)


func _put_gates() -> void:
	# (the doorways are measured against the walls, which must be in the physics first)
	await get_tree().physics_frame
	gates = ClearingGates.put(self, maze)
	# (only the clearing: kept shut, on nothing)
	gates.set_shut(clearing_only or not day.is_day())


func _shut_gates(shutting: bool) -> void:
	if gates and not clearing_only:
		gates.close(shutting)


## How many rings the maze has: the square ones, the desert and the round ones past it.
func ring_count() -> int:
	# (the desert counts as one)
	return maze.rings + (1 + maze.round_rings.rings.size() if maze.round_rings else 0)


## Things that hunt, roam or forage far from everyone are put to sleep: they
## neither think nor are drawn (the maze is a kilometre and more across, and
## most of what is in it is far out of anyone's sight). Woken again as someone
## comes near. (Far from every player in the room, so the host's copy keeps on
## moving whatever anyone is near.)
const SLEEP_FAR := 220.0
const WAKE_NEAR := 190.0
const SLEEPERS: Array[StringName] = [&"pursuers", &"maze_enemies", &"grievers", &"runners", &"campers", &"wildlife"]
var _sleep_in := 0.0


## Which zone of the maze a point is in: each square section its own (1, 2,
## 3...; the clearing goes with the first), then the desert, then the round
## sections. What is in a zone nobody is in sleeps, however near (the user,
## 2026-10-18: "that many monsters but just in zone 1- dont simulate outside
## there"). Asleep, they still go on their ways (Ecology), from zone to zone.
func zone_of(point: Vector3) -> int:
	var ring := maze.ring_of(maze.cell_at(point))
	if ring <= maze.rings:
		return maxi(ring, 1)
	if maze.round_rings and Vector2(point.x, point.z).length() >= maze.round_rings.inner_radius:
		return maze.rings + 2
	return maze.rings + 1


func _sleep_far() -> void:
	var eyes: Array[Vector3] = []
	if player:
		eyes.append(player.global_position)
	for seat: int in remotes:
		if is_instance_valid(remotes[seat]):
			eyes.append((remotes[seat] as Node3D).global_position)
	if eyes.is_empty():
		return
	var zones := {}
	for eye in eyes:
		zones[zone_of(eye)] = true
	var found := {}
	for group in SLEEPERS:
		for node in get_tree().get_nodes_in_group(group):
			found[node] = true
	for holder: Node in [enemies, wildlife, runners]:
		if holder:
			for node in holder.get_children():
				found[node] = true
	for node: Node in found:
		var thing := node as Node3D
		if thing == null or not is_instance_valid(thing) or thing == player:
			continue
		# (the dead are the world's to bring back: Ecology; a hunter felled by a shot is gone for good: Stagger.fell)
		if (thing is MazeEnemy and (thing as MazeEnemy).dead) or thing.has_meta(&"felled"):
			continue
		var nearest := INF
		for eye in eyes:
			nearest = minf(nearest, eye.distance_to(thing.global_position))
		if not zones.has(zone_of(thing.global_position)):
			nearest = INF
		var asleep := thing.process_mode == Node.PROCESS_MODE_DISABLED
		if not asleep and nearest > SLEEP_FAR:
			thing.process_mode = Node.PROCESS_MODE_DISABLED
			thing.visible = false
		elif asleep and nearest < WAKE_NEAR:
			thing.visible = true
			# (unless the dev panel has frozen everything)
			if not (dev and dev.frozen):
				thing.process_mode = Node.PROCESS_MODE_INHERIT


## With the flag `times`, how long each stage of `setup` took is printed (see
## tools/start_times.gd): `_lap` ends the stage `what` and starts the next.
var _lap_at := 0


func _lap(what: String) -> void:
	if Flags.value("times") == "":
		return
	var now := Time.get_ticks_usec()
	if what != "":
		print("  %-30s %6.0f ms" % [what, (now - _lap_at) / 1000.0])
	_lap_at = now
