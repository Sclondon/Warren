# Warren

A maze game for the Scareathon arcade, after *The Maze Runner* and *Labyrinth*. You and up to three friends
wake in a wide grassy clearing walled in by a maze that was not built for people: grey stone walls 34 m
high, damp and mossy, ivy hanging from them. Find the way out. The maze goes round the clearing in rings, each
walled off from the next but for one gate; a pale light stands up past the gate out of the last ring.

This is the start: the clearing, the first ring, rooms for playing together, and a maze made fresh each
round. Apophis, packs of mummies and a Griever hunt the passages, and other boys, the runners, run them; the walls do
not move, and there is no night.
Every player is Inside's boy:
no face, a plain shirt (its colour by seat, the first red) and dark trousers.

What the game is meant to be (pillars, art direction, the maze's rules, enemies, playing together) is in
[DESIGN.md](DESIGN.md); this file is how it is built and run.

Godot 4.7, GL Compatibility, landscape first (it also fills a portrait window). Web build in `build/`, served at
https://sclondon.github.io/Warren/build/.

## Playing

- **Move:** a thumb on the left half of the screen (touch), WASD or arrows, or a gamepad stick.
- **Look:** drag on the right half, the mouse, or the right stick. **Jump:** the jump button, Space, or A.
- **Cut** a vine strung across a hall (walk it like a tightrope from the ledge or bracket it is strung from): the hand button, E or F.
  It falls into two vines hanging from the walls; if you were on it, you keep hold of yours.
- **Take** what lies about (a grappling hook, a backpack, a spear, a torch, a flare, a map scrap, a rope ladder): the act
  button near it. **Tap a slot** at the top (or 1 to 4; a pad's d-pad and Y) to take a tool into his hand or put it
  back, or to read a map or hang a ladder; the act button then uses what is in his hand (throws the hook at a ledge's
  lip, throws the spear or the flare, lights a campfire with the torch). **DROP** (X, or the pad's d-pad down) puts it down.
- **Fight back** (DESIGN.md, "Fighting back"): a stick, a bat or a sword in his hand is swung with the act button and
  staggers what hunts in front of him; a revolver or a shotgun (rare, a round or two in it) is brought up and fired,
  and fells or staggers what it hits, loudly. Boxes of rounds go in his pocket and load an empty gun.
- Everything else the boy from *Outside* can do works too (sprint, duck, slide, climb a ledge, kick off a wall).
  The walls themselves are far too tall to climb, but there are ways up: ivy up the terraces, vines, rope bridges.
- **PLAY ALONE**, or **MAKE A ROOM** and give friends its four-letter code to **JOIN A ROOM**. The room's
  maker starts the game. When everyone is out, the room's maker picks the next maze.
- A run's score, sent to the arcade, is 10000 less the seconds it took you to get out.

## Laying out mazes by hand

Open `res://maze_editor.tscn`. Its root is a `MazeLayout`: set **Maze Seed** and **Rings** in the Inspector and
press **Generate**. The maze is laid out as pieces (`MazePiece`) in folders: Walls, Piers, Terraces, Ivy, Vines,
Bridges, Trees and the Beacon, each shown as it will be. Move, turn, resize (a box's **Size**, or scale it), copy or
delete any of them; a bridge's far end is its child **End**. Save the scene as `res://mazes/<name>.tscn` and rounds
play it: layouts in `res://mazes/` are played in name order (round 1 the first), round and round; with none there,
every maze is generated. **Playable** off leaves one out. **Game Light** off shows it in the editor's plain light.

The rules for generated mazes are set here too: every generated round is made by `maze_editor.tscn`'s **Clearing
Style** (with the clearing's own wall), **Square Sections** (a `MazeStyle` each, from the clearing out), **Desert**
(`DesertStyle`: dunes, the diagonal walls, its far wall) and **Round Sections** (a `RoundStyle` each, showing only
what a round section uses), from the round's own seed (`Mazes.rules`). A section's border wall is the one round its
outside. The maze is 7 rings: 3 square sections, the desert (a ring of its own) and 3 round ones; **Rings** counts
them the same way. Change a section's style here,
save, and the next round played uses it; the pieces laid out in this scene only count once saved into `res://mazes/`.

Walls count where they stand: which lines between cells have a wall is read from the wall and pier pieces when the
maze is played, so taking one away opens the way there (for the players, the things that hunt them and the way out),
and one put down on a line (every 14 m, half a cell off the middle) closes it. The rings, gates and clearing come
from the seed.

The maze is laid out and built in **zones**: the clearing, each square section, and outside (the desert and the
round sections past it). Generate again lays out only the zones whose rules have changed since the last Generate (or
whose walls or gates moved, or a neighbour's rules that reach across the wall between them changed: wall thickness,
border wall). The other zones keep their pieces and what you did to them by hand. **Generate All** replaces everything.
The editor's Output says which zones were laid out. A change to one section's own rules rebuilds only that section. A change to how its passages are carved can move its
gate out, so the sections past it change too, and it reshapes its cells along the wall round its inside, so the zone
inside it is rebuilt as well.

To find out what a setting does, turn on **Live Preview**: the maze is shown as the game builds it from the rules,
and built again a moment after any setting changes. Only the zones the change reaches are built again, with the
ground under them all (nothing of it is saved, and the pieces are hidden meanwhile). `tests/zones_test.gd` checks
that building zone by zone gives the same maze as building it whole, and `tests/zone_preview_check.tscn` opened in
the editor changes a few rules in turn and prints what each builds again. Clear the pieces to keep the scene light; Generate only when you want pieces to move by
hand. Hover a setting for what it does. In the editor ivy is drawn flat green (`IvyClimb.plain`): growing every patch
leaf by leaf was most of what Generate cost. `tests/preview_check.tscn` opened in the editor
(`"$G" --headless --path . --editor tests/preview_check.tscn --quit-after 600`) builds the preview and prints its time;
`tools/generate_times.gd` times the steps.

## How it works

- `scripts/maze.gd` (`Maze`): the plan. Square cells 14 m across. `Maze.CLEARING` cells across the clearing (41),
  then each ring as its `MazeStyle` (`scripts/maze_style.gd`) says: depth, hall width (it carves over blocks of
  cells), wall thickness, its border wall (round its outside: how high, and a rampart of solid cells; the clearing's own wall is `ClearingStyle`'s), straightness,
  branching, loops, entrances, rooms (`Maze.rooms`: open floors of whole blocks, a few halls into each from
  different sides, a column, a pine or a pond in the middle; `Maze.columns` are in the plan so the hunters go
  round them), and
  what is on its walls (see DESIGN.md): its levels of ledge are a list (`mezzanines`, each a `MezzanineLevel`,
  `scripts/mezzanine_level.gd`: height over the one under it, depth, share of faces). `rings` of them are built (1 for now) and the grid runs to the outside of
  the last. Each ring is grown from its first way in (into the first, a gate in the middle of each side of the
  clearing; into each later one, the gate out of the ring inside it), and its gate out put on its outside as far
  round the walls from its ways in as there is. The gate out of the last ring is the exit. The same seed always
  gives the same maze: `Maze.seed_for(room code, round)`.
- `scripts/maze_layout.gd` (`MazeLayout`) and `scripts/maze_piece.gd` (`MazePiece`): a maze as pieces, generated
  or laid out by hand (above). `MazeBuilder.build(plan)` lays out a generated maze and realizes it; `realize(layout)`
  builds any layout. `scripts/mazes.gd` (`Mazes`) finds the ones in res://mazes/; `scripts/maze_light.gd`
  (`MazeLight`) is the sky, mist and sun, for the game and the editor alike.
- `scripts/maze_builder.gd` (`MazeBuilder`): the walls inside a ring 34 m high and 3.2 thick, the walls between
  rings as high as the outer ring's style says (the clearing's 92 m, the rest 46) and 4.2 thick, each with a footing and a cornice, and square piers standing above them where walls
  meet; built of real blocks (each a chamfered slab a little proud or sunk, with joints between) out to 110 m
  and plain boxes beyond, in squares of 70 m so that what is off screen is not drawn, with plain boxes for shadows;
  a box for each piece to bump into. The next ring's outside wall stands
  unbroken beyond the last ring built, with open ground up to it. The ground, and over the clearing its gentle
  hills (`ClearingStyle`: a mesh and a heightmap to walk on, `MazeBuilder.hills`); stands of pines in the clearing
  (none in its middle, dense woods in one corner)
  and a few past the last ring (GameCommon's pine-tree); real grass over the clearing (GameCommon's
  grass: knee-high blades that the wind moves and the players push aside); the light past the exit.
- `scripts/corn.gd` (`Corn`): corn after Inside's cornfield (the user, 2026-10-18: "Lets also add corn like that one
  scene in the inside video"). Tall dry stalks (2.2 to 2.8 m: drooping, twisted leaves, an ear, a tassel; made in
  code) in rows over patches of ground, drawn per 8 m square as two MultiMeshes (the full stalk out to 16 m, a plainer
  one to 52; less of both on LOW quality), each square filled only when the camera first comes near. All the bending
  is in the vertex shader: the weather's wind, a lean from anyone near (plant_push's `pushed`), and a spring for each
  stalk shoved aside (at most 64, run in `Corn._spring`), so the stalks part round whoever pushes through and swing
  back behind. A rustle made in code follows the nearest few moving through it. Deep in it the hunters see you only
  within 8 m (`Corn.sight_reach`, asked by `MazeNav.sees`); they still hear you. `Corn.plant_maze` lays it down in
  rooms and stretches of hall (MazeStyle "Plants"), `Wilds` the plains quarters' fields (`WildLands.cornfields`).
- `scripts/marsh.gd` (`Marsh`): the marsh in front of the clearing's flooded entrance. How it lies is
  `ClearingStyle`'s (the marsh settings; `height_at`, `marsh_wet_at`, `marsh_depth_at`, `marsh_lane_at`); `Marsh`
  builds it: its own ground a point a metre (the hills' coarse ground, `ClearingStyle.coarse_height_at`, sunk out of
  sight under it) with a heightmap to walk on, one `Pool` of water over all of it at `ClearingStyle.MARSH_LEVEL`
  (so he wades and swims in it), sedges and reeds as two more grass fields, and bulrushes and lily pads in
  MultiMeshes by squares, drawn only near. `MazeBuilder._pond` adds it.
- `scripts/maze_features.gd` (`MazeFeatures`): the ways up, chosen from the seed. Terraces of stone against the walls
  like steps for something huge (a lower one 6.5 m up and 3 m deep, often an upper one at 13 m set back above
  it), with climbable ivy up their faces (`scripts/ivy_climb.gd`, `IvyClimb`, a `Ladder`) and sometimes on up to the
  wall top, where he can walk to the next pier; stone brackets with ivy up to them; vines to swing on, hung last of
  all on whatever is on the walls (`hang_vines`, after `MazeProps`; MazeStyle "Vines": mezzanine crossing, hanging
  and random crossing densities, an overall density and a height limit) (`scripts/vine.gd`, `Vine`, a `Rope`, its end
  2.6 m up so it takes a jump); and rope bridges (`scripts/rope_bridge.gd`, `RopeBridge`: a chain of points that
  sags, dips under anyone in the group `bridge_weights` and sways, its planks moving bodies, but only within
  36 m of someone in `bridge_weights`: `RopeBridge.Bodies`) between terraces
  across a hall and between wall tops. And grappling hook spots (`scripts/grapple_spots.gd`, `GrappleSpots`, pieces
  of kind ANCHOR: rings on corbels up the walls and at ledges' lips, hooks and pipes; one MultiMesh per look per 48 m
  square, found by the hook through `NearIndex`), by MazeStyle "Grappling hook spots".
  Sewer pipes through the walls high up (`scripts/sewer_pipe.gd`, `SewerPipe`; MazeStyle "Tunnels"), each mouth a
  modelled one (`scripts/sewer_mouth.gd`, `SewerMouth`): a bell of concrete flaring out of the wall on a lip that
  juts out under it, its underside curving back into the wall, drawn with the walls from the platform (a PIER piece
  with `mouth`) and bumped into as a few boxes; ivy up to the front of the lip, vines and a hook ring at its edge.
- `scenes/wall_gallery.tscn` (`scripts/wall_gallery.gd`, made by `tools/make_wall_gallery.gd`): a room of every
  wall style and look side by side, each signed; play it to walk among them.
- `scripts/wall.gd` (`Wall`, scene `scenes/wall.tscn`): a wall in a style (Basic: a plain box; Cornice, Pilasters,
  Stepped: decorated; `Wall.style_boxes`), width, height and depth in the
  Inspector, in one of several concretes (photographed, from Poly Haven, CC0: `textures/polyhaven/CREDITS.md`; or
  made by `tools/make_wall_textures.gd`), the repeats hidden by a shader that shifts the texture about and lays
  broad tone and rain stains over it. The maze's walls are drawn with it (`Wall.material_for`), Basic unless a
  wall piece is given a style (`MazePiece.style`): cast concrete inside
  the rings, precast slabs between them.
- `scripts/maze_stone.gd` (`MazeStone`): the ground shader (and the old stone wall shader, no longer used). The stone is Outside's `Sandstone`
  shader at a giant's scale (blocks 5 m long), made grey and damp: dark streaks run down from the joints, the
  foot of every wall is soaked and mossy, and ivy hangs in curtains from the top. Lit in hard bands like the figures.
- `scripts/world.gd` (`World`): one round. Sky, fog and sun; the maze; this player (`player.tscn`, Outside's boy
  from GameCommon) with `FollowCamera` (orbit, `indoors` so it stays out of the walls) and `TouchControls`;
  a `RemotePlayer` for each friend. Each copy sends where its own player is 12 times a second.
- `scripts/enemies/`: what hunts the maze. `Apophis` (Outside's great snake) and six kinds of `Mummy` (Outside's,
  with their rigs and models in `models/enemies/`) on a shared `MazeEnemy`, finding their way with `MazeNav` on the maze
  plan and placed from the seed by `MazeEnemies`; and the `Griever` (`griever*.gd`): a lump of wet meat on eight
  procedural robotic spider legs that plant on walls and ground, with a stinger. Then the newer kinds, each a thin
  `MazeEnemy` driving a creature from `creatures/` (installed from GameCommon): `MazeGhoul`, `Centipede`,
  `MazeSpider`, `Abomination`, `MazeFleshMound` (pairs, amalgams, striders and flesh mounds: one kind in four forms by how many bodies are in it, that grow by absorbing whom they catch and by merging), `MazeSlimeWall`, `Bats`, `MazeBaboon`, `MazeDog`, `Alien`, `Beetles`, `MazeFishPerson` (it brings its own pool to lurk in), `MazeAngel` (it drifts over the halls and its gaze, which builds while you stay in its sight, takes you; `Ophan` is its look), `MazeFrog` (a giant toad) and `MazeFrogSwarm`, `MazeHarpy`, `MazeBoar`, `Chickens`, `MazeGargoyle` (which finds its own ledge over a hall, or sets a stone corbel into the wall to crouch on), `MazeDeer` (the watching herd), `MazeElk` (the territorial bull), `MazeImp` (gangs that perch on walls, ride you and slow you) and `MazeImpSwarm` (a crack dozens pour out of); and `MazeColossus`, a spindly giant 260 m tall that crawls over the ring on the wall tops, sees whoever is in the open from above and presses one long finger down at them, and rears up over the clearing's wall to look in; `MazeCoyote` (skittish packs that shadow you and grow bold round someone alone; tame ones in the clearing, put in by `MazeEnemies.add_wildlife`) and `MazeSkinwalker` (hidden in a coyote pack), `MazeTripod` (a Martian tripod striding round the ring over the walls: its searchlight finds you, its horn sounds, then its heat ray burns down the hall or its grasper reaches down); `MazeClown` (still while watched, a sprint when not), `MazeStegosaurus` (a grazer that warns anyone too near and swings its spiked tail), `MazeSpiderMonkey` (troops that hang from vines over the halls and drop on you), `MazeLizardPerson` (bands that crawl the walls), `MazeTribesman` (the masked tribe: feral lost boys in carved masks who drum, chant and throw spears), `MazeDeinonychus` (feathered packs that cut you off), `MazePterodactyl` (soars, roosts on high wall tops, and dives to snatch anyone in the open), `MazeSnail` (climbs the walls after you, its slime holds you back), `MazeHydra` (in its marsh pool, striking with many heads), `MazeGibbon` (troops on the ledges and wall tops that whoop at you below and knock down climbers), `MazeBear` (a screaming bear calling out in its last victim's voice), `MazeBrachiosaurus` (a gentle giant of the desert, dangerous only underfoot), `MazeDimetrodon` (a basking, cold-blooded ambusher), `MazeGriffinfly` (giant dragonflies that buzz you and knock you down; two harrying someone alone catch them), `MazePsychicChild` (watches over whoever is calm near her with telekinesis, bursts when frightened), `MazeLynx` and `MazePanther` (on `MazeCat`), `MazeWolf` (endurance packs with dens and dusk choruses), and the wildlife they eat: `MazeFox`, `MazePondFrogs`, `MazeRabbit`, `MazeHare`, `MazeJackalope`; `MazeOctopus` (in a pool or a drain: grabs whoever lingers and drags them in; inks), `MazeMoose` and `MazeMammoth`; carnivorous plants (`MazeFlytrap`, `MazeSundew`, `MazePitcher`), `MazeMushrooms` and `MazeMushroomZombie` (blind hordes that hunt by sound), `MazeGnome` (pocket thieves, statues while watched), `MazeWeaver` (and its strands), `MazeAnts` and `MazeMantis`, `MazeRat`, `MazeRatSwarm` and `MazeRatKing`, `MazeLuckDragon` (comes down to whoever stands still in the open and carries them over the walls) and `MazeHorse` (lonely feral horses that come to trust you and follow), `MazeWyvern` (pairs of two-legged dragons nesting on high wall tops: a dive that carries you off, or landing to lash with a barbed tail), `MazeWoodsman` (a weary old man with an axe, a top hat and a lantern whose light keeps the hunters back; he warns off whoever comes near and swings at whoever crowds him) and `MazeBeast` (a tall antlered shadow, mostly unseen, that lures whoever is alone with its lantern and its hum; it shuns his light); dogs can be befriended with meat (cut from carcasses); fireflies (`FireflyField`) rise at dusk. They all live on their own as well (`Ecology`: hunger, the hunted and the hunters, the dead coming back). How many of each a ring
  has is its `MazeStyle` ("What hunts it"); `World` asks `MazeEnemies` for the first ring's (`populate`, then
  `add_hunters`) and puts in a Griever; alone or as the host they are run there and their state goes to guests ten
  times a second (K_ENEMIES), where copies follow it. Caught, a player is put back in the clearing; out, nobody is
  hunted.
