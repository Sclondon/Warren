extends Node
## The game from start to finish: the title (over a slow look down on a maze),
## making or joining a room, its lobby, and a round in the maze, then the next.
## All the screens are built here in code; the maze and everyone in it are World.
##
## Playing alone needs no server. Online, the room's leader (its maker) starts
## the round and calls the next one; every copy builds the same maze from the
## room code and the round number (Maze.seed_for).

const Flags := preload("res://scripts/flags.gd")
const FONT := preload("res://fonts/SpecialElite-Regular.ttf")
const CODE_KEYS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const INK := Color(0.93, 0.9, 0.8)
const MOSS := Color(0.45, 0.62, 0.33)
const STONE := Color(0.13, 0.14, 0.13, 0.86)

## "title", "join", "lobby", "loading", "play" or "paused".
var screen := "title"
var world: World
var round_number := 1
## This player's look, as the word for it (see Looks).
var look := Looks.pick()
## Set by tests: nothing is saved or reported.
var testing := false
## Rounds of the clearing alone, to test in (World.clearing_only): CLEARING ONLY on
## the title with dev tools on, or the flag `clearing`.
var clearing_only := false

var _ui: CanvasLayer
var _page: Control
var _hud: Control
var _clock_label: Label
var _toast: Label
var _toast_time := 0.0
var _code_typed := ""
var _code_label: Label
var _status: Label
var _solo_code := ""
var _preview_camera: Camera3D
## Talking to the others in a room (see Voice), kept from round to round.
var voice: Voice
var _mic: Button
var _pause: Control


func _ready() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	Net.room_changed.connect(_on_room_changed)
	Net.started.connect(_on_started)
	Net.closed.connect(_on_closed)
	Net.failed.connect(_on_failed)
	Net.packet.connect(_on_packet)
	voice = Voice.new()
	voice.name = "Voice"
	add_child(voice)
	voice.changed.connect(_show_mic)
	# (the flag `clearing`: straight into the clearing alone, to test in; tests start their own rounds)
	if Flags.value("clearing") != "" and not testing:
		start_clearing()
		return
	# (straight into a maze alone; the title's choices are in the pause menu. Tests
	# start their own rounds from the title)
	if testing:
		show_title()
	else:
		start_solo()


# --- Screens ----------------------------------------------------------------

func show_title() -> void:
	screen = "title"
	var page := _new_page()
	page.add_child(_spacer(1.0))
	page.add_child(_label("WARREN", 66, INK))
	page.add_child(_label("You wake in the middle of a maze.\nFind the way out.", 24, INK.darkened(0.15)))
	page.add_child(_spacer(0.6))
	page.add_child(_button("PLAY ALONE", start_solo))
	page.add_child(_button("MAKE A ROOM", make_room))
	page.add_child(_button("JOIN A ROOM", show_join))
	# (with dev tools on, a round of the clearing alone, to test in: World.clearing_only)
	if DevTools.enabled():
		page.add_child(_button("CLEARING ONLY", start_clearing, 26))
	page.add_child(_spacer(0.3))
	_status = _label("Up to four can play together.", 20, INK.darkened(0.3))
	page.add_child(_status)
	page.add_child(_spacer(1.0))


