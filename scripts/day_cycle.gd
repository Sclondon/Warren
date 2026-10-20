class_name DayCycle
extends Node
## Day and night over the maze: the hour goes round from morning, through a
## day of `day_seconds` (dawn to sunset) and a night of `night_seconds`, and the
## light the World put up (MazeLight: the sun, sky, mist and the light of the sky
## round) goes with it, from the grey of an overcast day through a dimmer dusk to
## a night lit only by a pale moon. At sunset the clearing's gates close
## (ClearingGates), and at dawn they open again.
##
## The hour is the same on every copy of the game in a room: it is worked out
## from how long the round has gone, and everyone starts the round together.

signal dawn
signal sunset

## How long the day is, dawn to sunset, and the night, in seconds of play.
@export var day_seconds := 420.0
@export var night_seconds := 180.0
## The hour the round starts at.
@export_range(0.0, 24.0) var start_hour := 7.0

## The hours of dawn and sunset.
const DAWN := 6.0
const SUNSET := 19.0
## How high the sun stands at midday, and the moon at midnight, degrees.
const SUN_HIGH := 68.0
const MOON_HIGH := 45.0

## The hour, 0 to 24.
var hour := 7.0
## Seconds of play since the round began (set ahead by DevTools).
var seconds := 0.0
## How light it is, 1 by day to 0 at night (for the clouds and the like).
var daylight := 1.0
## How gloomy the weather makes it (Weather): 0 the overcast of every day, 1 the
## dark of heavy rain: dimmer, the sky darker, the mist thicker.
var gloom := 0.0
## Lightning now (Weather), 0 to 1: the mist and the shade lit up white for a moment.
var flash := 0.0
## The colour of the mist now (for the rain and the fog Weather draws to match it).
var mist := Color(0.66, 0.7, 0.69)
## How sunny the weather makes it (Weather), 0 to 1: at 1 a clear day, a blue
## sky, a bright warm sun with sharper shadows, the mist thin and the colour back.
var sunshine := 0.0
## How much thicker the mist is round the camera, for a fog bank it is in
## (Weather: the clearing's), 0 the usual.
var thicken := 0.0
var _fog_base := Color.WHITE
var _ambient_base := 1.0
var _flashed := false
var _brood := 1.0

var _sun: DirectionalLight3D
var _environment: Environment
var _sky: ProceduralSkyMaterial
var _was_day := true
var _wait := 0.0
# What MazeLight made them, by day.
var _day := {}


## Puts a day cycle under `world`, driving the light MazeLight put there.
static func put(world: Node) -> DayCycle:
	var cycle := DayCycle.new()
	cycle.name = "DayCycle"
	world.add_child(cycle)
	return cycle


func _ready() -> void:
	var world := get_parent()
	for found in world.find_children("*", "DirectionalLight3D", false, false):
		_sun = found
	for found in world.find_children("*", "WorldEnvironment", false, false):
		_environment = (found as WorldEnvironment).environment
	if _environment:
		_sky = _environment.sky.sky_material as ProceduralSkyMaterial
		_day = {
			"top": _sky.sky_top_color, "horizon": _sky.sky_horizon_color,
			"ground": _sky.ground_horizon_color, "fog": _environment.fog_light_color,
			"ambient": _environment.ambient_light_energy, "fog_density": _environment.fog_density,
			"fog_height_density": _environment.fog_height_density, "saturation": _environment.adjustment_saturation,
		}
	if _sun:
		_day["sun"] = _sun.light_energy
		_day["sun_colour"] = _sun.light_color
		_day["shadow_blur"] = _sun.shadow_blur
		_day["shadow_opacity"] = _sun.shadow_opacity
	seconds = _seconds_to(start_hour)
	_apply()
	_was_day = is_day()


func _process(delta: float) -> void:
	seconds += delta
	# (the light a few times a second: the sky is drawn again whenever it changes)
	_wait -= delta
	if _wait <= 0.0:
		_wait = 0.25
		_apply()
	if _environment and (flash > 0.0 or _flashed):
		_flashed = flash > 0.0
		_environment.fog_light_color = _fog_base.lerp(Color(0.86, 0.9, 1.0), flash * 0.55)
		_environment.ambient_light_energy = _ambient_base + flash * 1.6
		MazeLight.share_mist(_environment, _sun, _brood)
	var day_now := is_day()
	if day_now != _was_day:
		_was_day = day_now
		if day_now:
			dawn.emit()
		else:
			sunset.emit()


## Whether it is day (from dawn to sunset).
func is_day() -> bool:
	return hour >= DAWN and hour < SUNSET


## Seconds of play to sunset, or to dawn by night.
func seconds_to_change() -> float:
	return _seconds_to(SUNSET if is_day() else DAWN) - fposmod(seconds, day_seconds + night_seconds)