- `scripts/wildlife/`: what lives in the clearing and hunts nobody. `TameChickens`: a tame ChickenFlock (with its
  sounds, ChickenVoice), placed by `TameChickens.populate` from the seed (ClearingStyle and MazeStyle, "Wildlife"),
  scattered by anyone running through; each copy of the game runs its own (`World.wildlife`).
  `Insects` (`World.insects`): moths, flies and dragonflies (InsectSwarm, `creatures/insects/`), placed by
  `Insects.populate` from the seed (MazeStyle and ClearingStyle, "Wildlife"). Moths gather round anything in the group
  `moth_lights` (meta `moth_radius`, `moth_height`, `moth_count`): it puts the angel, the light past the exit and any
  GameCommon `Fire` there (a fire joins by itself when it is put in); big moths rest on hall walls (placed with a ray
  when someone first comes near), clouds come out over the clearing at dusk. Flies gather round anything in
  `fly_carrion` (meta `carrion_radius`, `carrion_height`): the flesh mounds, the meat beast, the slime wall, carcasses
  (`InsectLook.carcass()`) in dead ends and in the boar's lair, and for `Insects.CAUGHT_TIME` where anyone is caught
  (World's `caught`, MazeEnemies' and the Griever's); they buzz, and land on someone standing still. Dragonflies hunt
  patches of the marsh and perch on its bulrushes' tips (`Marsh.bulrush_tops`, swaying with them:
  `Marsh.bulrush_sway`). Each swarm is drawn and moved only near the camera. The dev panel's + MOTHS (round a lantern),
  + FLIES (on a carcass) and + DRAGONFLIES put them in ahead. `Birds` (`World.birds`): blue jays (`BlueJays`) in the pines at the edge of the woods, which scold anyone under their trees, and a few crows in the treetops by the woods (ClearingStyle, "Wildlife"), and `Ravens` on the maze's walls (MazeStyle, "Wildlife"), omens that fly ahead of you to sit over a hunter waiting there; murders of `Crows` sit along the wall tops and erupt cawing at anyone who runs, calling the hunters. `Perches` finds where birds sit.