## The pause menu, over the round (MENU on the HUD, Escape, or a pad's Start): what
## the title had, a new maze alone, making or joining a room, and on with the round.
## Playing alone the round stands still behind it; in a room it goes on. The game
## goes straight into a maze, with no title first (the user, 2026-10-19: "The game
## should just load straigh into the maze, rather than menu then maze. Lets add a
## pause menu and put the main menu options there").
func show_pause() -> void:
	if world == null:
		show_title()
		return
	# (not while it is still loading, nor while he wakes: the HUD it is on is hidden then)
	if screen == "loading" or (_hud != null and not _hud.visible):
		return
	if _hud == null:
		_show_hud()
	_close_pause()
	screen = "paused"
	if not Net.active():
		world.process_mode = Node.PROCESS_MODE_DISABLED
	_pause = ColorRect.new()
	_pause.color = Color(0.03, 0.04, 0.03, 0.55)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_pause)
	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 24
	page.offset_right = -24
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 16)
	_pause.add_child(page)
	page.add_child(_label("WARREN", 56, INK))
	page.add_child(_button("RESUME", resume))
	if Net.active():
		page.add_child(_label("ROOM %s" % Net.code, 26, INK.darkened(0.2)))
		page.add_child(_button("LEAVE THE ROOM", leave))
	else:
		page.add_child(_button("NEW MAZE", new_maze))
		page.add_child(_button("MAKE A ROOM", make_room))
		page.add_child(_button("JOIN A ROOM", show_join))
		# (with dev tools on, a round of the clearing alone, to test in: World.clearing_only)
		if DevTools.enabled():
			page.add_child(_button("CLEARING ONLY", start_clearing, 26))
	_status = _label("Up to four can play together." if not Net.active() else "", 20, INK.darkened(0.3))
	page.add_child(_status)


## Back to the round from the pause menu.
func resume() -> void:
	_close_pause()
	if world:
		world.process_mode = Node.PROCESS_MODE_INHERIT
	screen = "play" if world else "title"


func _close_pause() -> void:
	if _pause and is_instance_valid(_pause):
		_pause.queue_free()
	_pause = null


## Back from joining: to the pause menu over the round, or the title if there is none.
func _back() -> void:
	if world:
		_show_hud()
		show_pause()
	else:
		show_title()


func show_join() -> void:
	screen = "join"
	_code_typed = ""
	var page := _new_page()
	page.add_child(_spacer(0.5))
	page.add_child(_label("ROOM CODE", 34, INK))
	_code_label = _label("_ _ _ _", 72, MOSS.lightened(0.3))
	page.add_child(_code_label)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for letter in CODE_KEYS:
		var key := _button(letter, _type_letter.bind(letter), 30)
		key.custom_minimum_size = Vector2(70, 70)
		grid.add_child(key)
	page.add_child(grid)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(_button("BACK", _back, 28, 170))
	row.add_child(_button("DELETE", _type_letter.bind(""), 28, 170))
	row.add_child(_button("JOIN", _join_typed, 28, 170))
	page.add_child(row)
	_status = _label("", 22, INK.darkened(0.2))
	page.add_child(_status)
	page.add_child(_spacer(0.5))


func show_lobby() -> void:
	screen = "lobby"
	var page := _new_page()
	page.add_child(_spacer(0.5))
	page.add_child(_label("ROOM", 30, INK.darkened(0.2)))
	page.add_child(_label(Net.code, 96, MOSS.lightened(0.3)))
	page.add_child(_label("Give your friends this code.", 22, INK.darkened(0.2)))
	page.add_child(_spacer(0.2))
	for entry: Dictionary in Net.players:
		var seat := int(entry["slot"])
		var text := "%s%s%s" % [runner(seat), "  (you)" if seat == Net.slot else "", "  away" if entry.get("away", false) else ""]
		page.add_child(_label(text, 30, INK if seat != Net.slot else MOSS.lightened(0.35)))
	page.add_child(_spacer(0.2))
	if Net.slot == 0:
		page.add_child(_button("START", Net.start_game))
	else:
		page.add_child(_label("The room's maker starts the game.", 22, INK.darkened(0.2)))
	page.add_child(_button("LEAVE THE ROOM" if Net.active() else "MENU", leave if Net.active() else show_pause))
	_status = _label("", 22, INK.darkened(0.2))
	page.add_child(_status)
	page.add_child(_spacer(0.5))


func _show_hud() -> void:
	_clear_page()
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hud)
	_page = _hud
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 16
	bar.offset_right = -16
	bar.offset_top = 12
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(bar)
	_clock_label = _label("0:00", 30, INK)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_clock_label)
	if Net.active():
		var code := _label("ROOM %s" % Net.code, 22, INK.darkened(0.25))
		bar.add_child(code)
	if Net.active() and voice.available():
		_mic = _button("", voice.toggle_mic, 20, 120)
		_mic.custom_minimum_size.y = 48
		bar.add_child(_mic)
		_show_mic()
	var menu := _button("MENU", show_pause, 20, 110)
	menu.custom_minimum_size.y = 48
	bar.add_child(menu)
	_toast = _label("", 34, INK)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 90
	_toast.offset_left = -340
	_toast.offset_right = 340
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_child(_toast)


