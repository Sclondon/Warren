# Warren: design

What the game is meant to be, and the decisions that shape it. The README says how it is built and run; this says
what it is for. Where the two disagree about the game (not the code), this one wins. Keep it current: when a
decision changes, change it here.

## The idea

You wake in a wide grassy clearing walled in on every side by a maze that was not built for people. Up to four
friends wake with you. Find the way out.

After *The Maze Runner* (the Glade, the walls, the Grievers, the sprint) and *Labyrinth* (a maze with rules of its
own), seen and lit like *Inside*. A secret cart in the Scareathon arcade (code **MAZE**), played in landscape.

## Pillars

1. **Built for something bigger.** The maze dwarfs you. Walls are huge, high, thick and damp; gaps through them are
   slots you squeeze through; the clearing is vast. Scale is the main feeling.
2. **Quiet dread, not combat.** You run, hide, climb and get out. You can fight back a little (a stick, a bat, a
   sword, and rarely a gun with a round or two: "Fighting back"), but it only ever buys a moment or one less thing
   after you; you never clear the maze. Being caught costs you ground (back to the clearing), not the game.
3. **Together, close by.** Friends in a room run the same maze, hear each other only when near, and lose each other
   round corners.
4. **Every maze new, every maze fair.** Mazes are generated from rules, a fresh one each round, the same for everyone
   in a room. Rules, not hand edits, are how the maze changes (hand layouts are possible, but the rules come first).
5. **Landscape first.** Laid out, played and checked in landscape (1280x720), with mouse and keyboard, a gamepad,
   or touch on a phone held sideways. It must still run smoothly in a phone browser, and still fit a portrait window.

## Look and feel (the art direction)

- **The boy.** Every player is Inside's boy, the same character for everyone (no random looks): no face, a mask-like
  head with a chin, a plain basin-cut of hair low over the brow, a plain shirt, tapered dark trousers with some shape
  to the legs (never tubes), short angular boots. The only difference between players is the shirt colour, by seat:
  Inside's deep red first, then faded blue, mustard, dull green. Every head and hair option made along the way is
  kept (CharacterStudio, and the head/hair sheets) for comparison. The runners (below) are the same boy too, in
  greyer shirts no player has: grey, brown, off-white, a dark charcoal-brown.
- **Animation.** Readable, exaggerated poses; a full-tilt sprint after Dylan O'Brien's in *The Maze Runner*; jump,
  slide, roll and trip with believable hands and ankles. Reference: `videoplayback.mp4`.
- **Light.** Inside's: overcast, misty, nearly colourless but for the red shirt; soft light from above, soft
  shadows. Mist thick enough to lose the far walls, but not so thick the maze is grey mush (lighter on the title and
  in the editor). Far off the walls loom out of the mist as dark slabs against the sky rather than fading into it
  (2026-10-19: "The Maze walls kind of just becom ugly featureless gray blobs in the distance ... amore brooding
  looming cinematic visual"): the mist thinner high up, so the tops loom while the feet are lost in it; darker and
  bluer high and far, never quite all mist; the slabs' joints and shades, the top edge and corners kept at a
  distance; lighter towards the sun, and light still on a sunny day (`Wall.looming_shader`, `MazeLight.share_mist`).
- **Weather** (`Weather`, from the room's seed, the same for everyone): spells of overcast, heavy cloud, rain (a
  sprinkle, steady rain, a downpour, a thunderstorm) and, now and then, a clear sunny day with a blue sky (2026-10-18:
  "There should also be sunny days with blue sky"). Rain thin, never thick white bars: fine streaks, droplets close
  by, distant sheets of it, and splashes where it lands ("should slapsh when it hits the ground. Theyre too thick").
  Some spells and some dawns a low ground fog that rises and sinks and that you leave a wake in; the clearing's wall
  always rising out of banks of billowing fog at its foot ("billowing fog that the clearing walls rise above").
- **Walls.** Brutalist concrete: cast concrete inside the rings, precast slabs between them; photographed textures
  without visible tiling, rain stains running down from ledges. Plain boxes by default (no crowning or footing);
  decorated styles are for particular places. Solid, never planes. "Maze walls should be very slightly weathered
  and rounded rather than perfect squares" (2026-10-18): their top edges and corners are worn round (unevenly: deeper
  in places, nearly sharp in others; rounder on the great walls), paler where worn, with chips, grime where the rain
  runs off their tops, and faces very slightly uneven. Still clearly huge brutalist concrete. Rules per section:
  wall edge rounding, border wall edge rounding, wall weathering (WallMesh builds them; collision stays boxes).
- **Ground.** Damp dirt and mud in the halls (cracked dry patches, stones, wet mud, moss along the wall feet,
  puddles that reflect the walls), at the quality of Outside's sand. Real 3D grass in the clearing that bends round
  you and stands back up, never mown.
- **Life on the walls.** Vines hang from the wall tops (climbable ropes); ivy where there are ways up.

## The maze

### Shape

Square rings round the clearing, middle out, each walled off from the next but for its gates. Only the first ring
is built so far; the others are planned. The way out of the last ring is the exit, marked by a pale light standing
up past it.

The plan is a grid of 14 m cells. Walls stand on the lines between cells. Every ring has its own **style**
(`MazeStyle`), which is where the rules live, and which can be changed per ring in the editor (`MazeLayout.styles`).

### The clearing

- 41 cells across: about 574 m. Open grass, stands of pines round its edge and dense woods in one corner (chosen by
  the seed), but no trees within 95 m of the middle. The middle is level (70 m out); past it very gentle hills, up to
  4 m, level again near the walls. All set by `ClearingStyle` (`scripts/clearing_style.gd`, `MazeLayout.clearing_style`).
- Something different before each entrance (`ClearingStyle.entrances`): dense woods round one, grass up to his chest
  round another, a marsh in front of another, nothing at all near the last.
- The tall grass (ClearingStyle "Entrances": tall grass width, reach, ragged, height, hollow): a meadow of grass up to
  his chest, half an oval with its straight side along the wall, about 340 m along it and 150 m out into the
  clearing, its edge wandering in bays and spits. It runs right up to the foot of the wall and to the gate on both
  sides of it; the doorway stays open (grass has no colliders). Changed 2026-10-18 at the user's word ("the tall
  grass area needs to be bigger in the clearing and run right up to the walls and door"): before, it was a round
  meadow of 75 m radius, its middle 55 m in from the gate, that met the wall only near the gate.
- Plants (`scripts/undergrowth.gd`): ferns and moss round the pines, bushes over the field. A bush is a rooted dome
  of leafy lumps a couple of metres across: thin stems from its foot, and over each lump a shell of small cards on
  which a shader draws sprays of pointed leaves, the gaps cut out, darker inside and low down, lit as one rounded
  mass. (2026-10-18, the user: "the bush just looks like floating squares": they had been flat-shaded diamonds hung
  round their lumps.)
- The ground casts no shadow (2026-10-18, the user: "I can see lines in the ground"): with the sun low it shaded
  itself in fine stripes (shadow acne), which showed between the grass.
- The marsh (`scripts/marsh.gd`, the marsh settings of `ClearingStyle`): not a pond but a wide, ragged bog, about
  190 m along the wall and 125 m out, beginning a few metres from the wall's foot. Many shallow, irregular pools and
  channels of standing water between hummocks and tussocks of wet ground, black mud at the water's edge, broad open
  meres in some parts and flats of tussocks in others, and a few deep dark pools he has to swim. The water is one
  sheet at one level that the ground stands up through: the shape is all the ground's, from the seed. Sedges grow all
  over it, up out of the shallow water too (thinner there and in open gaps, so the eye catches water at his height;
  darker and yellower than the field's grass; none in the
  deep pools), with reeds and bulrushes in clumps along the pools' edges (rounded heads of brown velvet; some gone to
  seed, some broken, some leant over) and lily pads and a scum of duckweed on the
  open water. All of it bends round whoever pushes through. Wading slows him (the deeper, the slower), he splashes
  going in and leaves rings. A lane in from the gate has nothing deep and nothing standing in it: the way in is wet
  but open. The gate itself is flooded (the user, 2026-10-18: "you have to wade through"): in front of it, from the
  wall's foot about 70 m along and 40 m out, water to his knees or waist (`marsh_flood_*`) with no dry way across,
  and on through the gate's slot in the wall into a pond across the hall beyond (Ponds). Wading, never swimming.
  Schools of small fish in its water dart off from whoever wades near (`FishSchool`).
- Its wall is a special case, far thicker than the grid, with its own controls (ClearingStyle, "Clearing wall"):
  by default 3 cells of solid stone (about 54 m) and 92 m high, twice the other walls between rings. Nothing grows or stands on it.
- Four gates, one in the middle of each side, each a slot about 2 m wide (about three of him) running the whole way
  through that wall. Every gate leads on into the maze: none is a dead end.

### The desert ring's quarters

Past the square sections, the desert ring is cut into four quarters by great walls from the square's corners, each
its own biome (`DesertStyle.Biome`, matched to the clearing's entrance on its side). Each is dressed (added
2026-10-18, the user: "why are the plains, swamp and forest empty?"), all of it by `DesertStyle` rules editable in the
maze editor (groups Forest, Swamp, Plains), nothing in the way within `keep_clear_radius` of a quarter's door or gate:

- **Desert:** Outside's sand in dunes.
- **Forest:** dense, dark woods of the game's pines (a tree every 6 m or so, open glades), ferns, bushes and moss under
  them, fallen logs, a few mossy boulders, on a dark floor of needles. Misty and dim, after Inside.
- **Swamp:** one sheet of still water, knee deep at most, over the middle of the quarter, hummocks of wet ground
  standing up through it cut by winding channels; dry boggy ground round its edges; sedges all over, reeds and
  bulrushes at the water's edge, lily pads, grey dead and drowned trees, and low banks of mist.
- **Plains:** wide grass over low hills, boulders, and outcrops of great rocks (the biggest as high as a house), and a
  couple of fields of tall dry corn (Corn).

`WildLands` (scripts/wild_lands.gd) works out where everything is from the seed, in squares of 64 m; `Wilds`
(scripts/wilds.gd) builds only the squares near the camera (MultiMeshes, shapes put in before their body enters the
world, seen only out to the mist) and lets far ones go, since each quarter is some sixty hectares. Trunks, logs and
rocks are bumped into; the swamp's and plains' ground is walked on (Maze.ground_height knows it).

### Ring styles