- `creatures/`: GameCommon's creatures, look and motion only (see each one's README): `ghoul`, `centipede`,
  `giant_spider`, `abomination`, `flesh_mound` (needs the boy from the character controller), `slime_wall`, `bats`, `baboon`, `dog`, `alien`, `beetle_swarm`, `fish_person`, `angel`, `frog` (the giant toad and the frog swarm), `harpy`, `boar`, `chicken`, `gargoyle`, `deer`, `elk`, `imp`, `imp_swarm`, `colossus`, `coyote` (needs `dog`), `skinwalker` (needs the character controller, `coyote` and `dog`), `tripod`, `insects` (moths, flies, dragonflies, and a carcass), `crow` (crows and ravens), `blue_jay` (needs `crow`), `woodsman` (needs the character controller; his lantern is `OilLantern`), `beast` (needs the character controller and `woodsman`). Change them here, then `kit.sh pull`
  them back to GameCommon (`godot/<name>`, with `_` as `-`). Their models are built in Blender by their `tools/` scripts.
- `scripts/wildlife.gd` (`Wildlife`): the animals that hunt nobody: herds of ordinary deer and elk grazing in the
  clearing's meadow (ClearingStyle, "Wildlife") and in the halls (MazeStyle, "Wildlife"), running off when someone
  comes near. Lightweight (not MazeEnemies, not sent over the network): each copy runs its own from the round's seed.