func _show_round_over() -> void:
	var panel := _panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -230
	panel.offset_bottom = 230
	_hud.add_child(panel)
	var page := VBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 14)
	panel.add_child(page)
	page.add_child(_label("EVERYONE IS OUT" if world.remotes.size() > 0 else "YOU GOT OUT", 40, MOSS.lightened(0.35)))
	var seats: Array = world.out.keys()
	seats.sort_custom(func(a: int, b: int) -> bool: return world.out[a] < world.out[b])
	for seat: int in seats:
		page.add_child(_label("%s  %s" % [runner(seat), clock_text(world.out[seat])], 28, INK))
	if not Net.active() or Net.slot == 0:
		page.add_child(_button("NEXT MAZE", next_round))
	else:
		page.add_child(_label("The room's maker picks the next maze.", 20, INK.darkened(0.2)))
	page.add_child(_button("LEAVE THE ROOM" if Net.active() else "MENU", leave if Net.active() else show_pause))


# --- Flow -------------------------------------------------------------------

## A round of the clearing alone, played alone (see `clearing_only`).
func start_clearing() -> void:
	clearing_only = true
	start_solo()


func start_solo() -> void:
	_solo_code = "SOLO%d" % randi_range(0, 99999)
	round_number = 1
	_begin([{"slot": 0, "look": look}], 0, false, Maze.seed_for(_solo_code, round_number))


func make_room() -> void:
	_status.text = "Reaching the server..."
	Net.create(look)


func _join_typed() -> void:
	if _code_typed.length() < 4:
		_status.text = "A code is four letters."
		return
	_status.text = "Reaching the server..."
	Net.join(_code_typed, look)


func next_round() -> void:
	round_number += 1
	if Net.active():
		Net.send_json(Net.BROADCAST, {"round": round_number})
		_begin_online()
	else:
		_begin([{"slot": 0, "look": look}], 0, false, Maze.seed_for(_solo_code, round_number))


## A new maze alone, from the pause menu.
func new_maze() -> void:
	clearing_only = false
	start_solo()


## Out of the room (or the round), and on into a new maze alone (tests: back to the title).
func leave() -> void:
	if Net.active():
		Net.leave()
	_close_pause()
	_end_world()
	clearing_only = false
	if testing:
		show_title()
	else:
		start_solo()


func _begin_online() -> void:
	var players: Array = []
	for entry: Dictionary in Net.players:
		players.append({"slot": entry["slot"], "look": entry.get("hero", "")})
	_begin(players, Net.slot, true, Maze.seed_for(Net.code, round_number))


func _begin(players: Array, my_slot: int, online: bool, seed_value: int) -> void:
	_close_pause()
	_end_world()
	screen = "loading"
	world = World.new()
	world.name = "World"
	world.clearing_only = clearing_only
	add_child(world)
	# (a loading screen while the round is made, a stage at a time, so that it is not
	# frozen; tests have it all at once)
	if not testing:
		_loading_page()
		world.stepwise = true
		world.building.connect(_loading_step)
	await world.setup(seed_value, my_slot, players, online, Mazes.for_round(round_number))
	if not testing:
		_wake_up.call_deferred()
	voice.world = world
	world.escaped.connect(_on_escaped)
	world.caught.connect(func(_seat: int) -> void: _say("Caught! Back to the clearing."))
	screen = "play"
	_show_hud()


## The loading screen: the name, what is being made now, and how far along.
var _loading_label: Label
var _loading_bar: ProgressBar
## About how many stages a round is made in (World and MazeBuilder say each).
const LOADING_STAGES := 10