## Sets the hour (for DevTools: on to dusk, or dawn).
func set_hour(to: float) -> void:
	seconds = _seconds_to(to)
	_apply()


# Seconds into the cycle (which starts at dawn) at which it is `at` o'clock.
func _seconds_to(at: float) -> float:
	var into := fposmod(at - DAWN, 24.0)
	var day_hours := SUNSET - DAWN
	if into < day_hours:
		return into / day_hours * day_seconds
	return day_seconds + (into - day_hours) / (24.0 - day_hours) * night_seconds


func _apply() -> void:
	var into := fposmod(seconds, day_seconds + night_seconds)
	var day_hours := SUNSET - DAWN
	var up: float
	if into < day_seconds:
		var share := into / day_seconds
		hour = DAWN + share * day_hours
		up = sin(share * PI)
	else:
		var share := (into - day_seconds) / night_seconds
		hour = fposmod(SUNSET + share * (24.0 - day_hours), 24.0)
		up = -sin(share * PI)
	# How light it is: 1 by day, 0 at night, through dawn and dusk; and how near
	# the sun is to setting or rising (for a little warmth then).
	var light := smoothstep(-0.25, 0.3, up)
	daylight = light
	var storm := Color(0.3, 0.32, 0.33)
	var low := clampf(1.0 - absf(up) / 0.35, 0.0, 1.0) * smoothstep(-0.2, 0.0, up)
	if _sun:
		var turn := 25.0 + (hour - 12.0) * 9.0
		var high := maxf(up, 0.1) * SUN_HIGH if up > 0.0 else maxf(-up, 0.15) * MOON_HIGH
		_sun.rotation_degrees = Vector3(-high, turn, 0.0)
		var moon := Color(0.55, 0.64, 0.82)
		var warm := Color(1.0, 0.78, 0.6)
		# (a sunny day's sun warmer and much brighter, its shadows darker and sharper)
		var sunny := Color(1.0, 0.95, 0.84)
		var by_day: Color = (_day["sun_colour"] as Color).lerp(sunny, sunshine).lerp(warm, low * 0.6)
		_sun.light_color = moon.lerp(by_day, light)
		_sun.light_energy = lerpf(0.32, _day["sun"] * lerpf(1.0, 2.6, sunshine), light) * lerpf(1.0, 0.75, low) * (1.0 - gloom * 0.6)
		_sun.shadow_blur = lerpf(_day["shadow_blur"], 0.9, sunshine)
		_sun.shadow_opacity = lerpf(_day["shadow_opacity"], 0.92, sunshine)
	if _environment:
		var night_top := Color(0.09, 0.11, 0.15)
		var night_horizon := Color(0.17, 0.2, 0.24)
		var dusk_horizon := Color(0.62, 0.52, 0.47)
		# (a sunny day's sky blue, deep overhead and pale at the horizon, and its mist a bright pale blue haze)
		var blue_top := Color(0.26, 0.46, 0.78)
		var blue_horizon := Color(0.64, 0.76, 0.9)
		var blue_haze := Color(0.74, 0.8, 0.86)
		_sky.sky_top_color = night_top.lerp((_day["top"] as Color).lerp(blue_top, sunshine).lerp(storm, gloom * 0.6), light)
		var grey := Color(0.46, 0.48, 0.49)
		_sky.sky_horizon_color = night_horizon.lerp((_day["horizon"] as Color).lerp(blue_horizon, sunshine).lerp(dusk_horizon, low * 0.5).lerp(grey, gloom * 0.5), light)
		_sky.ground_horizon_color = night_horizon.lerp((_day["ground"] as Color).lerp(blue_haze, sunshine * 0.5), light)
		_environment.fog_light_color = Color(0.15, 0.18, 0.22).lerp((_day["fog"] as Color).lerp(blue_haze, sunshine).lerp(dusk_horizon, low * 0.35).lerp(grey, gloom * 0.5), light)
		_environment.ambient_light_energy = lerpf(0.55, _day["ambient"] * lerpf(1.0, 1.2, sunshine), light) * (1.0 - gloom * 0.25)
		var clear := lerpf(1.0, 0.3, sunshine * light)
		# (the far walls brooding dark against the sky on a grey day, light on a sunny one: Wall.looming_shader)
		_brood = lerpf(1.0, 0.35, sunshine * light)
		_environment.fog_density = _day["fog_density"] * (1.0 + gloom * 0.9) * clear * (1.0 + thicken)
		_environment.fog_height_density = _day["fog_height_density"] * clear
		_environment.adjustment_saturation = lerpf(_day["saturation"], 1.0, sunshine * light)
		_fog_base = _environment.fog_light_color
		mist = _fog_base
		_ambient_base = _environment.ambient_light_energy
		MazeLight.share_mist(_environment, _sun, _brood)