- `scripts/remote_player.gd` (`RemotePlayer`): a friend, a `Figure` on the boy's rig chasing their news.
- `scripts/runners/`: the others in the maze, after the Gladers' Runners. `MazeRunner` is the same boy as the players
  (`DrivenBoy`, `scripts/driven_boy.gd`: the player's own controller and rig steered by code, from GameCommon's
  `godot/driven-boy`) in a muted shirt of his own, who runs his own section (ring): jogs its halls by the middle on
  `MazeNav` waypoints (feeling ahead with a ray for what the plan does not know, a buttress, a tree), sprints from what
  hunts him (to cells he reaches first, the clearing best of all, or up ivy he gets to first), is loud while he
  sprints (hunters that see him near turn after him), waves both arms to draw a hunter off a player, beckons a player
  who comes up to him and runs for his section's gate, waiting when they fall behind, and stands aside pointing
  through it (`GestureRig`, `scripts/gesture_rig.gd`). He is in `maze_players`, so everything hunts him; caught, he
  is struck down (limp) and put back in the clearing, sits, and jogs home. `MazeRunners` puts in as many per ring as
  its style says ("Who else is in it": `runners`) and keeps them in step: the host runs them and sends
  `MazeRunners.pack()` ten times a second (K_RUNNERS); a guest's are DrivenBoy puppets steered with the same inputs.