| | Avenues (ring 1) | Narrows (ring 3) | Tangle (ring 3, planned) |
| --- | --- | --- | --- |
| Depth | 6 cells (outside the clearing wall's 3 of solid stone) | 4 cells | 4 cells |
| Halls | 2 cells wide (about 16 m between walls) | 1 cell | 1 cell |
| Walls | 12 m thick, 34 m high | 3.2 m thick | 3.2 m thick |
| Passages | go on straight half the time; no extra branching; no loops | winding, forking | branching often, many loops |
| On the walls | climbable ivy up a tenth of the faces (a third to two-thirds of the way up, never to the top), stone brackets with ivy up to them, vines hung on the ledges, the brackets and the sewer parts and strung across the halls (walked as tightropes; no buttresses: the user, 2026-10-18, "I never asked for butresses"; the act button cuts one into two hanging vines) | terraces, ivy, vines, rope bridges | as Narrows |

What a style can set: depth (cells), hall width (cells), wall thickness, its border wall (the wall round its outside: how high, and extra cells of solid wall
thickening it on the far side), how often passages go straight, how often they branch, how many loops, narrow entrances (a passage of
some length from each gate) and doorways (a slot through a gatehouse), rooms, and what is on and about its walls.

**Rooms** (the user, 2026-10-18: "There should be larger “rooms” scattered about the maze"; MazeStyle "Hallways":
an on/off box, how many, how big in cells, on by default with 6 a section of 2 to 4 cells across): open floors
carved as part of the maze, whole blocks of it taken together, so the section stays one maze with nothing cut off.
Each is come into from halls on two to four sides, keeps a block clear of the wall round its section's inside (none
opens on the clearing or a rampart; in a section too narrow it may stand against the wall round its outside, but no
gate out is put in one), and keeps clear of the gates, the entrances and the other rooms. The walls are tall, so a
room is a light well: in the middle a column of the walls' stone from the floor to over their tops (four in a room
four cells across), a great pine, or a pond (only in a section with ponds). Nothing is strung or bridged across a
room; the ledges go round its walls as round any other.

**Corn** (the user, 2026-10-18: "Lets also add corn like that one scene in the inside video"; MazeStyle "Plants": an
on/off box, the share of rooms and of hall cells, on by default with a third of the rooms and a twentieth of the
halls): Inside's cornfield. Dry, pale, yellow-grey stalks taller than the boy, close in rows, filling a room from wall
to wall (round its column or pine; never a room with a pond) or a stretch of hall a few cells long and as wide as the
hall (none at a gate between sections). They bend and sway apart round anyone pushing through, spring back behind
with a sway, and rustle; you cannot see far through them, and deep in them the hunters see you only near. The plains
quarters have a couple of big fields too (DesertStyle "Plains": cornfields, how big).