func _loading_page() -> void:
	var box := _new_page()
	(_page as ColorRect).color = Color(0.05, 0.055, 0.05)
	box.add_child(_label("WARREN", 66, INK))
	_loading_label = _label("Making the maze...", 28, INK.darkened(0.15))
	box.add_child(_loading_label)
	_loading_bar = ProgressBar.new()
	_loading_bar.max_value = LOADING_STAGES
	_loading_bar.show_percentage = false
	_loading_bar.custom_minimum_size = Vector2(520, 18)
	_loading_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var back := StyleBoxFlat.new()
	back.bg_color = STONE
	back.border_color = MOSS.darkened(0.35)
	back.set_border_width_all(2)
	back.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = MOSS.darkened(0.15)
	fill.set_corner_radius_all(3)
	_loading_bar.add_theme_stylebox_override("background", back)
	_loading_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_loading_bar)


func _loading_step(what: String) -> void:
	if _loading_label == null or not is_instance_valid(_loading_label):
		return
	_loading_label.text = what + "..."
	_loading_bar.value = minf(_loading_bar.value + 1.0, LOADING_STAGES - 0.5)


## The start of a round: he is asleep in the middle of the clearing, and we see
## through his eyes as they open: a slit, a blink, wider, a blink, open, bleary
## and then clear, looking up at the grey sky and the walls over him. Then he
## sits up and gets to his feet, and the view comes back behind him.
const EYELIDS := """
shader_type canvas_item;
// 0 shut, 1 wide open; how bleary (blurred and dim) what is seen is.
uniform float open = 0.0;
uniform float bleary = 1.0;
uniform sampler2D seen : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 p = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	// The opening between the lids: a wide almond, its top lid curving more than its bottom.
	float lid = open * 0.62;
	float top = lid * (1.0 - pow(abs(p.x) / 1.05, 2.0)) * 1.15;
	float bottom = -lid * (1.0 - pow(abs(p.x) / 1.1, 2.0)) * 0.85;
	float soft = 0.05 + 0.08 * bleary;
	float shown = smoothstep(top, top - soft, p.y) * smoothstep(bottom, bottom + soft, p.y);
	shown *= smoothstep(0.0, 0.08, open);
	vec3 colour = textureLod(seen, SCREEN_UV, bleary * 4.0).rgb;
	colour = mix(colour, vec3(dot(colour, vec3(0.33))), bleary * 0.5) * (1.0 - bleary * 0.35);
	// (dark at the edges, as the lids and lashes shade it)
	colour *= 1.0 - smoothstep(0.1, 0.65, length(p)) * 0.55;
	COLOR = vec4(colour * shown, 1.0);
}
"""


func _wake_up() -> void:
	if world == null or world.player == null:
		return
	var player = world.player
	# (asleep in the middle of the clearing: the shut eyes over it from the first frame)
	var lids := ColorRect.new()
	lids.set_anchors_preset(Control.PRESET_FULL_RECT)
	lids.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = EYELIDS
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"open", 0.0)
	material.set_shader_parameter(&"bleary", 1.0)
	lids.material = material
	_ui.add_child(lids)
	# (nothing of the HUD until he is up)
	if _hud:
		_hud.visible = false
	world.put_player(world.spawn(world.slot, true), world.spawn_yaw(world.slot, true))
	for i in 4:
		await get_tree().physics_frame
	if world == null:
		lids.queue_free()
		return
	player.fall_asleep()
	for i in 20:
		await get_tree().process_frame
	# Through his eyes: from his head, looking up past his shoulder at the sky and
	# the top of the clearing's wall.
	var eye := Camera3D.new()
	eye.fov = 70.0
	world.add_child(eye)
	var head: Vector3 = (player.get_node(^"Rig") as CharacterRig)._head.global_position
	var facing := Vector3(sin(player.facing_yaw), 0.0, cos(player.facing_yaw))
	# (a little over the grass he lies in, so that it is the sky and the walls, with grass at the edges)
	eye.global_position = head + Vector3.UP * 0.4
	eye.look_at(eye.global_position + (facing * 0.42 + Vector3.UP).normalized() * 10.0)
	eye.make_current()
	var opening := create_tween()
	for step: Array in [[0.28, 1.4], [0.04, 0.22], [0.55, 1.1], [0.18, 0.2], [1.0, 1.6]]:
		opening.tween_property(material, ^"shader_parameter/open", step[0], step[1]).set_trans(Tween.TRANS_SINE)
	opening.parallel().tween_property(material, ^"shader_parameter/bleary", 0.0, 2.2)
	await opening.finished
	if world == null or not is_instance_valid(eye):
		lids.queue_free()
		return
	# He gets up; the view comes back down out of his eyes to behind him.
	player.wake()
	if _hud:
		_hud.visible = true
	lids.queue_free()
	var from := eye.global_transform
	var took := 0.0
	while took < 1.8 and world and is_instance_valid(world.camera):
		await get_tree().process_frame
		took += get_process_delta_time()
		eye.global_transform = from.interpolate_with(world.camera.global_transform, smoothstep(0.0, 1.0, took / 1.8))
	if world and is_instance_valid(world.camera):
		world.camera.make_current()
	eye.queue_free()