- `scripts/loot/`: what lies about and the camps (DESIGN.md, "What lies about", "Camps"). `Loot` places them from the seed by
  the rules in ClearingStyle and MazeStyle ("What lies about"), keeps this player's inventory (two slots, four with a
  backpack; `Player.act_first` is how the act button takes things) and keeps the room in step (K_JSON `{"loot": ...}`:
  the host says who gets what, as it runs the hunters). `LootItem` (a loose body the Player carries and throws; a
  torch and a flare burn with GameCommon's `Fire`) and `LootHook` (the character controller's `GrappleHook`, made to
  feel for the lip of any ledge in reach; it also catches the hook spots and wraps hanging and strung vines),
  `LootGlint` (the glint off one lying about), `LootHud` and `LootMap` (the
  inventory, the prompt, a map scrap read, a gun's rounds), `Stagger` (a hunter knocked back by a spear, a blow or a
  shot, or felled by a shot), `FireWard` (what the swarms,
  `MazeEnemy.fears_fire`, keep off), `LootGunFx` (a shot's flash, streak and sound: the CC0 recordings in
  `audio/guns/`, from Outside), `RopeLadder` (a `Ladder` hung from an edge), `Campsite` (a camp, left or with
  people, from the models in `props/models/`), `SmokeColumn` (its smoke, one MultiMesh moved in its shader) and
  `Camper` (a `DrivenBoy` sat or asleep at one, who points you to what is near). The models are built in Blender by
  `props/tools/build_props.py`. `Campsite` and `SmokeColumn` are in GameCommon as `godot/campsite`.
