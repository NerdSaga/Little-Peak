# Little Peak: Features Log

A running record of what has been built, where it lives, and which part of the [Game Design Document](GDD.md) it implements. Maintained by Pizza; send updates to Pizza rather than editing directly.

## Test Room (v0.2)

- **Status:** In review in [PR #3](https://github.com/NerdSaga/Little-Peak/pull/3) on `spaghetti/testing-scene`
- **Built by:** Spaghetti
- **Engine:** Godot 4.7 (checked with 4.7.2)
- **Scene:** `GD Project/testing/test_room.tscn`. Open `GD Project` in Godot and press F6, or run `godot --path "GD Project" res://testing/test_room.tscn`. F5 still runs the main scene.
- **Reusable scenes:** `GD Project/testing/reusable/`
- **Shared files touched:** `project.godot` (new input actions, including `toggle_menu` on Tab)
- **Verified:** Ran headless with no script errors. A headless physics pass climbed the practice wall, was refused by the blue wall, took wings from the bird, glided, unlocked two campsites, and teleported to both. The HTML5 export has not been tested because there is no export preset yet.

### Reusable Scenes

See [GDD section 12](GDD.md#12-reusable-scenes).

| Scene | What it does | GDD reference |
|---|---|---|
| **Player** | Full moveset: run, jump, stamina climb, glide (locked until wings), orbit camera | [4. Player Movement & Abilities](GDD.md#4-player-movement--abilities) |
| **Climbable** | A collision body the player can grab | [4.3 Climbing](GDD.md#43-climbing) |
| **Unclimbable** | Same shape options; the player never grabs it | [4.3 Climbing](GDD.md#43-climbing) |
| **Wings Bird** | First chat (E) gifts wings and unlocks gliding. Lives in Zone 1 in the real game. | [8.1 Zone 1](GDD.md#81-zone-1-the-foothills-tutorial-decided) |
| **Campsite** | Press E at the fire to roast a marshmallow and unlock it; unlocked sites can be teleported to | [8.2 Campsites](GDD.md#82-campsites-decided) |

#### Configuring Climbable and Unclimbable

Both use `SurfaceBody`. Set these on the instance:

| Setting | What it does |
|---|---|
| `shape_mode` | `Primitive`, `Convex` (hull of the mesh), or `Concave` (trimesh) |
| `primitive` | `Box`, `Sphere`, `Capsule`, or `Cylinder` (ignored when `corner_mesh` is on) |
| `size` | Box: width, height, depth. Sphere: radius in X. Capsule and Cylinder: radius in X, height in Y. |
| `corner_mesh` | Builds an L shape. Convex fills the notch; concave leaves it open. |
| `albedo` / `roughness` | Look only. Blue with roughness 0.12 is the wet look. |

### Movement and Systems

| Feature | Details | GDD reference |
|---|---|---|
| Run | Camera-relative, quick start, slightly slower stop, slower uphill, slides on slopes past about 32° | [4.1 Run](GDD.md#41-run) |
| Jump | Variable height, 0.1s coyote time and jump buffer, disc shadow | [4.2 Jump](GDD.md#42-jump) |
| Climb | Jump into a Climbable to grab. Climb hop costs a chunk of stamina; Space + back lets go; automatic mantle at the top | [4.3 Climbing](GDD.md#43-climbing) |
| Stamina | Drains while climbing and gliding, refills on solid ground and at camps. Below 25% the bar flashes, the body pulses, and a gamepad rumbles. | [4.4 Stamina](GDD.md#44-stamina) |
| Glide | Hold Shift after the jump peaks. Slow fall, wide turns, slow stamina drain | [4.5 Gliding](GDD.md#45-gliding--other-traversal-options) |
| Camera | Spring-arm orbit, recenters while running, pulls out while climbing | [5. Camera](GDD.md#5-camera) |
| Campsite travel | Tab opens a travel panel; unlocked camps appear as buttons that teleport you and refill stamina. Three test camps: Trailhead, Switchback, North Camp | [8.2 Campsites](GDD.md#82-campsites-decided) |
| Falling | Falling off the pad returns you to the last camp you teleported to (or the start). No damage. | [7. Failure & Risk](GDD.md#7-failure--risk) |

### Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD | Left stick or d-pad |
| Look | Mouse | Right stick |
| Jump | Space | A |
| Climb hop / let go | Space while climbing; Space + back lets go | A |
| Glide | Shift (after the bird) | LB |
| Talk / roast | E | X |
| Travel menu | Tab (Tab or Esc closes it) | Start |
| Capture / release mouse | Click / Esc | |
| Hide help | F1 | |

Tuning defaults (speeds, stamina costs, camera distances) are listed in the PR #3 description and exposed as settings on the player and camera rig.

### Deferred

- Saving unlocked campsites between sessions
- World map (campsite fast travel uses a test panel for now)
- HTML5 export test (needs an export preset)
- Long jump
- Footsteps and dust
- Touch controls
- Options menu (invert and sensitivity are already settings)
- Viewpoint framing and fading thin occluders
- Stamina upgrades
- Swimming
- Glide updrafts
- Wet-grip and crampon unlocks
- Other animals
- Tumble animation; breathing audio (currently a visual pulse and rumble)

### Notes

- `project.godot` is shared. Coordinate with Spaghetti before adding input actions.

## History

- **v0.2:** Reusable scenes, the Wings Bird replacing the trail guide, campsites with travel, and Climbable/Unclimbable shape options.
- **v0.1:** First test room: movement, climbing, camera, trail guide NPC, and test geometry.