func _end_world() -> void:
	if world:
		world.queue_free()
		remove_child(world)
		world = null
	if _preview_camera:
		_preview_camera.get_parent().queue_free()
		_preview_camera = null


## Behind the title and the lobby: down a long hall of the second section, at a
## boy's height, the walls going up into the mist, drifting slowly along it.
func _show_preview() -> void:
	_end_world()
	var view := World.new()
	view.name = "Preview"
	add_child(view)
	view._sky()
	var builder := MazeBuilder.new()
	view.add_child(builder)
	var rules := Mazes.rules()
	var maze := Maze.generate(randi(), 2, rules[0], rules[1], rules[2])
	builder.build(maze)
	_preview_hall = _longest_hall(maze, mini(2, maze.rings))
	_preview_along = 0.0
	_preview_camera = Camera3D.new()
	_preview_camera.fov = 60.0
	view.add_child(_preview_camera)
	_preview_camera.make_current()


## Where the menu's camera goes: [start, end] of the longest straight run of open
## hall in `ring` (by the middle of the hall where it is two cells wide).
var _preview_hall: Array = []
var _preview_along := 0.0


static func _longest_hall(maze: Maze, ring: int) -> Array:
	var best: Array = [Vector3.ZERO, Vector3.FORWARD * 40.0]
	var longest := 0
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) != ring or maze.solid.has(cell):
			continue
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			# (only from the start of a run: the cell behind is walled off)
			if not maze.blocked(cell, -step):
				continue
			var run := 0
			var at := cell
			while not maze.blocked(at, step) and maze.ring_of(at + step) == ring:
				at += step
				run += 1
			if run > longest:
				longest = run
				var across := Vector2i(-step.y, step.x)
				var shift := Vector3.ZERO
				for side: Vector2i in [across, -across]:
					if not maze.blocked(cell, side):
						shift = Vector3(side.x, 0.0, side.y) * Maze.CELL * 0.5
						break
				best = [maze.world(cell) + shift, maze.world(at) + shift]
	return best


func _process(delta: float) -> void:
	if _preview_camera and _preview_hall.size() == 2:
		# (drifting along it at a walk's pace, a little sway, round again at its end)
		var start: Vector3 = _preview_hall[0]
		var end: Vector3 = _preview_hall[1]
		var length := maxf(start.distance_to(end) - 20.0, 1.0)
		_preview_along = fmod(_preview_along + delta * 0.9, length)
		var way := (end - start).normalized()
		var at := start + way * _preview_along + Vector3.UP * (1.65 + sin(_preview_along * 0.9) * 0.03)
		_preview_camera.position = at
		_preview_camera.look_at(at + way * 30.0 + Vector3.UP * 7.0 + way.cross(Vector3.UP) * sin(_preview_along * 0.07) * 2.0)
	if world and _clock_label:
		_clock_label.text = clock_text(world.out.get(world.slot, world.clock))
	if _toast and _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)