- `scripts/looks.gd` (`Looks`): every player is the same boy, as Inside has him (no face, a basin cut, no cap,
  shirt, dark trousers and boots). Only the shirt's colour differs, by seat.
- `scripts/voice.gd` (`Voice`): proximity voice in rooms (web only), WebRTC signalled through the room.
- `scripts/net.gd` (autoload `Net`): the rooms connection, copied from October Valley. Server side:
  `server/routes/theClearing.js` in scareathon-v3 at `/the-clearing/ws`, which reuses
  `server/eightBitEvilV2/rooms.js` (four seats, four-letter codes, the maker hosts, seats held through
  a dropped connection). A guest can only talk to the host, so the host passes guests' news on.
- `scripts/main.gd`: the title (over a maze seen from above), joining by code (an on-screen letter pad, so no
  phone keyboard), the lobby, the HUD, round over, and the score sent to the arcade.
- From GameCommon (`C:\Projects\GameCommon`): `godot/character-controller` (player.tscn, `scripts/player.gd`,
  `character_rig.gd`, `character_look.gd`, `follow_camera.gd`, `touch_controls.gd`, `toon.gd`, `figure.gd`,
  models/boy*.glb and the rest listed in its FILES.txt), `godot/driven-boy` (`driven_boy.gd`, `gesture_rig.gd`),
  `godot/pine-tree`, `godot/grass`, `godot/fire` (the torches, flares and campfires) and `godot/campsite` (from here). Copies: change them here if need
  be, and pull good changes back with `sh /c/Projects/GameCommon/kit.sh pull`.

## Commands

Godot is `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe` (`$G` below).