Each feature of a section has its own on/off box in the maze editor's Inspector, its amount and size settings shown
under it only while it is on (the user, 2026-10-18: "Rather than a share slider - there should be check boxes to turn
on and off each feature for the section in the editor. Vines and ivy should be their own sections not in climbing,
same with sewers (wall decor) and tunnels."). The groups:
- **Climbing**: the mezzanines (a list of levels of ledge along the walls, each with its height, depth and share of
  faces; see "The levels of ledge" below), terraces (how many, upper terraces),
  arched concrete bridges between ledges at the same level (how many, deck width, arch rise),
  rope bridges (between terraces, wall top to wall top, between mezzanine ledges), metal catwalks over the top
  ledges (how many, how high, how wide, railings; see "The catwalks" below).
- **Ivy**: wall ivy from the ground (how many, how high), ivy on from upper terraces to the wall top, ivy between
  mezzanine levels.
- **Vines**: one box and five settings, hung on whatever is on the walls (see "The vines" below): mezzanine crossing
  density, hanging density, random crossing density, overall vine density, and a height limit (a percentage of
  the wall's height).
- **Wall decor**: stone brackets (with ivy up to them), vents, outlet pipes (and how many drip), cables looped along
  the walls.
- **Tunnels** (ways through and down): sewer pipes through the walls (how many, how high), culverts, drain grates,
  manholes.
- **Signs of life**: heaps of boxes and barrels, cables across the halls (snapped, lamps),
  junction boxes with a cable between, slanting cables, cables down from a ledge.
- **Grappling hook spots**: routes up the walls, rings at ledge lips, hooks to swing from.
- **Plants**: undergrowth along the wall feet, wall grass, corn. **Water**: ponds, and within them flooded halls,
  swimming ponds and fish.

Boxes that only matter with another on (bridges and ivy-to-top of terraces; flooded halls, swimming ponds and
fish of ponds) are hidden while it is off. A box is saved in the style's `features_switched`; a section saved before
the boxes (or a preset) has each feature on when its amount is more than 0, so it looks as it did. Off reads as an
amount of 0 (`MazeStyle.amount`), so the same random numbers are drawn and a maze with nothing changed is the same.
Every setting shows its unit in the Inspector (m, cells, s, "of faces", "of halls", per hectare...; shares are 0 to
1) and has a one-line tooltip (the user, 2026-10-18: "the editor also needs units - its hard to tell what im changing").

**The levels of ledge** (MazeStyle `mezzanines`, a list of `MezzanineLevel`; the user, 2026-10-18: "I should be able to
add mezzanines as a list and control them indvidiually, height and depth. The automatically get stacked on top of
eachother, and the limits of depth and theight should be the whole hallway for edditing purposes"). Add Element adds a
level over the last. Each has its *height* (m over the top of the level under it; the first, over the ground), its
*depth* (m out from the wall) and its *share* (of the faces with the level under it, how many have it too; the first
runs along every wall, a step of stone from the floor). They stack by themselves, each standing on the one under it,
and step back where each is shallower. The sliders run to 120 m (the highest maze wall) and 56 m (across the widest
hall, four cells), and further typed in; laying out keeps them sensible for the section (`MazeStyle.level_height`,
`level_depth`): the levels stop at the first that would come within 2 m of the maze walls' tops (or rises nothing),
and no level is deeper than leaves a 1.5 m walkway between it and one facing it across a hall of the section's width.
A section saved with the old rules (mezzanine height, depth, levels, level rise, depth step, upper share; thickness
was unused) is given the levels they made when it loads (`MazeStyle._set`): the same ledges as before.

Because walls are thick, any opening one cell long through a wall is itself a slot (cell minus wall thickness):
that is how the gates become slots.

### Round sections

Past the desert, three round sections (`RoundStyle`, `MazeLayout.round_sections`), each with a **layout**:
- **Maze** (ring 5, Spokes): passages grown between circular walls (`RoundMaze`).
- **Rotating doors** (ring 6, Turnstiles): halls round between circles of wall. Each circle is broken by doorways,
  and in each a great slab turns on a pivot under a lintel. You get through by timing it: either side of an
  edge-on door is a gap. The doors are moving bodies that shove you, turned by the round's clock (`World.clock`) so
  everyone sees the same thing. Their turns are spread so some door in every circle is always nearly open.
  Settings: circles, doors per circle, seconds per half turn, gap width.
- **Tunnel** (ring 7, Bore): one wide roofed tunnel all the way round, from the gates in to the way out. It is
  dim, lined in dark stone that the mist does not lighten, and lit only by slots across its roof (faint shafts and
  pale patches on the floor). Settings: width, height, skylight spacing.

### Standing water

Ponds and flooded halls (`scripts/ponds.gd`, MazeStyle "Water"): a share of hall cells has standing water, a pond
lying in the hall or a stretch of hall flooded from wall to wall, from puddle-deep to his waist, a few deep enough to
swim; the ground goes down under it, so he wades and swims. Laid out as pond pieces (editable by hand), kept clear of
walls, ledges and terraces. Grey, still, overcast water; schools of small dark fish in some that dart off as he wades
near. Cheap: one sheet of water per area of ponds, fish in one MultiMesh per school, and water and fish far from the
camera do nothing.

### Ways up

Terraces of stone against the walls (steps for a giant: 6.5 m and 13 m), ivy to climb their faces and sometimes on
to the wall top, vines to catch with a jump and swing on, rope bridges across halls and between wall tops. Which a
ring has is its style's choice. The wall tops are a second level you can travel along.

**The halls with ledges, as the user's concept slices draw them** (2026-10-18: "I added concept art folder for how the
vines and wires should work in zone 1 - its a slice of the maze, not to scale"; "I also included concept art for zone
2, how the mezzanines and vines should work, and there should be arched concrete bridges"; "Keep the ivy - I just left
it off for simplicity"). All of it is rules, each with its box, laid out only where both walls of a hall have a ledge
(`MazeFeatures._concrete_bridges`, `MazeProps._ledge_cables`; the vines are hung on all of it afterwards, see "The
vines"), with numbers of their own, so a maze laid out before is otherwise as it was:

- **Section 1** (one ledge along the walls, the hall narrow under it and full width over it). *Brackets*
  (Wall decor): stone brackets high over the ledges (height over the ledge, m), ivy up to each from the ledge; vines
  are strung across from them, swept down to the far ledge and hung from them. So: climb the ivy to the ledge, the ivy
  to the bracket, and walk or swing the vines from there. *Vines strung between the ledges* (at each level: under the
  ledges here), *vines hanging from a ledge's edge* to the level under it or the floor. Wires (Signs of life, props, not climbed): *junction boxes* high on
  both walls (height over the ledge, m) with a cable between them (a vine is now and then strung between them too, as
  from anything on the walls), *slanting cables* from high on one wall down to the other (low end and high end over the
  ledge, m), and *ledge cables* from a ledge's edge across and down to the far wall under its ledge (fixed at a share
  of the ledge's height), hanging on from there to the floor. The undergrowth at the walls' feet is the Plants one.
- **Section 2** (three levels of ledge, each stepping back from the one under it, so the hall is a narrow channel at
  the floor and widens level by level). *Concrete bridges* (Climbing): arched concrete bridges across the hall
  between the ledges at the same level, over the first (deck width, m; arch rise, m): a flat deck flush with the
  ledges, its underside an arch of blocks of the ledges' concrete worn round as the walls are; solid, walked across;
  ivy up to each end from the floor, level by level, so every bridge can be climbed to. Vines hang from the
  bridges' sides past the level under them (to the one under that, or the floor), and are swept from a ledge's edge
  down across to the far ledge a level under it. And, as in section 1, vines strung across between the ledges at each
  level (over the top ledges, across the floor's channel) and hanging from each level's edge to the one under it.

The ledges go round the ends of walls and outside corners, every level (the user: "the mezzanine should go around
corners not just end"); vents, outlets, culverts and wall cables stand out of a ledge's front instead of being buried
in it, and sewer pipes go through over the highest ledge there may be, their ivy up from the highest ledge under them
("sewer parts should stick out of the mezzanine rather than get clipped"). Every vine has roots and a bunch of
leaves where it is held ("the vines need to have a root or leaves at their connection points"), and its
leaves go round with the stem as it swings (they jumped round it as a hanging vine swung past upright: "the leaves
seem to teleport when they move"). The roots are young and green, small tendrils and rootlets lying over what holds
it, and the leaves are bunched thick on them and on the stem there ("The roots should be smaller and green, and
more leaves should be bunched around the connection"): over the lip of a ledge, a corbel or a bridge the stem comes
up over the edge and its roots spread over the top, a few rootlets gripping the edge (they stuck out into the air
before); out of a wall the stem comes out of the face and bends down, its roots over the face; under a beam or a
bracket they spread over its underside (which is drawn now: no box standing off the ground was drawn from below).
`Vine.Held` says which; `MazePiece.held`, `reach` and `held_end` carry it.

**The leaves** (2026-10-18: "the vine leaves and ivy leaves need some love, lets make a real leaf shape and try to
make sure they arent just floating"): a vine's are pointed ovals on short stalks, folded along the midrib, their tips
curling back, ten triangles (`Vine.leaf_mesh`), each stalk's foot on the stem; ivy's are five-lobed on long stalks,
twelve triangles (`IvyClimb.leaf_mesh`), each on its stalk off one of the stems, which lie on the wall's face, the
leaf lying over the wall with its tip just off it.

**The vines** (2026-10-18: "all of the wall decor props should be independent of the vines- the vines are hung on
whats there. There should be 3 sliders- one for mezzanine crossing density, one for hanging straight down vine
desnity, a thirdn for random corssing vine desnity ... and fourth and final for overall vine density. There hsould
also be a single height limit as a percentage of hte wall height"). Everything on the walls is laid out by its own
rules first, vines or none: ledges, terraces, brackets, sewer pipes, concrete bridges (`MazeFeatures`), then vents,
outlets, culverts, junction boxes and cables (`MazeProps`). Then the vines are hung on what is there
(`MazeFeatures.hang_vines`, last of all in `MazeLayout`), each place a vine may hang with numbers of its own, so the
vines' settings change only the vines:
- *Mezzanine crossing density* (vines per hall with ledges both sides, at each level): strung edge to edge across
  between ledges at the same level, or swept down from a level to the one under it on the far side.
- *Hanging density* (per anchor): a vine hanging straight down from a ledge's edge (every level), a bridge's side, a
  terrace, a bracket, a sewer pipe's platform, over the top of a vent, an outlet, a culvert or a junction box (to a
  hop over what is under it), or out of bare wall (a random way down).
- *Random crossing density* (per anchor): a vine strung or swept across the hall from any of those (but a ledge with
  a ledge across from it, and a bridge): to a thing on the far wall about across from it (a bracket, a junction
  box...), to the far wall itself (lower down, or up from low down), or swept down to the floor part way across,
  rooted there; clear of the ledges both sides.
- The densities are the chance for each ledge edge; bare wall faces have 0.3 of it, things on the walls 4 times it
  to hang and 1.5 times it to be strung across (`MazeFeatures.PULL`).
- *Overall vine density* (x) multiplies all three. *Height limit* (% of the wall's height, each wall's own): nothing
  higher holds a vine, and ledges over it have none.
- *Vines hanging from the vines strung across* (the user, 2026-10-19: "hanging vines should be able to hang from
  crossing vines"): laid after all of those, the hanging density times 0.8 for each strung vine (`MazeFeatures.
  STRAND_PULL`; none from one swept to the floor), from points along it clear of its ends, down towards the floor (or
  the ledge or catwalk under them), ending 2.4 m clear of it at least, under the height limit; roots and leaves where
  each is held under the stem (`Vine.Held.STRAND`). Their tops go where those points go (`VineStrand.hang`, `Vine.
  follow`): as it sags, sways and dips under someone walking it (only while it is awake, near someone), and cut, each
  goes with its half as that swings down (`Vine.carry`), or falls with a half too short to hang. Check and picture:
  `tools/strand_vines_shots.gd`.

Vines out of bare wall have their roots and a bunch of leaves where they come out, under the first ledge or over the
top one. They are Vines and VineStrands as any: swung on, climbed, walked and cut. Mazes saved with the old vine
rules (hanging, tightrope, terrace, bracket, ledge strung, swept, ledge hanging, wall and bridge vines, cables by
vines) load with them let go of (`MazeStyle.RETIRED`).

Pictures: `tools/zone1_vines_shots.gd` (pass `zone2` for the second section, `corners` for ledges round wall ends and
sewer props on ledges, `anchors` for where vines are held, `leaves` for the leaves close up,
`wallvines` for the vines out of the walls, `hung` for vines hung on the props).

**The catwalks** (MazeStyle "Climbing", Catwalks; the user, 2026-10-18: "we need to add a metal cat walk option that
will add pathways above the mezzanines, rarely in zone 2 and then lots in zone 3"). Grated steel walkways gone to rust,
dark and muted (`Catwalks`, `MazePiece.Kind.CATWALK` and `LADDER`, laid out by `MazeFeatures._catwalks`), at one height
in a section: *height* (m) over its top level of ledge, or over the floor where it has none, and never nearer the
walls' tops than 2.5 m under the cornice (`MazeStyle.catwalk_level`). Each straight stretch of wall (*share of halls*)
may have one along it, all of it or part, on brackets from the wall, railed on the hall's side, into the corners
(meeting one along the wall there) and short of the piers that stand out where walls meet. Across the halls (0.6 of
the share), from wall to wall on struts, or from one along a wall, meeting its side; one longer than 9 m also hangs on
rods from a steel beam under the walls' cornices; railed on one side or both (*railings*). *Width* (m) of the deck.
Ladders (the boy's own `Ladder`s) go up to them from the top ledge under them, or the floor: at some free ends of those
along the walls, beside some of those across the halls by a wall, and one at least to every way they make over the
maze; an end in the air with no ladder has a railing across it, and a railing is left open where a catwalk meets it
or a ladder comes up. Vines hang from their sides (the hall's side of one along a wall, both sides of one across, over
the floor) and are strung across from them, as the vines' rules say (`MazeFeatures.Anchor.CATWALK`). Cheap: every bar
of steel is one box in a MultiMesh, the decks another (the grating holes are cut by a shader, solid far off), the rungs
a third, a set for each 48 m square; one body for them all, a box shape for each deck and each stretch of railing.
Defaults: none in the first section, few in the second (0.08 of halls, 5 m over the top ledge), many in the third
(0.45, 9 m over the floor). Pictures and a climb: `tools/catwalk_shots.gd`.

**Grappling hook spots** (added 2026-10-18 at the user's request: "we should also have grappling hook spots"). Places
made for the grappling hook to catch, in rusty iron dark against the concrete, so that a way up can be seen from below
and planned (`GrappleSpots`, `MazePiece.Kind.ANCHOR`, laid out by `MazeFeatures` from MazeStyle "Grappling hook spots"):

- **Routes** (grapple route share, of the maze wall faces nothing else is on): stone corbels up a bare wall, one every
  6.5 m at most (grapple route rise), by turns either side of a line, an iron ring hanging from the end of each, from
  the ground (or the highest ledge along the face) to the wall's top, where a last ring hangs from the cornice. Throw
  at the ring above, climb, pull up onto the corbel, throw at the next. (So the hook can now take you to a wall top,
  but only up one of these.)
- **Rings at the lips of ledges** (grapple ring share): each level of the mezzanine along a face, terraces, the
  platforms under the sewer pipes, the strung vines' corbels. The hook catches any lip anyway; the ring shows where.
- **Hooks and pipes to swing from** (grapple swing share, and how high over the floor): an iron hook or an old pipe out
  of a wall over the hall.

Held, the hook marks what it would catch, and the next few things in reach faintly. It prefers a spot (or a vine) to
the bare lip of a ledge about as far off. It is also thrown at **vines**: at a hanging vine (in reach, out of reach of
a jump) it wraps round it about 3 m over his hands, he is hauled in up its line (quickly, slowing at the last) and
takes hold of the vine there, swinging on with a little of the haul's speed, the hook wound back in; then it is any
vine. At a vine strung across a hall it wraps round that, and its rope hangs from there to climb. Every copy of the game
lays out the same spots from the seed; a hooked vine swings on each player's own machine (as any vine does).

## Players

- Move, look, jump, and everything Outside's boy can do: sprint (its own button), duck, slide, roll, climb a ledge,
  kick off a wall, climb ivy, swing on ropes, cross bridges.
- Controls: left thumb moves, right half drags the camera; keyboard/mouse and gamepad too. The camera follows behind
  when you run away from it, and never circles you when you run sideways.

## What hunts the maze

- **Apophis**, Outside's great snake.
- **Mummies**, six kinds from Outside, in packs.
- **The Griever**: a gelatinous lump of wet meat on eight robotic, procedurally animated spider legs that plant on
  walls and floor, with a stinger. It sees, hunts, winds up, strikes.
- Added 2026-10-18 at the user's request ("models and animations specifically, and then as reusable components"):
  each is a GameCommon creature (look and motion, `creatures/<name>/`) driven by a thin `MazeEnemy` here.
  - **Ghoul** (after Zelda's ReDeads, from our mummies, no wraps): raw red, bare, a blank mask face. A statue in a
    dead end until it sees someone; its wrenching shriek freezes anyone facing it for about 2 s; it rushes (faster
    than a walk) and hug-grabs. Turn away or run at once and it is easy to get past.
  - **Giant centipede**: rests coiled, hunts faster than a run (a sprint escapes), up the wall feet round corners,
    rears as a warning and pounces with its claws.
  - **Giant spider**: waits head down high on a wall, drops on a thread, charges in dashes, rears, lunges. Loses
    a sprinter. Climbs back up to wait.
  - **Meat abomination** ("MEAT BEAST" on the dev panel): slow, never lets go, nearly fills a hall; lashes tendrils
    from a few metres after a visible wind-up; touching it catches.
  - **Flesh mounds** (added 2026-10-18: "hands and legs sticking out of it ... like it's absorbed a bunch of people", no
    mouth; "the torsos should use the character torsos, with mask faces ... less bloody, more like the skin grew together,
    maybe pussy"; "different size abominations that can grow and merge together or by absorbing people"): people grown
    together, one creature in sizes by how many bodies are in it. Pallid waxy skin flowing from body to body, puckered
    scar-dark seams, stretch marks, veins, boils of pus; the boys' blank mask faces; men's arms, long gaunt arms and legs.
    Five forms (2026-10-18, the user: "a couple more amalgam stages rather than just the 2", then "one more stage before
    abominations thats like a sphere of bodys that rolls around"):
    - **Pair** (2): two boys grown together back to back, the one under on all fours, the one on top face up with
      his arms and legs waving like an upturned beetle's. Scuttles nearly as fast as a run (3.9 m/s); where its quarry
      is in a straight line within 9 m it crouches (0.6 s) and rushes at 6.6 m/s, faster than a sprint, for only
      about 1.1 s. A step aside or a side turning gets away. Running into it catches.
    - **Amalgam** (3 or 4): boys fused at the hips in a wheel of limbs. Shambles a little slower than a run; where its
      quarry is in a straight line down a hall it rears with its limbs splayed (0.6 s, the warning) and cartwheels at them
      at 5.1 m/s, faster than a run, slower than a sprint, for about 3 s, then is spent and lurches slowly. A sprint, a
      side turning or a climb gets away. Rolling into you catches.
    - **Strider** (5 or 6): the boys joined at the hips in a ring, each bent over outwards, heads hanging, walking on
      all ten or twelve legs, the ring turning slowly. A little slower than a run hunting (3.5 m/s); it faces every
      way, so it grabs at anyone within about 2.5 m on any side (0.95 s wind-up, the ring tipping and lunging, the
      boys on that side throwing their arms). A closing hand or walking into it catches.
    - **Ball** (7 or 8): the boys grown into a sphere as high as two men, heads, shoulders and arms out all round it.
      It rolls wherever it goes, the arms that come round under it slapping down; down a straight hall it gathers speed
      until it is faster than a sprint (6.4 m/s), but it turns only slowly and must slow nearly to a stop for a corner:
      a turning off its way, or a climb, gets away. Rolled over, you are caught.
    - **Mound** (9 to 10, the "abomination"): fills more of a hall the bigger it is, crawls slower (no faster than a walk). Hauls itself on
      its hands, on the walls where they are near; grabs with the hands at its front after a wind-up (arms drawn up,
      hands splayed and shaking). A closing hand or walking into it catches.
    - **Growing**: whom it catches it absorbs (their body is seen dragged in; the player still goes back to the clearing)
      and it gains a body; two that meet merge, the smaller flowing into the bigger. Growing past a form's most makes it
      the next form (pair, amalgam, strider, ball, mound). Capped at 10 bodies (phones). Each section has, by default, two
      pairs, two amalgams, a strider of 5 or 6, a ball of 7 or 8 and a mound of 9 or 10 (MazeStyle pairs, amalgams,
      striders, balls, flesh_mounds).
  - **Slime wall**: see-through jelly full of skeletons that fills a hall wall to wall, below walking pace;
    touching it catches (you are drawn in and tumble among the bones). Find another way round.
  - **Bats**: a colony roosts on a wall; running or sprinting near wakes it. They catch nobody: they mob the
    player and call every hunter within 45 m to them. Duck or stand still and they lose interest.
  - **Demon baboons**: troops of a mandrill alpha and baboons. They bark, flank (some go where you are heading),
    burst faster than a run and tire; a sprint escapes. Leap-grab.
  - **Feral dogs**: packs that follow players' scent trails nose-down out of sight, bay and gallop on sight
    (between a run and a sprint), lunge-bite. Climbing breaks the trail.
  - **Aliens**: twos and threes that walk calmly and blink ahead of you when unwatched (a shimmering column
    warns first; looking at it stops it), then raise a hand and catch you in a pale light.
  - **Beetles** (after Outside's scarabs): a swarm of several hundred glossy black beetles with an oily sheen
    (ground beetles and dor beetles) waits in cracks at the foot of a wall, in a dead end or along a hall. When
    someone comes down the hall they pour out and flood along the floor after them, lapping up the wall feet, a
    little faster than a run and slower than a sprint. Those that reach you run up your legs; enough of them for
    a moment and you are caught. Sprint away, or get up onto a terrace, the ivy or a vine (they climb no higher
    than about a metre up a wall); when they get no nearer for a few seconds they stream home into the cracks.
  - **Fish people** (deep ones, out of Innsmouth; the user asked 2026-10-18 for "a fish person enemy that uses the
    character controller as a base"): tall, stooped, grey-green and scaled, a fish's head with glassy eyes and needle
    teeth, gills, a fin down the back, webbed hands and feet. Each lies in a black pool of its own in a hall, sunk to
    its eyes: a puddle with two eyes in it, if you look. Down there it hears only what is close or loud: walk softly
    past along the far wall and it stays down; run near it, or step in its pool, and it rises and croaks, and its
    croak brings up every other fish person within about 40 m. It shambles below a walk, but lopes faster than a run
    in short bursts when it sees you near, then stands gulping for breath; a sprint or a corner loses it. It lunges
    and grabs with both hands. It cannot stay out of the water: after half a minute, or once it has lost you, it goes
    back to its pool and sinks.
  - **Angel** (a "biblically accurate" one, after Ezekiel's ophanim and Isaiah's seraphim): three great wheels of
    pale gold one within another, turning slowly, their rims full of real eyes that blink out of step, round a
    burning white-gold heart half hidden by six wings. Huge (7 m across), silent, floating over the halls; the one
    warm bright thing in the mist, lighting the walls round it. It drifts slowly and everyone passes under it, but
    its eyes look every way, so there is no creeping past behind it. Being SEEN is the danger: while you stand in its
    sight in the open its gaze builds on you over about four seconds (quicker near it), and everyone can see and hear
    it build: every eye turns on you, the wheels stop, the wings before its face part, a cone of pale light reaches
    down and pools at your feet, and a choir swells and rises. If it reaches the full you are drawn up into the light
    and taken. Break its sight (a corner, a slot, onto the ivy) and the gaze falls away. One in the first ring.
  - **Giant toad** (added at the user's request, "a frog enemy"): a huge warty toad, taller than the boy's chest,
    squatting wet and still in a dead end, throat pulsing. Seen, it croaks (its throat a great bubble), turns on you
    slowly and comes in great arcing leaps (slower than a run, on the whole). Near and facing you, it winds up for
    about a second where you can see it (the throat swells, the mouth gapes), aims at your chest and holds that aim
    for the last third of a second, and shoots a sticky tongue several metres. Step aside, duck under it, or be out of
    reach; it misses, gulps and sits a moment.
  - **Frog swarm**: dozens of small frogs (fist- to cat-sized) in a muddy pool in a dead end, a few sitting about its
    edge. Come near and they pour out at you in hopping waves, leaping over each other, croaking in chorus. Those that
    reach you leap on and cling, and the more there are the slower you go; enough of them for long enough and you are
    caught. Outrun them, shake them off by running and jumping, or get up onto something (a terrace, the ivy): they
    cannot hop that high, give up and go home.
  - **Harpies** (the user: "lets add a harpie type enemy"): a starved woman's head and trunk (ribs, hollow eyes, a
    too-wide lipless mouth, lank wet hair over the face) on great ragged grey-black wings, with a bird's lower body
    and scaly raptor legs. Each perches high on a wall (the ledge, or the top), hunched, wings mantled, watching the
    hall below. Seeing someone out in the open it screeches (the first warning), takes off over the walls and
    circles high over them; then a falling cry (the second warning), a stoop over the end of a long straight hall,
    and a dive down it, talons first, at chest height. It flies over the walls, so it can come from anywhere, but
    it needs a straight run of hall, wider than its wings, under open sky: under a bridge or a platform, or in a
    slot, you cannot be dived at, and staying hidden long enough sends it home. Its line is set the last half second: duck, slide or roll and
    the talons pass over; step aside and they pass by; stand or run straight and you are snatched. Two dives, then
    it climbs back to its perch and lands.
  - **Giant boar** (after the boar gods of *Princess Mononoke*): a wild boar far over the boy's head at the
    shoulder, black bristle with a crest down its hump, great chipped tusks (one broken), mud-caked, scarred, old
    arrows in its hide, steaming breath. It roots in the mud of a dead end or a wide hall. Poor eyes, a great nose:
    it smells anyone near, much further upwind of it than downwind, so creep past downwind. Noticing you it snorts,
    stamps and paws, its hackles rise and it lowers its head (about two seconds, seen and heard), then charges in a
    straight line, far faster than a sprint and barely able to turn. Step aside (a side passage, a slot, a way up)
    and it thunders past and skids, or slams into the wall and stands stunned a few seconds, then forgets you a
    while. In its way, you are tossed and caught. It cannot reach anyone up a wall.
  - **Chickens** (added at the user's request, "lets also add chickens"): flocks of scruffy feral hens and a rooster
    foraging in the halls, pecking and scratching at the mud, heads bobbing with the chicken head-lock; filthy and
    molting, a rooster crowing in the fog, and a little comic relief. Like the bats they catch nobody: run or
    sprint near them, or walk upright close by, and they explode in a squawking, flapping panic (some flying, feathers
    everywhere), and the racket calls every hunter within 40 m. Creep past crouched. Run into one and the rooster
    flies into a rage (after Zelda's cuccos): the flock mobs you, leaping and beating round your head, pecking,
    slowing you, calling the hunters all the while, until you get away.
  - **Gargoyles** ("and a Gargoyle enemy"): a carved-stone grotesque, alive, bat-winged, of the walls' own weathered
    concrete. It crouches as a statue on a ledge over a hall (a terrace's edge, a wall top low enough to be seen, or
    a stone corbel jutting from the wall), and cannot be told from a carving. Pass beneath it and it stirs (a faint
    ember in its cracks and eyes, its head grinding round to follow you, dust trickling off it), then drops in a long
    glide onto where you were going, its shadow darkening where it will land: keep moving, or turn aside, and it
    misses. A miss turns it to stone where it lands for a few seconds: the time to get away. Then it hunts in heavy
    bounds a little slower than a run, slow to turn (a turn down a side passage gains ground), and from a few metres
    in front of you winds up (wings raised, a snarl) and leaps. Lost, it beats its way back up to its ledge.
  - **The herd** (added 2026-10-18, "lets add deer and elk as well"): white-tailed deer standing in a hall, real at
    first glance. When they see you every head comes up and turns to you, and they freeze, staring, too long, eyes
    giving back the light. Look away and they are a little closer when you look back (they never come within 12 m).
    Come near (9 m) or run at them and one snorts and stamps, the tails go up white, they stot off on stiff legs and
    break into a stampede down the passages away from you; if the only way out is past you, it comes straight back
    down the hall at you, and a deer that runs into you knocks you down (caught). The alarm and the stotting are the
    warning, nearly two seconds: stand aside. One in a herd of four or more is wrong: legs a little too long, a head
    that turns round further than a neck should; now and then it stands up on its hind legs and takes a step towards
    you; it never runs with the others, and stays watching you as they go.
  - **The bull elk**: taller at the shoulder than the boy, holding a stretch of halls as his own. On his ground and
    in his sight, he faces you and bugles (an eerie rising scream, steam pouring from his mouth: the first time
    only), paws the ground and lowers his antlers, then charges faster than anyone can run. For an instant he can
    still swing at you; then his line is set and he can hardly turn. Step aside into a side passage or behind a
    buttress, climb, or leave his ground; standing in his line, you are caught. He runs on past, stands blowing,
    turns slowly and comes again.
  - **Tiny imps** (added 2026-10-18, "add tiny imps and imp swarm"): knee-high devils, sooty red-brown, pot-bellied,
    bat-eared, needle-toothed. Gangs of three or four perch head down on a wall face like gargoyles, chittering. They
    pester rather than kill: noticing you, they cackle, scurry down the wall and scuttle after you (faster than a run,
    slower than a sprint), leap on and cling (back, thigh, shoulder). Each one on you holds you back, and its cackle
    tells every hunter nearby where you are (they fetch bigger things). Three on at once for a moment bring you down.
    A jump or two shakes them off; a roll, slide or dive throws them all off; thrown off, one tumbles and throws a
    tantrum before it comes again. They give up when they lose you and climb back to their perch.
  - **Crows** (added 2026-10-18, the user: "add crows /ravens and blue jays"): murders of seven to thirteen American
    crows sitting along the edges of the wall tops and ledges over a hall (the lowest ledges if there is room on
    them), side on, looking about, preening, shuffling, now and then a caw (a bow forward, tail flicked, bill wide).
    They are the maze's watchers. Walk in a hall below them, in their sight, and every head turns to you; as you go
    they follow along the walls in short flights, one after another, leapfrogging to keep over you (never far from
    home, never into the clearing). Walking calls nobody. Run near them, or sprint within a longer way, and the murder
    erupts cawing and wheels over you, following you round, and its cawing calls every hunter within 45 m to you,
    over and over, for about nine seconds; then they settle on the walls where they are, slow to go off again for a
    while. When something catches someone near them they rise and wheel over the place, cawing, for half a minute:
    a sign to everyone else. They catch nobody. Walk, do not run, under crows.
  - **Imp swarm**: a crack at the foot of a wall. Come near (or run near) and it chitters for a second, then dozens of
    imps pour out as a tide along the floor and up and along the walls. Those that reach you run up you and cling,
    slowing you; ten on you for a second and you are down. A roll throws them off; a sprint outruns them; getting up
    onto anything (a terrace, ivy, a vine) or out of reach and they give up and stream home, and rest before coming
    out again.
- **The colossus** (added 2026-10-18: "and a colossus", then "even bigger, crawl over the top of the maze, and
  try to use just 1 fingertip to crush you", and "more lanky and spindly"): what the maze might have been built
  for. A gaunt giant 260 m tall if it stood, after *Shadow of the Colossus* (and *Attack on Titan*'s giants over the
  wall): impossibly long thin arms and legs, knobbly joints, a narrow ribcage and hunched spine, a small stone mask
  of a head on a long neck with pale eyes, sparse slabs of weathered stone with moss, grass, vines and glowing
  runes, tatters of dark fur, long bony fingers. One crawls over each ring wide enough (the Avenues and the
  Galleries) like a spider, on the wall tops, never in the halls: its hands and feet come down only on wall tops of
  its ring, its elbows and knees bent high above, its body slung low over the maze, the halls in its shadow; dust
  and stones rain into the halls where a hand comes down. Its upper body is lost in the mist. It never crosses the
  clearing.
  - It hunts with one finger. Whoever it sees out in the open, it stops, bends its head down to peer between the
    walls, and holds its long index finger over them (its shadow growing on the ground, following slowly), then
    presses it down, grinds, lifts and tries again where they ran, four times at most; under the fingertip is
    caught. The finger cannot get into a slot, right up to the foot of a wall, or under a ledge. Lose it and it
    gives up and crawls on.
  - It sees from above whoever is out in the open in front of it; not in a slot, flat against a wall, under a
    ledge or bridge, or behind a wall from where its eyes are. Standing still halves how far it sees. Running hard
    near one of its hands or feet makes it stop and peer about.
  - Now and then, crawling beside the clearing's wall, it rears up, leans its hands on the top and looks over: from
    the clearing, a gaunt figure over the wall with two pale eyes. It cannot reach in.
  - Its limbs as ways up (riding it over the walls) are not done: see below.
  - **Coyotes** (added 2026-10-18 at the user's request, "there should be a coyote, and coyote skinwalker as well"):
    real coyotes, lean and rangy, grizzled grey-tan with a cream throat and belly, big upright ears, yellow eyes, a
    bushy black-tipped tail carried low. Packs of three to five trot about the halls, sniff, stand and stare. Mostly
    skittish: seeing someone they shadow them at a distance (about 15 m), stopping to stare whenever they look round;
    now and then the pack breaks into its yip-howl chorus. Come close or run at one and it gallops off and slinks back.
    One alone, or a pair, never does more. Only a pack of three or more round someone **alone** (nobody else within
    12 m) grows bold over about seven seconds: they circle, closing in low and snarling, a yip as the warning, and
    after a couple of seconds of it the one behind you darts in and snaps. Turn on one and it backs off; run at one and
    the pack loses its nerve; running gets away (they close in slower than a run); a friend coming near ends it.
    After a snap the pack scatters and is not bold again for a while. Tame coyotes live in the clearing too
    (ClearingStyle "Wildlife"): they stare, yip and run off, and are never bold.
  - **Skinwalker** (the internet-horror figure, kept to horror fiction): something wearing a coyote's skin, hidden
    in one of the packs as one of them. Look closely: it is bigger, its joints bend the wrong ways, its eyes shine too
    much, it never joins the chorus, and when the coyotes run from you it does not: it stares. From round a corner it
    calls out to you, a voice made in code (a "hey?", a "hel-lo", a coyote's yip turned human; never anyone's real
    voice). Look straight at it from close, or walk up to it, and it stops pretending: it freezes, turns its head to
    you and rises (the warning, nearly two seconds) onto long gaunt legs, the hide hanging down its back, the coyote's
    head a mask over a pale human face; its pack scatters. Then it runs you down on all fours in bursts: down flat and
    a jerk of the head (the wind-up), a burst far faster than a sprint, then it stops dead, twitching. Bursts need a
    straight line to you; out of its sight it crawls after you slower than a run. Turn corners, get up high (it cannot
    climb: it stands under you and gives up) or get into the clearing (it will not follow). Lost, it goes back to its
    pack. The first ring has two coyote packs and one skinwalker hidden in one of them.
  - **Tripod** (the user: "a giant 3 legged tripod enemy like from war of the worlds"; then "the tripod legs should
    be more fluid, noodly"): a Martian fighting-machine far taller than the walls. A low cowl of weathered bronze
    plate some 60 m up, half lost in the mist, a pale eye glowing in the dark under its brow; three long, whippy legs
    of segmented metal that coil up as they lift, swing high over the walls and uncoil to plant in the halls with a
    boom that shakes the ground; cable tentacles and a clawed grasper hanging under it; a heat ray on a jointed arm;
    red weed trailing off it. It does not chase: it patrols round its ring in great slow strides (slower than a
    walk), its searchlight crossing the wall tops and sweeping slowly down one hall after another. Lit in the open
    for half a second, you are found: its horn sounds, a deep, distorted "ULLA" heard across the maze (the warning),
    its light stays on you and its hood turns to you. Near under it, its grasper uncoils high over you and comes down
    slowly; get away or out of its sight and it draws back, stay and its claws lift you away. Further off, its arm
    swings round and the emitter charges (about two and a half seconds: it glows brighter and its hum rises); then
    the ray comes down the hall at you from well up it and burns along it through where you stood, drifting after
    you only slowly. Step out of its line, into a side passage or a slot, under a ledge or behind a buttress, and it
    burns past, leaving a black scorch with a glowing seam and steam rising off it. The walls cut its light and its
    ray as they do its sight: against the near wall, under a ledge, in the ivy, you are hidden. One in a ring at
    most (it is huge); the first ring has one.
- How many of each a ring has is its style's rule (MazeStyle, "What hunts it"); the first ring has some of every
  kind. The dev panel puts any of them in ahead of you.
- None enters the clearing. Caught, a player is put back in the clearing. Once out, nobody is hunted.
- With friends, the room's maker runs them; everyone else sees copies.
- **Solid** (2026-10-18, the user: "the enemies should have collision"): the boy is stopped by a hunter's body as by
  a wall (layer 4; copies run by another machine on their own layer, MazeEnemy.PUPPET_LAYER, so a guest is stopped
  by them too). Swarms, flocks and the giants stay passable.
- **Up is not safe from everything** (2026-10-18, the user: "more creatures should be able to climb things"): a
  hunter that climbs (MazeEnemy.climbs) goes up after a player who is up on a ledge, a terrace, a concrete bridge or
  a catwalk (or on the ivy up to one), each in its own way: the panther and the deinonychus leap (a crouch, a bound,
  the rest clawed up), the masked tribe, the clown (only unwatched), the gnomes and the mushroom zombies (slow, slipping
  back) climb hand over hand, lizard people, imps, the mantis (near its post) and the giant ants cling to the face,
  rat swarms pour up a ledge's front to whoever is at its edge, and the psychic child floats up after whom she
  follows. They come along the top and catch, and come down when you do. The lynx (shy), the wolves (they pace
  below), the giants, swimmers and grazers do not climb; a vine, a rope bridge or a wall top is still safe.
  `scripts/enemies/high_ways.gd` (HighWays: the surfaces of a zone, made once from its layout) and `high_climb.gd`.

### The added hunters (2026-10-18)

- **Clown**: a horror clown, too tall and too thin, stained baggy suit and ruff, a greasepaint mask with a painted
  grin, one red balloon floating just over his head (the only colour near him). He stalks whoever he has noticed to a
  music box, slower than a run, and is only ever still when someone looks at him (frozen mid-pose, the head tilting).
  Within 10 m, unwatched, he giggles (look at him then and he stops), then sprints in flailing stop-motion at 8 m/s for
  2.3 s and stands winded. Touching him catches. The reverse of the angel: watched, he is harmless.
- **Stegosaurus**: Stegosaurus stenops at its real size, a grazer in the wide halls (sometimes with a calf), often
  across the hall. It barely notices anyone creeping; within about 7 m of its body it turns side on, rumbles and raises
  the thagomizer (2.6 s), then swings it low: whoever the spikes hit is thrown and caught. It never chases.
- **Spider monkeys**: troops of four to seven hang by their tails from a vine they string about 6 m up a hall's
  walls, still and dark. They stir and swing along over you; pass under one and it shrieks (0.6 s) and drops at where
  you will be: walking or running you are landed on, a sprint carries you past. A miss and it chases briefly, then
  climbs back.
- **Lizard people**: bands of two or three, reptile men clinging head down to the walls over a hall, tasting the air.
  They skitter along the face beside you and climb after you; they hiss and fan the dewlap, then leap at where you
  were (keep moving and they miss). On the ground a little faster than a run. Cold-blooded: by night or in rain slow
  enough that a run escapes.
- **The masked tribe** (the user: "natives with masks and spears"; a fictional feral tribe of the maze's own lost
  boys, after Lord of the Flies, not any real people): parties of three to five boys, clay-grey, in rags, each face
  behind a crude carved mask of wood, bone or bark, each with a stick spear. They camp round a skull totem in a dead
  end and patrol in file; one drums and chants on seeing you and they hunt at a run (a sprint gets away), fanning
  out. One at a time draws back with a yell (0.85 s) and throws where you are going (ducked, it goes over); close to,
  they jab. They cannot reach anyone up high.
- **Deinonychus**: packs of three or four, feathered and as the bones say. One holds off about 9 m, crouched and
  clicking, while the others go round by loops of the halls to cut you off; then all burst faster than a sprint for
  about two seconds and tire. Close and facing you: a crouch, tail flick and hiss, then a pinning leap (step aside and
  it stumbles). They cannot climb: up high you are safe.
- **Pterodactyls**: Pteranodon-like, 6.8 m across, soaring over the rings and roosting on high wall tops. They hunt
  anyone in the open: a low pass with its shadow and a croak, then a dive with the roar of the wind, feet forward; its
  line is set the last half second (step aside). Caught, you are carried off. Not into a passage under 9 m wide, or
  under anything.
- **Wyverns** (the user: "wyverns"): two-legged dragons, 9 m across, in pairs nesting on a high wall top in the  outer rings (a nest of sticks and bones), soaring over their territory. Anyone who climbs near the nest is gone for  at once; otherwise they hunt part of the time, anyone in the open. Warnings: the scream and the shadow. Then a dive  (feet forward, its line set the last half second: step aside; caught, you are carried off) or it lands in the hall  and stalks you on wrists and feet, slower than a run, and lashes with its barbed tail after a plain coil-back with a  hiss (run out of reach). Not into passages under 10 m wide, or under anything. Hungry, they carry prey to the nest.
- **Giant snail**: a land snail as big as a car, slower than a walk but relentless; it climbs walls and over the tops
  after anyone up high, and its slime trail lies two minutes and holds you back to less than its speed. Touching it
  catches; it pulls into its shell when bumped or when it loses you.
- **Hydra**: a heavy, low reptile body with seven serpent necks, sunk in a black marsh pool of its own across a hall.
  Awake, its heads weave and watch; anyone within about 8.5 m is struck at: a head coils back and hisses (0.75 s), then
  darts, up to three at once from different angles. Sprint and swerve past, or slip by behind it. A head cut off (act,
  near it) falls, and two grow back.
- **Gibbons**: troops of three to five living high on the ledges, terraces and wall tops (past the first section),
  swinging under the edges and flying the gaps. On the ground you are safe but seen: the great call fetches every
  hunter within 40 m. Climbing near their ways you are prey: one winds up shrieking and swings at you feet first; get
  down or away from the edges first.

- **Screaming bear** (the user: "annihilation bears"; an original creature in that spirit): a huge bear starved to
  the bone and changed, legs far too long, half its face bare skull with a clouded eye, no lips. It cries out with the
  voice of the last thing it killed ("help!", "no, no, no!", sobbing; made in code, the same every time), which
  carries far: you hear it long before you see it. It stalks slower than a run, calling; in a line within about 13 m
  it rears and screams (about 2 s), then charges faster than a sprint, briefly, and swipes. Caught, you are mauled and
  it takes your voice. Climb out of reach, break its sight, never go toward the voice.
- **Brachiosaurus**: life size, 13 m tall, roaming the desert and the wide round halls and browsing at the walls; a
  gentle landmark, dangerous only underfoot: each foot lifts slowly over a darkening spot where it will land, the
  ground shakes near it, and whoever is on the spot is crushed. Walk under its belly or clear of the spots.
- **Dimetrodon**: a 3.4 m sail-backed synapsid basking side on to the sun in wide halls and the desert, cold-blooded
  (slow at night and in rain). Come near and it rises gaping and hissing, then lunges; it chases slower than a run.
- **Griffinflies** (the user: "a giant dragonfly"): Meganeura 1.4 m across, four wings each beating on its own, in
  pairs over a stretch of halls. One hangs in front of you at head height, warns for a second (legs out in a basket,
  jaws open, wings clattering) and strikes through where you were: duck or step aside. Hit, you are knocked down, not
  caught; two harrying someone alone catch them.

- **Psychic child** (the user: "not necessarily hostile but dangerous", then "should have telekinesis and protect you
  from hostiles"): a small barefoot girl in a washed-out hospital smock, a blank mask face, drifting a hand's breadth
  off the ground humming, debris circling her. She hunts nobody; come slowly and stay calm by her and she follows you.
  Anything that comes after someone calm near her she takes hold of with her mind (arm out, the air warped, a
  nosebleed): lifted, held, then killed, flung or shoved back by its size. Each hold costs her; several in a row, a
  sprint near her, a bump or a loud thing frighten her, and after a warning (warp, racing debris, ringing, hands to
  her head) she bursts: everyone within 10 m thrown, whoever is right by her caught. Then she sits drained.
- **Lynx**: shy, it watches from the ledges and slips away, hunting the small animals; cornered or at its kill it
  hisses, then swipes. **Black panthers**: stalkers on the ledges and from behind, strongest at night (eyeshine, a
  low growl, the wiggle before the spring); face one and it hesitates and gives up; turn your back and it pounces;
  run from it close and it chases briefly faster than a sprint.
- **Grey wolves** (the user: "might as well add wolves"): packs of four to six with a den in a dead end, patrolling
  in file, howling together at dusk and through the night (other packs answer). They hunt by endurance: a trot slower
  than a run that never tires, others covering the side passages; they close in (low, snarling, a growl) only on the
  slow, stopped, cornered or long-hunted, then one bursts and grabs. Climb, stand by a fire, reach the clearing, or
  keep together: they wait for a straggler.

- **Giant octopus** (the user: "New monster: giant octopus"): mantle 2.5 m, arms 8 m, camouflaged in a black pool  against a hall's wall or a drain through a wall, one or two arms feeling along the floor and up the walls (curling  tips, rings on the water, a wet slither). Linger within an arm's reach and an arm rears and coils (about a second,  the skin blanching), then lashes where you were: a walk is caught, a run missed. It drags you to its water: four  jumps break its grip, or a friend's act cuts the arm (it inks, which blinds, and hides; the arm grows back). It may  crawl out after you, slower than a walk; from a drain it pours itself through the wall.- **Moose** ("Moose"): unpredictable at its own wallow: a cow charges anyone near her calf, a bull in the rut whoever  he sees; ears back, hackles up, head-low stare first. The charge knocks you down and it rears: still in reach when  the hooves land, you are caught. **Woolly mammoths** ("wooly mammoth"): herds in the widest halls; they ring the  calf, the matriarch trumpets and mock-charges, then charges and tramples; step aside late, she is slow to turn.  Nothing hunts the giant plant-eaters (Ecology: size 4 plant-eaters are nobody's prey).
- **Carnivorous plants** (the user: "carnivorous plants"): giant real ones that never move. A Venus flytrap shivers
  at a touch (the warning) and snaps on whoever is still in it 0.75 s later; a sundew's sticky leaves slow you, then
  hold you a couple of seconds (jumping tears you free); a pitcher's slippery lip at a wall's foot takes whoever
  steps on it. They eat small creatures. **Mushrooms**: patches on walls and floors, bonnets glowing at night;
  puffballs puff spores when trodden or run near (the screen blurs and greys, you slow, the zombies hear).
  **Mushroom zombies**: boys taken over by a fungus, moved like puppets, clicking; blind, they hunt by sound only
  (running, sprinting, hard landings; walking only close; crouching never): they stop and listen (the warning),
  lurch slower than a run and lunge at the sound. A creature they take raises another from the ground.
- **Gnomes** (the user: "gnomes"): knee-high folk-tale gnomes, old and eerie, a band in a hollow at a wall's foot.
  Stock-still while anyone faces them; unwatched they creep up behind whoever has something in their pockets,
  snatch one thing and run home with it (catch one and it drops it; the hoard by the door can be taken back). Run at
  their hollow and two pull a rope across at shin height. They catch nobody; a lit torch keeps them off.
- **The weaver** (the user: "a four winged six-armed humanoid"): a tall faceless waxen figure, six arms whose hands
  never stop signing, four torn lacewing wings, drifting over the halls and weaving strands of shining thread across
  them at chest height. Walk into one upright and you stick; duck or slide under, or cut it with act. Stuck, it comes
  and lifts you away unless you tear free (mash jump or act) or a friend cuts you out.
- **Giant ants** (the user: "giant ants"): a colony of dog-sized carpenter ants, a nest in a dead end and a trail
  out along the halls. Keep off the trail and away from the nest and they let you be; tread on it and the alarm runs
  through them (they rear and click), and they pour out faster than a run: three holding you a second catch you; a
  sprint or a jump tears them off. They haul carcasses home. **Giant praying mantis**: 3 m, still among ferns by a
  hall wall, its head turning in jerks to follow you (the tell); within about 3 m in front it strikes faster than
  anything (ducking is no help); a miss leaves it still a moment to slip past.
- **Rats** (the user: "rats, rat swarms and rat kings"): mischiefs that run the wall feet and gnaw carcasses,
  fleeing; **rat swarms** in drains at a wall's foot that roar, then pour out like a river after you (stand in them a
  moment and you are caught; a sprint, getting two metres up, or fire saves you); the **rat king**, rats knotted by
  their tails dragging themselves slower than a walk, whose shriek calls every swarm near, bold and past the fire.
- **The luck dragon** (the user: "falcor like long dragon"; original): 35 m, pearly scales, white fur, a gentle
  hound's head, no wings, swimming through the sky over the outer rings and the desert. Stand still in the open and
  it comes down, lays its head before you and sings; climb onto its neck and it carries you over the walls further
  out. While it is down the hunters near back off. (The wyverns are still to come.)
- **Lonely horses** (the user: "there should be lonely horses as well, rarely"): one or two in the whole maze, each  alone, feral and a little thin, mane and tail long and tangled, an old rope halter on some. They wander the wide  halls and the clearing's edge, graze, doze, roll and shake, and now and then whinny; nothing answers. Wary: run at  one and it canters off; come slowly and stand and in time it lets you near; touch it (act, empty-handed) three  times a little apart and it trusts and follows you. A hunter near and it bolts. (Riding is still to come.)
- **Dogs and meat**: meat is cut from carcasses (act) and now and then found at camps; thrown, what eats meat goes
  to it. A dog fed meat (thrown near it, or held out) becomes the giver's friend: it hunts no player, follows at heel,
  barks at what hunts near and goes for what comes at its friend. Left far behind long, it goes feral again.

- **The woodsman and the beast** (2026-10-18, the user: "Lets add a woodsmen with an axe and top hat and lantern,
  and a the Beast inspired character from Over the Garden Wall"). In the mood of *Over the Garden Wall*, in the
  maze's greys. One of each in a section by default (MazeStyle "What hunts it": `woodsmen` and `beasts`, each with
  its box), none in the clearing; the monster multiplier makes three woodsmen of it, but there is never more than
  one beast.
  - **The woodsman** (`MazeWoodsman`, `creatures/woodsman/`): a tall, gaunt, weary old man in a long coat and a
    battered top hat, an axe over his shoulder and an oil lantern held out before him. Its warm light is the one
    warm thing in the grey and really lights the halls round him (one light, no shadows; none on low detail, only
    the glass and a halo), but not him: he stands dark against it. He walks the halls slowly (1 m/s), stops to
    look about, and now and then goes to the ivy at a wall's foot (or a bare wall) and chops at it, three blows.
    He is not a monster and not a friend. **His light keeps the hunters back**: whatever goes about the maze short
    of the biggest (Ecology's sizes under 4: mummies, dogs, the tribe, the wolves...; not the giants, swarms and
    flocks) cannot go after anyone within 7.5 m of him. **But he is wary of strangers**: come within 11 m and he
    stops, turns, holds his lantern up at you and grunts (the warning), then goes on, watching you. Come within
    3.4 m, or run at him, and he comes after you (2.7 m/s, slower than a run) and, within reach in front of him,
    raises his axe high over his head (0.8 s, the warning) and brings it down: still in front of him, you are
    caught. Then he turns away and lets everyone be for seven seconds. So walk near him, in his light, but give
    him room. **He hunts the beast**: seeing it within 30 m, he turns on it, holds his lantern up and strides at it.
  - **The beast** (`MazeBeast`, `creatures/beast/`): a tall shadow (about 2.8 m, its antlers over that), black,
    great branching antlers like dead boughs, two pale burning eyes, and a lantern of its own glowing faintly.
    Rare and **mostly unseen**: hidden (not there at all) most of the time; every 14 to 34 s (sooner in the dark)
    it shows itself to the nearest player in its section, alone best (nobody else within 18 m; runners count as
    company): it steps out of a side passage they cannot see into a straight hall at the far end from them (or,
    with none, is simply there, far enough off that the mist hides its coming) and stands there, a silhouette, eyes and lantern faint. By day 38 to 52 m off and less often; at night or in rain
    and mist 18 to 30 m; with company further still and seldom. **It lures whoever is alone**: its lantern held up
    and out at them, brightening and swaying, and a low hum, a tune of its own, carrying down the hall; it comes on
    very slowly (0.75 m/s), and whoever it lures, on the ground in its sight, is drawn towards it (0.55 m/s, less
    than a walk: walk or run away and you are free of it). **If it reaches you** (2.6 m) it draws its long arms up
    and out (about a second: the warning; the hum stops, its eyes flare, wood groans) and closes its hands: still
    within 3 m, you are taken into the dark (caught: back to the clearing). It goes (back out of sight, then gone)
    when someone with company comes to it, when the one it lures gets away or out of its sight, or after it has
    watched a while. **It cannot abide the woodsman's light**: it never shows itself within 24 m of him, flees one
    who comes within 16 m, and lures nobody in his light.
  - Online: run by the host; guests' puppets show what they do (the woodsman's chops, warnings, swings and his
    lantern raised; the beast there or gone, luring, reaching), and whoever the beast lures on a guest's machine is
    drawn towards it there. Neither hunts the others nor is hunted (Ecology: the woodsman size 2, the beast 4,
    eating nothing).

### The maze lives on its own (2026-10-18, Ecology)

The user: "they should also interact with each other. We should have world game manager ... like a Rain World or
Kenshi kind of sim ... relatively simple". scripts/ecology.gd, run where the hunters are (alone, or the host):
- Every kind that takes part has a size (0 a hen to 4 the biggest) and a diet (Ecology.KINDS). Meat-eaters grow hungry
  over about five minutes; hungry and after no player, they hunt the nearest smaller creature they see (or one as big
  that eats only plants), never their own kind. Catching it kills it: a carcass where it fell (the flies come), and
  the killer eats a while. Players still come first.
- What could be eaten runs from a meat-eater near it that is after it or hungry.
- Out of everyone's sight the creatures still go on their ways, and a hungry one may kill sleeping prey it comes on:
  the maze is not as it was left.
- The dead come back after three minutes at their dens (where they began), once nobody is within 150 m.

## Who else is in the maze

Added 2026-10-18 at the user's request ("npc runners"): other boys in the maze, after the Gladers' Runners, run by
the computer. They are the same boy as the players, on the same controller and rig, in muted shirts no player has, so
they read as others but plainly the same kind of person. Each knows his own section (ring) and stays in it.

- **They run it.** They jog its halls from place to place, down the middle of the wide ones, and now and then climb
  some ivy to look about and come down again.
- **They are hunted.** Everything that hunts the maze hunts them as it would a player. They see it coming and sprint
  (as fast as a player's sprint, near enough) to where it cannot get first: the clearing best, or up ivy they will
  reach before it. Caught, a runner is struck down and is back in the clearing, sitting, as a caught player is; then
  he jogs out to his section again.
- **They draw hunters away.** Sprinting, a runner is loud: anything hunting that sees him near turns after him if he
  is nearer than what it was after, so one sprinting past pulls the pack off you. And one who sees a player hunted
  near him waves both arms over his head (no voice: gestures only) and the hunter takes after him instead; not
  often (half a minute between).
- **They lead.** Come up to one (a few metres, in sight) and he stops, faces you and beckons, then runs (not
  sprints, so you can keep up) for the gate out of his section; fall behind and he stops and
  beckons again; lose him and he gives up. At the gate he stands aside and points through it, and goes back to his
  running. He leads one section at a time, never all the way out: the next section's runners know theirs. Then he
  will not lead again for a while.
- **How many**: a ring's style says (MazeStyle, "Who else is in it"); two in each for now. Few, since each poses a whole
  boy, and none is posed when far from the camera.
- With friends, the room's maker runs them; everyone else sees copies driven by the same inputs, so they climb,
  sprint and gesture alike.
## Wildlife

Not everything that lives here hunts (added 2026-10-18: "there should be non hostile regular deer and elk"). Herds of
ordinary white-tailed deer (a buck, does, spotted fawns) and of elk (a bull, cows, calves) graze out in the clearing's
meadow, towards its corners and the edges of the woods (never the middle where everyone wakes, nor the ways to the
gates), and a few stand in the halls. They graze and wander, lift their heads to watch you come, flick their ears
and tails, and run off when you come near (deer stotting a few bounds with their white tails up, then away at a
gallop; elk trotting, then galloping), and settle to graze where they stop; a bull bugles now and then far off. They
catch nobody and are nothing to be afraid of, which makes the ones that are wrong worse. How many: ClearingStyle and
MazeStyle, "Wildlife". Each machine runs its own copy from the round's seed, frightened by the same players, so they
agree.
## Wildlife
- **Foxes, frogs, rabbits, hares and jackalopes** (2026-10-18, the user: "regular frogs ... foxes", "rabbits, hares,  jackalopes"): the life of the place and what the hunters eat. Red foxes follow at a distance, sit and watch, slip  away, carry off things lying about and pounce for the small things (tame ones in the meadow). Frogs sing round the  marsh and little ponds at dusk and in rain and plop into the water as you come near. Rabbits graze round their  warrens and bolt down the holes, thumping; hares lie flat, then explode away jinking; the rare jackalope stares,  and butts whoever comes too near (knocked down, not caught).

Not everything in the clearing and the maze is a threat. Added 2026-10-18 at the user's request ("there should be
non hostile regular deer and elk and chicken as well. Some should be in the clearing"):

- **Birds** (added 2026-10-18, the user: "add crows /ravens and blue jays"). Real anatomy and a real wingbeat (the
  wing straight and fingered on the downstroke, folded at the wrist on the upstroke, a flick at the top), take-offs
  with a jump, glides, banking, landings with a flare; their calls are made in code.
  - **Blue jays**: families of three to six in the pines at the edge of the woods nearest the middle (ClearingStyle,
    "Wildlife"): vivid blue, barred black, white below, a black necklace, crested. One of the very few colour accents
    in the near-colourless clearing, so they are small and few. They flit from branch tip to branch tip and tree to
    tree in bounding flights, drop to the ground in front of the trees to hop about and peck, and fly back up;
    "jay! jay!" with a bob and the crest up, a squeaky "queedle", and now and then (as real jays do) a red-tailed
    hawk's scream. Walk in under their trees and they gather on the branches over you and scold, crests up; run
    through those on the ground and they go up into the branches. Something that hunts near the trees, they scold
    too: a tell.
  - **Crows in the clearing**: a small flock in the treetops of a stand by the woods, walking (with the crow's
    swagger) and pecking in the meadow in front of it. Walk near and those on the ground fly up into the trees; run
    at them and the whole flock goes up cawing, wheels over the trees and settles. They call nobody.
  - **Ravens**: a pair (or one) on the wall tops of a ring (MazeStyle, "Wildlife"): a third bigger than a crow, a
    wedge tail, a shaggy throat, a heavy bill; deep croaks and hollow knocking. An omen: when someone comes near and
    something that hunts waits in the halls ahead of them, the ravens fly ahead, croaking, to sit on the walls over
    it, and stay there while it stays. Those who notice where the ravens went know what lies there.
- **Tame chickens**: ordinary farmyard hens and a rooster that forage, cluck and crow. Run through them and they
  scatter a few steps, squawking, and settle; walk near and they edge away. They never call the hunters and never mob.
  The clearing has a couple of flocks (ClearingStyle, "Wildlife"), the first pecking at the edge of the woods, all well
  away from the middle and the paths to the gates; a ring can have some in its halls too (MazeStyle, "Wildlife", none
  by default). Placed from the round's seed, so everyone in a room sees the same flocks.
- **Fireflies** (the user: "fire flies"): at dusk and through the night clouds rise from the clearing's tall grass,
  woods, marsh and meadow, and from the ivy and the walls' feet in the maze: cold yellow-green, three kinds each
  blinking in its own rhythm (one in waves all together); they scatter from anyone running through and drift back.
- **Insects** (added 2026-10-18: "moths and flys", "dragon flys"). Mostly atmosphere, and a tell or two:
  - **Moths**: pale, dusty moths fluttering erratically in clouds round every light in the mist: the angel's burning
    heart, fires and torches, the pale light past the exit; they blunder into the light and bounce off it, and a few
    rest on the wall by it and scatter as you come. Big ones (luna moths, death's-head hawkmoths among the plain ones)
    rest on the walls of the halls with their wings spread flat, and burst off as you pass, flutter about and settle
    again. At dusk and through the night clouds of them come out over the clearing's grass.
  - **Flies**: buzzing clouds of blowflies (red eyes, metallic blue-green bodies) round anything dead or of meat: the
    flesh mounds, the meat beast, the slime wall, carcasses lying in dead ends, the boar's lair; and for a while
    wherever someone was caught. Their buzz carries a few metres: flies mean something dead, or something of meat, is
    near. Stand still among them and a few land on you and crawl on your head and shoulders until you move.
  - **Dragonflies**: over the marsh, in patches along its pools: darting fast and straight, stopping dead to hover,
    turning at right angles, perching on the bulrushes' tips with their wings held out flat; blue-green, the one
    colour in the grey. They take off as you come near.
  - They catch nobody, call nobody, and nothing about them is sent between players: each machine makes its own from
    the round's seed. How many: MazeStyle "Wildlife" (moths per light, big moths on the walls, flies per carrion,
    carcasses in dead ends) and ClearingStyle "Wildlife" (dragonflies over the marsh, moth clouds at dusk). Each swarm
    is one draw, and is drawn and moved only near the camera.

## What lies about

Added 2026-10-18 at the user's request ("there should be grappling hooks, backpacks, spears, torches to find, and
other abandoned loot through the clearing, and abandoned (or occupied) campsites"). Others were here before you, and
left things behind. **They are tools to get away with** (pillar 2): a spear buys a moment; a torch keeps the small
things off; a flare sends them looking elsewhere. (What there is to fight with came later: "Fighting back", below.)

- **Grappling hook.** Out of your hand with the act button at the lip of a ledge in reach above you (a mezzanine, a
  terrace, the platform under a sewer pipe, a vine's corbel: any ledge's edge the hook can feel for, up to about 13
  m: never the wall tops, which stay out of reach but by the routes of hook spots), at a hook spot (rings, hooks and
  pipes: "Ways up"), at a vine (wrapped round it, you are hauled in to it and hold it), or at anything marked as a
  grapple point. It bites, you swing on
  its rope and climb it, and at the top pull yourself over the lip. A big new way up, but its rope frays: six catches
  and it parts.
- **Backpack.** Worn as soon as it is taken: room for four things instead of two. Full, it slows you a little.
- **Spear.** A sharpened sapling with a shard of iron lashed to it. Thrown (act), it staggers the first thing that
  hunts it passes near: knocked back a couple of metres, rocking, for three seconds, and it catches nobody in that
  time. Then it comes on again. It lies where it fell, to be taken up again. The swarms are not staggered by it.
- **Torch.** A stick with a head of pitch-black rag. Lit when taken into the hand (put away, it is snuffed), it lights
  the halls round you (its own light and flame, GameCommon's fire) and burns for four minutes, low for the last half
  minute, then is out. The swarms (beetles, the imp swarm, the frog swarm) fear fire: within five metres of a burning
  torch, in a hand or lying where it was thrown, they will not come at you, and give up and go home. Held to a cold
  campfire it lights it; a burnt-out torch held to a burning one is lit again.
- **Flare.** A road flare. Thrown, it is struck: a hard red light for 45 seconds, and what hunts within 45 m and is
  after nobody goes to see; when it lands, what is chasing someone further off than the flare is drawn off too.
  Dropped, it is not struck.
- **Map scrap.** A page torn from an exercise book: read (from the inventory), it shows the halls round you in
  pencil and the way to the gate out of where you are (the clearing's nearest gate, or your section's way out) for a
  few seconds, and crumbles. There is still no map.
- **Rope ladder.** Hung (from the inventory) standing at the edge of a drop of 2.4 to 16 m, it hangs from there to
  the ground: a way down, and back up, for everyone, for the rest of the round.

Each lies in the grass or the mud with a small glint now and then off it (wet metal, a bit of glass), never lit up like
a prize. The act button near one takes it (the boy stoops for it); "E TAKE THE TORCH" at the foot of the screen says
so. Two slots, four with a backpack; tap a slot (or 1 to 4; on a pad the d-pad and Y) to take a tool into your hand or
put it back, or to read a map or hang a ladder; DROP (X) puts it down. With something in your hand you cannot take
hold of ivy or a vine, so walking into ivy puts it away for you. Held, a torch is held up, a spear carried point up
and levelled over the shoulder to throw, the hook's coil hangs from the hand; the backpack is worn.

**Where (the rules, ClearingStyle and MazeStyle "What lies about"):** in the clearing, a set number of each (one hook,
backpack, flare, map and ladder, two spears and two torches by default), among the edge of the woods, in the tall
grass, by the pond and out in the field, never within 40 m of the middle where everyone wakes nor near the ways from
the middle to the gates; the grass is trodden thin round each. In the maze, six in each square section's halls, in the
ends of halls first (the cells with the most walls), never by its gates; mostly flares, maps and torches. More lie by
the camps. Placed from the round's seed: everyone in a room finds the same things in the same places.

**Together:** only the room's maker says who gets what (a guest asks); taken, it is gone for everyone. What anyone
holds is seen in their hand; what is dropped or thrown is seen to fall and lie; torches lit and out, campfires lit and
ladders hung are seen by all. A guest's spear asks the maker to stagger what it hit.

## Fighting back

Added 2026-10-18 at the user's request ("sticks, bats and swords to use, and rarely guns and very little ammo"). They
lie about with the rest (taken, held, dropped and shared the same way) and are held in both hands, as Outside's boy
holds a bat. With one in your hand and something that hunts within seven metres, the act button fights instead of
taking what is at your feet.

- **Stick.** A branch broken off a tree. Common. Swung (act), it staggers the first thing that hunts in front of you
  for about a second, barely shoving it, and snaps after three to six blows that land.
- **Bat.** An old baseball bat. Staggers for two seconds and knocks it well back (four metres or so); splits after a
  dozen or more blows.
- **Sword.** An old straight sword, rare. The best: staggers for three and a half seconds, cuts through everything in
  its sweep, never breaks.
- A blow cannot hold a hunter down: one still reeling, or come out of it within a second and a half, is only knocked
  on a little. The swarms are not hit by a blow, nor by a shot.
- **Revolver** (six rounds) and **shotgun** (two, held in both hands): rare, and found with only one to three rounds
  in them. Act brings it up and fires. A shot fells what it hits for good (it goes over, lies, sinks into the ground
  and is gone for the round) if it is one of the ordinary hunters and near enough (the revolver 30 m, the shotgun's
  spread 11 m); the great and the unnatural (the snake, the colossus, the tripod, the angel, the gargoyle, the slime
  wall, the flesh mounds, the meat beast, the centipede, the skinwalker, the Griever) and anything further off are
  only staggered for five seconds. A shot is loud: everything that hunts within 90 m comes to see where it was, and
  within 40 m it knows who fired.
- **Rounds** and **shells**: a box of two to four, rarer still than the guns. Taken, they go loose in your pocket (no
  slot) and load an empty gun of their kind; the HUD shows what is in the gun and what is spare while you hold it.
  Empty, with nothing spare, it clicks.

**Where (the rules):** MazeStyle "What lies about": stick, bat and sword weights against the rest of what lies in its
halls (3, 2, 1 by default; no swords in the first section, more in the third), `gun_chance` (each thing is a gun 4% of
the time; 3% in the first section, 6% in the third), `shotgun_share`, `rounds_in_gun` (1 to 3), `ammo_chance` (2.5%)
and `rounds_per_box` (2 to 4). ClearingStyle: three sticks and a bat in the clearing, a 15% chance of a gun lying
somewhere in it and 8% of a box, and their own small chances by the camps. Camps left behind also have sticks and bats.

**Together:** a swing is seen by all; a shot is seen and heard by all where it was; rounds left in a gun go with it.
The maker staggers and fells (a guest asks), and everyone sees the felled one fall.

## Camps

- **Left behind** (three in the clearing, one in each square section's halls): a cold ring of stones round a bed of
  ash and charred stubs, a lean-to of tarp over a ridge pole on forked sticks (sometimes fallen in), bedrolls laid out
  or rolled, a log to sit on, a pot, a broken crate, a sack, sticks and stones scattered; in the clearing often a post
  with tally marks cut in its board, in the maze tallies scratched on the wall at the end of the hall. Sometimes a
  struggle: the lean-to down, the pot kicked over, two furrows where something was dragged away. A thing or two of what
  lies about is left by each. Hold a lit torch to its fire to light it: a fire ward of seven metres, for good.
- **With people at them** (two in the clearing, the first at the edge of the woods): the same, kept, a fire burning
  with its light, and smoke going up high enough to be seen from far across the clearing, so you can find them. Two or
  three runners rest round the fire between runs (one asleep on a bedroll): the same boy as everyone, in runners'
  shirts. Come up and one looks up and points you to what is worth taking lying near the camp (or beckons you in to
  the fire if there is nothing). Nothing hunts in the clearing, so they are never hunted there.
- The ground round a camp in the clearing is trodden: the grass worn thin, raggedly, never bare.

## Signs of life, and the sewers

Added 2026-10-18 at the user's request ("vents and sewer props on the walls and floor", "Zone 1 set up with signs of
abandoned life: camps, boxes and barrels, wires hanging above in the vines"). `MazeProps` (`scripts/maze_props.gd`)
lays them out from the seed as PROP and WIRE pieces (editable in the maze editor, in Props and Wires), by each
section's MazeStyle:

- **Sewers** (every square section, fewest further out; in the Inspector's "Wall decor" and "Tunnels" groups): old
  vents high on the walls (louvred or round, some great ducts), barred culverts at their feet with a puddle in front,
  small pipes with a rust stain down the wall and a puddle under them (some dripping), drain grates by the walls and
  manhole covers out in the halls (now and then pushed half off the black shaft).
- **The sewer pipes' mouths** (2026-10-19: "the sewer tunnel entrances should have modeleed funnel entrances rather
  than just square terraces"): where a pipe comes out of a wall it flares into a bell of concrete, like a culvert's
  outfall, its rim worn round, standing on a lip that juts out under it (flat on top, so he stands at the mouth; its
  front edge rounded over, its corners round, its underside a cove curving back down into the wall). The ledges'
  concrete, weathered as they are, with a tongue of dark slime run out over the lip, mossy at its edges, and the
  drips falling off its front. The lip is where the square platform was: the ivy still comes up to its front, vines
  hang from it, a hook ring may hang at it, and he ducks and crawls in through the bell.
- **Signs of life** (the Avenues): three camps left; heaps of boxes and barrels against the walls (solid, some
  stacked, a barrel fallen over); old black cables strung high across the halls, some snapped with their ends hanging, now and then a dead lamp; cables looped
  along walls on brackets.
- All weathered and dull, kept clear of the ways up (ivy, terraces, pipes), the gates and each other; the camps and
  what lies about keep off the heaps. Drawn as a MultiMesh a kind per 140 m square (cables merged into one mesh a
  square), gone past 110 to 160 m; nothing processes (drips fall in their shader). `tests/props_test.gd`,
  `tools/props_shots.gd`.

## Playing together

- Alone, or a room for up to four: make a room, share its four-letter code, the maker starts. The maze comes from
  the room code and the round, so nothing about it is sent.
- **Proximity voice** (web): talk with the MIC button (or V), off until you turn it on. Full volume within 4 m,
  silent by 30 m, heard from where the speaker is, muffled through walls. Peer to peer (WebRTC), set up through the
  room.
- A round ends when everyone is out; the maker calls the next maze.
- Score (sent to the arcade): 10000 less the seconds it took to get out.

## Performance rules

- Target phones in a browser (GL Compatibility, WebGL). The web .pck must stay well under GitHub's 100 MB limit
  (textures capped at 1024).
- Anything simulated per object (vines, rope bridges) must rest when still and nobody is near; never simulate
  thousands of things every frame.
- Anything numerous and spread out (grass squares, trees) is updated only near the camera and only when it changes.
- Resting means not processing at all, not a check that returns early: thousands of early returns cost milliseconds.
  Ropes and bridges rest with `Rope.rest` and one `Rope.Waker` starts those near anyone; ivy waits for one
  `IvyClimb.Grower`.
- Never loop over a big group (ropes, ladders) every step to find what is near: ask `NearIndex.near`. The boy's
  controller did that, so every runner cost ~4 ms and three made the frame rate fall to single figures. (The
  grappling hook's search, every third frame while it is held, asks it for grapple points, `GrappleSpots`
  squares, vines and strung vines; the spots are one MultiMesh per look per 48 m square and never process.)
- Never work out a whole-maze `MazeNav.field` in a loop: each is a walk of every cell, and only the last 96 are kept
  (the hunters share them). Walk only the few cells needed instead.
- `tools/frame_split.gd` (frame time and every processing script, per place) and `tools/runner_costs.gd` measure these.
- Check the first seconds too: no settling or warm-up work that runs for everything at once.

### Startup

A launch is the engine starting, every script compiled (about 4 s here: World and MazeEnemies reach all ~70 kinds),
the title over the menu's maze, then the round (`World.setup`) and its first frames. Rules for keeping it short:

- Count the things drawn, not only the triangles. Each MeshInstance3D (or MultiMeshInstance3D) is one more instance
  for the renderer to take in, and taking in tens of thousands at once costs seconds, more than in proportion. A
  thing made of many like parts is one MultiMesh, its parts the instances: a vine's or rope's links (`Rope`), a rope
  bridge's planks, ropes and posts (`RopeBridge`). The vines and bridges were 50,000 of the round's 55,000
  instances, and about 8 s of its start.
- Share meshes and materials among all the things of a kind (statics, made once), drawing a mesh of a metre as long
  as it needs to be, not one mesh each.
- Placing things apart (`MazeEnemies._far_from`) keeps how far every cell is from what is placed, adding only the
  newly placed; walking a field from every one placed so far, for each one more, was quadratic (about 2 s).
- Nothing set up at the start may change what is made, its order or the seeded choices: every copy in a room must
  build the same hunters in the same order (`MazeEnemies.enemies`) and the same loot from the same seed.
- Tests go straight to a round (`Main.testing`): no menu maze for them.
- Measure with `tools/start_times.gd` (each part of a launch; the flag `times` adds each stage of `World.setup`,
  `clearing` the clearing alone). Here, 1280x720: from about 35 s from launch to playing to about 22 s; the round
  from about 20 s to 11 s; the clearing alone about 2 s (7 s from launch). What is left: building the maze (about
  6 s: walls 2, the round sections 2, laying out 1), what hunts it (about 3.5 s, each kind building its look as it
  is put in, even those far off), compiling (4 s), the menu's maze (3 s) and the first frames (3 s).
- To test something in the clearing, play the clearing alone (`clearing`, or CLEARING ONLY on the title with dev
  tools on; `World.clearing_only`, `Maze.generate` with no rings): the clearing as ever, its first section only a
  narrow way round with nothing in it behind its gates, which stay shut, nothing that hunts and no runners.

## Not decided or not done

- Rings 2 and 3 (styles exist; not built or played yet), and what changes between rings beyond the style.
- Moving walls, doors that shut at night, a day/night cycle.
- A map, sound and music, player names. (A map scrap shows the way for a moment; there is no map.)
- Fighting back: a kill on a guest's copy is drawn falling only when the maker says so (a moment late); felled hunters
  are not put back during the round; the runners do not pick up weapons.
- Loot: a knife, a canteen or a whistle (thought of, not made); the hunters do not use the rope ladders; a friend's
  grappling hook rope is not seen by others (only them on it); the runners in the maze do not yet stop at camps (the
  ones at camps stay there).
- Enemies using the ways up (terraces, bridges, wall tops).
- Climbing the colossus: its limbs, fur and stone as ways up, riding it over the walls (the ivy's `Ladder` would
  have to move with a bone, and the character controller does not carry a climber on a moving body).
- Reconnecting mid-round past the server's 90 seconds; a relay (TURN) server for voice behind strict networks.
- Whether the score should reward helping friends out.
