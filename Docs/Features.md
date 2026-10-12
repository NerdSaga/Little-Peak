# Little Peak: Features Log

A running record of what has been built, where it lives, and which part of the [Game Design Document](GDD.md) it implements. Maintained by Pizza; send updates to Pizza rather than editing directly.

## Test Room (v0.1)

- **Status:** Draft, in [PR #3](https://github.com/NerdSaga/Little-Peak/pull/3) on `spaghetti/testing-scene`
- **Built by:** Spaghetti
- **Scene:** `GD Project/testing/test_room.tscn` (open in Godot 4.7 and press F6; click to capture the mouse). F5 still runs the main scene.
- **Files:** `GD Project/testing/` (`test_room`, `player/`, `npc/`). New input actions were added to the shared `project.godot`.
- **Verified:** Ran headless with no script errors. The HTML5 export has not been tested because there is no export preset yet.

### Built

| Feature | Details | GDD reference |
|---|---|---|
| Ground movement | Camera-relative running with a quick start, a slightly slower stop, slowdown uphill, and sliding on steep slopes | [4. Player Movement & Abilities](GDD.md#4-player-movement--abilities) |
| Jump | Variable height, coyote time, jump buffer, and a disc shadow under the player | [4. Player Movement & Abilities](GDD.md#4-player-movement--abilities) |
| Stamina climbing | Climbs gray rock, with a climb hop, letting go, an automatic mantle, and a drop when stamina runs out. Blue wet walls can't be climbed | [3. Core Loop](GDD.md#3-core-loop), [4. Player Movement & Abilities](GDD.md#4-player-movement--abilities) |
| Orbit camera | Spring arm. Recenters while running and pulls back while climbing | [5. Camera](GDD.md#5-camera) |
| Trail guide NPC | Wanders, turns to face the player, and gives the glide on the second conversation | [6. Progression](GDD.md#6-progression) |
| Glide | A slow fall with wide turns | [4. Player Movement & Abilities](GDD.md#4-player-movement--abilities) |
| Test geometry | A visible white peak, jump gaps, a gentle slope, a slide ramp, and a gate that forces the camera to pull in | n/a (testing only) |

### Deferred

- Long jump
- Footsteps
- Touch controls
- Options menu (invert and sensitivity are already exposed as settings)
- Viewpoint framing
- Stamina upgrades
- Campsites
- Swimming
- Updrafts
- Other animals
- Tumble animation
- HTML5 export test (needs an export preset)

### Notes

- `project.godot` is shared. Coordinate with Spaghetti before adding input actions.