```
"$G" --headless --path . --import                         # after adding a class_name script or a model
"$G" --headless --path . -s res://tests/maze_test.gd      # the maze plan
"$G" --headless --path . -s res://tests/smoke_test.gd     # alone: walk, walls, out, next maze, touch
"$G" --headless --path . -s res://tests/climb_test.gd     # ivy onto a terrace, a vine, a rope bridge
"$G" --headless --audio-driver Dummy --path . -s res://tests/pipe_test.gd   # a sewer pipe: up the ivy onto the lip of its mouth, crawled through ducked
"$G" --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/pipe_shots.gd -- <folder>   # pictures of sewer pipes' mouths: from the floor, beside, in, the boy on one
"$G" --headless --path . -s res://tests/strand_test.gd    # a strung vine: walked as a tightrope, cut into two vines
"$G" --headless --audio-driver Dummy --path . -s res://tests/bodies_test.gd   # bodies as a round starts; a strung vine's planks made as he comes up to it, gone once he leaves
"$G" --headless --path . -s res://tests/hunt_test.gd      # enemies in a round; caught, back to the clearing
"$G" --headless --audio-driver Dummy --path . -s res://tests/runner_test.gd   # runners: a route, ivy, drawing a hunter, caught, leading to a gate, a puppet
"$G" --headless --audio-driver Dummy --path . -s res://tests/climbers_test.gd   # hunters up after him on a ledge: a panther, a tribesman, giant ants, a puppet, the cost (-- all: every kind that climbs)
"$G" --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/runner_shots.gd -- <folder>   # pictures of runners
"$G" --headless --audio-driver Dummy --path . -s res://tests/loot_test.gd     # what lies about and the camps: placed, taken, slots, torch, spear, hook (a ledge, a route of hook spots, a hanging vine), ladder, map, weapons swung and guns fired, rarity by the rules, the room's news
"$G" --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/loot_shots.gd -- <folder> [1|1c|2|3|4|5|6|7|8|9|w|g|l|r]   # pictures of them (9: hook spots and a vine, w: weapons swung, g: guns fired, l: weapons lying, r: a friend fighting)
"/c/Program Files/Blender Foundation/Blender 4.3/blender.exe" --background --python props/tools/build_props.py [-- <folder> [names]]   # their models (and pictures)
"$G" --headless --path . -s res://tests/layout_test.gd    # a layout changed by hand, saved, loaded and played
"$G" --editor --path . res://tests/editor_check.tscn       # (after layout_test) what the editor shows, saved to user://editor_view.png
"$G" --headless --path . -s res://tests/enemy_test.gd     # Apophis and the mummies on their own
"$G" --headless --path . -s res://tests/griever_test.gd   # the Griever on its own
# each newer kind on its own (always with --audio-driver Dummy: some make sounds)
for t in ghoul centipede spider abomination flesh_mound slime_wall bats baboon dog alien beetles fish_person angel frog frog_swarm harpy boar chicken gargoyle deer wildlife imp imp_swarm colossus coyote skinwalker tripod crow clown stegosaurus spider_monkey lizard_person tribe deinonychus pterodactyl snail hydra gibbon ecology bear brachiosaurus dimetrodon griffinfly fireflies; do
  "$G" --headless --audio-driver Dummy --path . -s res://tests/${t}_test.gd; done
# pictures of each: tools/<kind>_shots.gd (windowed, 1280x720)
"$G" --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/frog_shots.gd -- <folder> [toad|swarm|maze|all]   # the frogs
"$G" --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/coyote_shots.gd -- <folder> [studio|strips|maze|all]   # coyotes: views, trot/gallop strips, a pack in a hall
"$G" --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/skinwalker_shots.gd -- <folder> [studio|strips|maze|all]   # the skinwalker
"$G" --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/woods_shots.gd -- <folder> [woodsman|beast|sound]   # the woodsman and the beast, close to by day and in a hall at night
"$G" --headless --path . -s res://tests/dev_test.gd -- --dev   # the dev tools (and the clearing wall's height)
"$G" --headless --audio-driver Dummy --path . -s res://tests/woods_test.gd -- --dev   # the woodsman and the beast, put in by the dev tools: drawn, his light, his warning and his axe, its lure and its reach, it fleeing him, their puppets, their boxes
"$G" --path . --resolution 1280x720 -s res://tools/climb_shots.gd -- <folder>   # pictures of the ways up
"$G" --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/catwalk_shots.gd -- <folder> [galleries]   # the catwalks: from the floor, on one, from above (`climb`, headless: up a ladder onto one and along it)
"$G" --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/looming_shots.gd -- <folder> [overcast|sunny|rain|dusk|night] [cost] [plain]   # far walls in the mist: the clearing, a long hall, from a ledge and over it, each desert quarter (`plain`: as before they drew their own mist)
"$G" --headless --audio-driver Dummy --path . -s res://tools/body_count.gd [-- defaults [nocatwalks]]   # bodies a solo round makes, by kind
"$G" --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/strand_vines_shots.gd -- <folder>   # vines hanging from strung vines: a picture, and their tops following it walked on and cut
"$G" --headless --path . -s res://tools/bake_preview.gd -- [seed] [rings]   # a maze to look round in the editor: preview/maze_preview.scn
"$G" --path . --resolution 900x900 -s res://tools/head_sheet.gd -- <file.png>    # every head shape
"$G" --path . --resolution 900x900 -s res://tools/legs_sheet.gd -- <file.png>    # every trouser cut and boot
node tools/dev_relay.mjs <scareathon-v3/server> 3111      # local rooms (needs server/node_modules)
sh tools/coop_test.sh                                     # two copies in one room against it
"$G" --path . --resolution 1280x720 -s res://tools/shots.gd -- <folder>   # pictures to look at
"$G" --path . --resolution 1280x720 -s res://tools/clearing_shots.gd -- <folder> [seed]   # the clearing: hills, woods
"$G" --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/room_shots.gd -- <folder> [seed]   # the rooms: the plan, in each kind, from above
"$G" --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/corn_shots.gd -- <folder> [seed]   # the corn: in a field at his height, him walking through, the plains, from above; and its costs
"$G" --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/deer_shots.gd -- <folder> [studio|strips|maze|clearing|all]   # deer and elk, gallop strips, the herd, wildlife
"$G" --headless --audio-driver Dummy --path . -s res://tests/marsh_test.gd   # the marsh: water, sedges in it, the lane in
"$G" --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/crow_shots.gd -- <folder> [studio|beat|maze|clearing]   # crows, ravens, blue jays, the wingbeat
"$G" --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/marsh_shots.gd -- <folder> [seed]   # the marsh, him in it
"$G" --headless --audio-driver Dummy --path . -s res://tests/insects_test.gd   # moths, flies, dragonflies: counts, culling, a light, carrion, caught, perching, cost
"$G" --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/insects_shots.gd -- <folder> [studio|maze|all]   # the insects up close, and in a round
"$G" --headless --path . --export-release "Web" build/index.html
```

