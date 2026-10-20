@tool
class_name MazeLight
## The light of the maze, after Inside: an overcast day, nearly without colour, so
## that the only strong colour is the shirts. A pale sky and a mist that thickens
## with distance and low down, out of which the far walls loom as dark slabs
## against the sky (they draw the mist themselves: share_mist); soft light
## from above with soft shadows; a little glow round bright things. The game's
## World puts it up, and so does a MazeLayout open in the editor, so that a maze
## laid out by hand is seen as it will be played.


## Puts the sky, mist and sun under `parent`; `internal` keeps them out of a scene being saved.
static func put(parent: Node, internal := false) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.5, 0.56, 0.58)
	sky_material.sky_horizon_color = Color(0.74, 0.77, 0.76)
	sky_material.ground_horizon_color = Color(0.6, 0.63, 0.62)
	sky_material.ground_bottom_color = Color(0.3, 0.32, 0.31)
	sky_material.sun_angle_max = 0.0
	sky_material.sun_curve = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 1.3
	# The mist: thickening with distance, and a little more low down. (Light in the
	# editor, which looks across the whole maze from high over it.)
	var editing := Engine.is_editor_hint()
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.66, 0.7, 0.69)
	environment.fog_density = 0.0012 if editing else 0.0045
	environment.fog_sky_affect = 0.6
	environment.fog_aerial_perspective = 0.4
	environment.fog_height = 6.0
	environment.fog_height_density = 0.0 if editing else 0.004
	# Glow round the bright (the light past the exit, the sky between the walls).
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 0.9
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Most of the colour taken out.
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.72
	environment.adjustment_contrast = 1.1
	environment.adjustment_brightness = 1.0
	var world := WorldEnvironment.new()
	world.environment = environment
	parent.add_child(world, false, Node.INTERNAL_MODE_BACK if internal else Node.INTERNAL_MODE_DISABLED)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	# (high and soft: an overcast sun, its shadows short and blurred)
	sun.rotation_degrees = Vector3(-68.0, 25.0, 0.0)
	sun.light_color = Color(0.92, 0.94, 0.95)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.shadow_blur = 2.5
	sun.shadow_opacity = 0.75
	sun.directional_shadow_max_distance = 140.0
	# (two cascades, blended where they meet, so that shadows do not jump in detail
	# as he walks; the near one covers the first quarter, where he is)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.25
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.6
	sun.shadow_normal_bias = 1.2
	parent.add_child(sun, false, Node.INTERNAL_MODE_BACK if internal else Node.INTERNAL_MODE_DISABLED)
	share_mist(environment, sun)


## Hands the mist on to the maze's walls, which draw it themselves (Wall's
## `looming` shader, so that far walls stand dark against the sky instead of
## fading into it): its colour (as the mist would have it, a share of the sky's
## horizon in it), how thick it is, and low down, and where the sun is and its
## colour (the mist is lighter towards it), and how brooding the far walls are
## (`brood`: 1 on a grey day, less on a sunny one). DayCycle calls it whenever it changes them.
static func share_mist(environment: Environment, sun: DirectionalLight3D, brood := 1.0) -> void:
	var colour := environment.fog_light_color.srgb_to_linear()
	var sky := environment.sky.sky_material as ProceduralSkyMaterial if environment.sky else null
	if sky:
		colour = colour.lerp(sky.sky_horizon_color.srgb_to_linear(), environment.fog_aerial_perspective)
	colour *= environment.fog_light_energy
	RenderingServer.global_shader_parameter_set(&"mist_colour", Vector3(colour.r, colour.g, colour.b))
	RenderingServer.global_shader_parameter_set(&"mist_density", environment.fog_density if environment.fog_enabled else 0.0)
	RenderingServer.global_shader_parameter_set(&"mist_height", environment.fog_height)
	RenderingServer.global_shader_parameter_set(&"mist_height_density", environment.fog_height_density if environment.fog_enabled else 0.0)
	RenderingServer.global_shader_parameter_set(&"mist_brood", brood)
	if sun:
		var basis := sun.global_basis if sun.is_inside_tree() else sun.basis
		var light := sun.light_color.srgb_to_linear() * sun.light_energy
		RenderingServer.global_shader_parameter_set(&"mist_sun", basis.z.normalized())
		RenderingServer.global_shader_parameter_set(&"mist_sun_colour", Vector3(light.r, light.g, light.b) if sun.visible else Vector3.ZERO)