## Escape, or a pad's Start: the pause menu, and back to the round.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var toggle := (key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE) or event.is_action_pressed(&"pad_start")
	if not toggle:
		return
	if screen == "play":
		show_pause()
		get_viewport().set_input_as_handled()
	elif screen == "paused":
		resume()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if screen != "join" or not (event is InputEventKey) or not event.pressed:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_BACKSPACE:
		_type_letter("")
	elif key.keycode == KEY_ENTER:
		_join_typed()
	else:
		var letter := char(key.unicode).to_upper()
		if letter.length() == 1 and CODE_KEYS.contains(letter):
			_type_letter(letter)


func _type_letter(letter: String) -> void:
	if letter == "":
		_code_typed = _code_typed.left(-1)
	elif _code_typed.length() < 4:
		_code_typed += letter
	var shown := ""
	for i in 4:
		shown += (_code_typed[i] if i < _code_typed.length() else "_") + (" " if i < 3 else "")
	_code_label.text = shown


# --- News -------------------------------------------------------------------

func _on_escaped(seat: int, seconds: float) -> void:
	var who := "You" if seat == world.slot else runner(seat)
	_say("%s got out in %s." % [who, clock_text(seconds)])
	if seat == world.slot:
		_report(seconds)
	if world.all_out():
		_show_round_over()


## The microphone button as the microphone is: on, off, being asked for, or refused.
func _show_mic() -> void:
	if _mic == null or not is_instance_valid(_mic):
		return
	var words := {"on": "MIC ON", "asking": "MIC...", "denied": "NO MIC", "none": "NO MIC"}
	_mic.text = words.get(voice.state, "MIC OFF")
	_mic.modulate = Color(0.75, 1.0, 0.7) if voice.state == "on" else Color.WHITE
	_mic.tooltip_text = "Talk to the others near you (V)"


func _on_room_changed() -> void:
	if screen in ["title", "join", "lobby", "paused"]:
		show_lobby()


func _on_started(_players: Array) -> void:
	round_number = 1
	_begin_online()


func _on_packet(_from: int, kind: int, data: PackedByteArray) -> void:
	if kind != Net.K_JSON:
		return
	var message: Variant = JSON.parse_string(data.get_string_from_utf8())
	if message is Dictionary and message.has("round") and not Net.is_host:
		round_number = int(message["round"])
		_begin_online()


func _on_closed(reason: String) -> void:
	var why := {"host": "The room's maker left.", "empty": "Everyone left.", "lost": "Lost the connection."}
	leave()
	var said: String = why.get(reason, "The room closed.")
	if _status and is_instance_valid(_status):
		_status.text = said
	else:
		_say(said)


func _on_failed(message: String) -> void:
	if _status and is_instance_valid(_status):
		_status.text = message


## A faster time is a better run: the arcade keeps the highest score, so it
## gets 10000 less the seconds taken (only from the web build, never in tests).
func _report(seconds: float) -> void:
	var score := maxi(10000 - int(seconds), 1)
	# (nor with dev tools on)
	if OS.has_feature("web") and not testing and not world.dev:
		JavaScriptBridge.eval("window.parent.postMessage({ type: 'PLAYER_DIED', score: %d }, '*')" % score)


func _say(text: String) -> void:
	if _toast:
		_toast.text = text
		_toast_time = 4.0


static func runner(seat: int) -> String:
	return "Runner %d" % (seat + 1)


static func clock_text(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


# --- Building blocks --------------------------------------------------------

func _clear_page() -> void:
	if _page:
		_page.queue_free()
		_page = null
	_hud = null
	_mic = null
	_clock_label = null
	_toast = null


func _new_page() -> VBoxContainer:
	_clear_page()
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.03, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)
	_page = shade
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24
	box.offset_right = -24
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	shade.add_child(box)
	return box


func _label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, pressed: Callable, size := 34, width := 420) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 78)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = STONE if state == "normal" or state == "focus" else STONE.lerp(MOSS, 0.4 if state == "pressed" else 0.2)
		box.border_color = MOSS.darkened(0.2)
		box.set_border_width_all(2)
		box.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(pressed)
	return button


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = STONE
	box.border_color = MOSS.darkened(0.2)
	box.set_border_width_all(2)
	box.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", box)
	return panel


func _spacer(weight: float) -> Control:
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.size_flags_stretch_ratio = weight
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return space