Flags (command line `-- --name=value` or the page's `?name=value`): `server=<url>` for another rooms server.
`dev` turns on the dev tools (on anyway when the game is run from the Godot editor): everyone starts in front of a
gate of the clearing (`start=middle` for the middle), and a DEV button under the clock opens god mode: put mummies
(of a chosen kind, alone or in a pack), the snake or a Griever into the maze ahead, a runner or three (+ RUNNER,
+ RUNNERS: come up to one and he leads you to his section's gate), each thing to find a couple of metres ahead (+ HOOK,
+ BACKPACK, + SPEAR, + TORCH, + FLARE, + MAP, + LADDER, + STICK, + BAT, + SWORD, + REVOLVER, + SHOTGUN, + ROUNDS,
+ SHELLS) and a camp (+ CAMP, + CAMP (LIT) with runners at it), freeze) or clear everything that
hunts, be uncatchable, go to a gate, the middle or the exit. Keys: ` the panel, G god, M a mummy, N the snake, B a
Griever. What it puts in is only in your copy, so use it playing alone; no score is sent with it on
(`scripts/dev_tools.gd`, `DevTools`).

The clearing alone, to test in (it starts in about 2 s, not 11): `clearing` goes straight into a round of only the
clearing (its meadow, woods, tall grass, marsh, hills, wall and gates, its wildlife and loot), with no maze past its
wall, its gates kept shut, nothing that hunts and no runners; with dev tools on, the title has a CLEARING ONLY button
too, and the dev panel works there as anywhere (put creatures in to look at them). `rings=0` does the same for any
round started. In a test, set `main.clearing_only = true` (or call `main.start_clearing()`), or `world.clearing_only`
before `World.setup`. `times` prints how long each stage of making a round takes.

```
"$G" --path . --audio-driver Dummy -- --clearing --dev                      # play the clearing alone
"$G" --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/start_times.gd -- times [clearing]   # how long a launch takes
```
On the web, add `?clearing&dev` to the page's address.

## Not done yet

Rings past the first; enemies using the rope bridges, vines and ladders (they climb faces instead); ears;
walls that move, doors that shut at night, a map, sound and music, names, and reconnecting mid-round past the
server's 90 seconds.
