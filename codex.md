# Never change exported variables of already placed nodes. Preserve their existing scene values in every change.

# Absorber project map

This document is the working index for future Codex changes. **Read it in full at the start of every user prompt before planning or changing the project.** After completing each prompt, update the relevant sections and append a concise entry to the prompt log below.

## Prompt maintenance protocol

1. Read this document before working on every prompt.
2. Keep the implementation sections accurate as part of the requested change.
3. Add the completed prompt and outcome to **Recent prompt log**; do not record secrets or irrelevant conversation.

## Project at a glance

- Engine: Godot 4.7.
- Main scene: `res://Scenes/world.tscn`.
- World unit: 64 × 64 pixel tiles.
- Input: left-click a painted floor tile to move the fox; click an enemy to chase it. Clicking a resource deposit opens its centered construction button; clicking a built producer opens capacity-building buttons on valid adjacent tiles. Clicking FoxAsha, FoxLio, or FoxNia routes the player adjacent; Asha opens the Store when no story conversation is due. Ground items are collected by stepping onto their tile, never by clicking them. Click or press Space/Enter to advance dialogue. Shift+0-9 saves, 0-9 loads, Shift+P fills every resource to capacity, Shift+O toggles the debug stat menu, and Tab opens the world map for campfire teleportation.
- Navigation: four-way `AStarGrid2D` with Jump Point Search enabled. It is built once when `World` enters the tree, with player/enemy occupied cells added dynamically when routes are requested.
- Combat: actors automatically attack enemies on a directly adjacent tile. Enemies stop patrolling when engaged. Enemy rewards are Damage, Health, or Resource and are granted only when their flying orb reaches its destination. Damage is stored in a six-weapon by three-enemy-color matrix, while collectible weapons add their grade-scaled bonus.
- HUD: opaque black backplates cover five tiles (320 pixels) inward from both sides and three tiles (192 pixels) inward from the top and bottom, behind every GUI control. Corner groups use 12-pixel sidebar insets and eight-pixel section spacing. Left-side texture icons render at their native 32x32 size; top-left values use 22px text while bottom-left resources retain 24px. Top-left stat containers use eight-pixel padding/spacing, damage/defense cells share standardized 40x40 dimensions, and primary Health/Mana cells are stronger than secondary regeneration cells. Discovered resources stack in full-width vertical rows. The fixed 296x207.2 minimap has a matching `Map` header containing Settings. Inventory and Equipment share one bottom-right frame, with the Quest Log embedded in the Inventory header and the six-column 42px slot rows beneath labeled sections. Unlocked player/Asha skills occupy the bottom center. The 1280x720 viewport uses fractional scaling with `expand` aspect handling so fullscreen/window resizes reach the screen borders instead of jumping between integer multiples.
- Terrain is editor-authored. Do not generate, replace, or clear the tilemap layers in code.
- Dungeons are isolated `DungeonLevel` scenes rendered through `DungeonManager` in a full-screen sub-viewport. The shared player is temporarily reparented into the active dungeon, while the overworld keeps processing without receiving dungeon input. M or Tab opens the active dungeon's independent fog-of-war map and its bottom-center Leave Dungeon button.

## Resource tree

```text
Absorber/
├── project.godot                         Project configuration and main-scene entry point
├── codex.md                              This project map
├── node_2d.tscn                          Unused Godot starter scene; not used by the running game
├── icon.svg                              Project icon source
├── icon.svg.import                       Godot-generated icon import metadata
├── Scenes/
│   ├── world.tscn                        Running world, hand-painted terrain, fox, and initial spawn
│   ├── fox.tscn                          Reusable playable fox scene
│   ├── chicken_enemy.tscn                Reusable chicken enemy scene
│   ├── cow_enemy.tscn                    Cow variant of the reusable enemy
│   ├── bull_enemy.tscn                   Bull variant of the reusable enemy
│   ├── evil_goat/crab/evil_scorpion_enemy.tscn  Additional reusable enemy variants
│   ├── snake/camel/crocodile/mouse_enemy.tscn  Sprite-swapped reusable enemy variants
│   ├── fox_asha.tscn                    Roaming clickable sentient-fox shop NPC
│   ├── fox_lio.tscn / fox_nia.tscn      Roaming clickable story NPCs
│   ├── enemy_spawn_point.tscn            Reusable enemy-spawn marker scene
│   ├── gold_ore.tscn                     Clickable ore deposit and mine-build button
│   ├── miner_structure.tscn              Mine production visual
│   ├── gold_shack.tscn                   Placeable +15 Gold capacity building
│   ├── gem_ore.tscn                      PileOfGems deposit and 3-minute Jewel mine
│   ├── gem_shack.tscn                    Placeable +10 Jewel capacity building
│   ├── fishing_spot.tscn                 Fish deposit and one-minute fishing mine
│   ├── fish_crate.tscn                   Placeable +5 Fish capacity building
│   ├── oak_tree.tscn / palm_tree.tscn    Wood deposits with five-/three-minute lodges
│   ├── wood_crate.tscn                   Placeable +15 Wood capacity building
│   └── damage_popup.tscn                 Reusable floating combat-damage label
├── Scripts/
│   ├── world.gd                          Tilemap navigation service and click-to-move handling
│   ├── fox_player.gd                     Fox movement, vitals, attacks, mana, and player skills
│   ├── chicken_enemy.gd                  Shared enemy combat, patrol, and telegraphed skills
│   ├── skill_toolbar.gd / skill_slot.gd   Player/Asha skill bars, picker, drag/drop, and tooltips
│   ├── enemy_spawn_point.gd              Spawn capacity and respawn lifecycle
│   ├── enemy_drop_entry.gd               Inspector-friendly item/chance/grade drop row
│   ├── game_resource_definition.gd       Inspector-editable resource definition
│   ├── resource_manager.gd               Multi-resource amounts, caps, and producers
│   ├── save_system.gd                    Compact save slots and offline progression
│   ├── resource_panel.gd                 Bottom-left discovered-resource HUD
│   ├── debug_stat_menu.gd                Shift+O manual stat adjustment panel
│   ├── fox_asha.gd                       Shopkeeper interaction and saved purchases
│   ├── fox_shop.gd                       Resource-priced stat shop interface
│   ├── story_fox.gd                      Shared non-shop fox movement and interaction
│   ├── dialogue_box.gd                   Bottom-screen portrait/name/text dialogue UI
│   ├── story_manager.gd                  Four-dialogue story state and trigger controller
│   ├── world_map.gd                      Tab-toggle full world map overlay
│   ├── world_map_canvas.gd               Terrain rendering and campfire selectors
│   ├── minimap.gd                        Top-right enemy/player map dots
│   ├── tile_grid.gd                      Screen-space 64-pixel grid overlay
│   ├── gold_ore.gd                       Ore selection and mine construction
│   ├── miner_structure.gd                Registers mine output with resources
│   ├── gold_shack.gd                     Registers a stackable Gold capacity bonus
│   ├── reward_orb.gd                     Animated enemy-reward travel orb
│   ├── damage_popup.gd                   Popup tween animation and cleanup
│   └── *.gd.uid                          Godot-generated script UID metadata; do not hand-edit
├── Shaders/
│   └── floor_tile_variation.gdshader     World-locked per-cell hue and brightness variation
├── Sprites/
│   ├── FloorTiles.webp                   4 × 3 floor atlas; every tile is 64 × 64
│   ├── WallTiles.webp                    3 × 1 wall atlas; every tile is 64 × 64
│   ├── Fox.webp                          64 × 64 playable fox sprite
│   ├── Chicken.webp                      64 × 64 enemy sprite
│   ├── Cow.webp and Bull.webp             64 × 64 enemy variant sprites
│   ├── Gold Ore.webp                      Gold ore deposit sprite
│   ├── MinerStructure.webp                Built mine sprite
│   ├── GoldShack.webp                    Gold capacity building sprite
│   ├── GoldOreResource.webp               Gold Ore resource HUD/drop icon
│   └── *.webp.import                     Godot-generated texture import metadata
├── Tests/
    ├── world_smoke_test.gd               Headless integration smoke test
    ├── save_system_smoke_test.gd         Save/load and offline-time smoke test
    ├── building_smoke_test.gd            Mine, shack, tooltip, and debug-key test
    └── *.gd.uid                          Godot-generated test-script UID metadata
└── Resources/
    ├── gold_ore.tres                     Gold Ore definition and resource icon
    ├── jewels.tres                       Jewel definition and resource icon
    ├── fish.tres                         Fish definition, icon, and base capacity
    └── wood.tres                         Wood definition and WoodResource icon
```

`.godot/` is Godot editor/cache state and is intentionally excluded from this map. `Godot_v4.7.1-stable_win64.exe` is the local engine executable, not a game resource.

## Scene and node relationships

```text
World (Node2D, WorldNavigation)
├── FloorTerrain (TileMapLayer)           Hand-painted passable tiles
├── WallTerrain (TileMapLayer)            Hand-painted blocked tiles, rendered above floor
├── Fox (instanced fox.tscn, FoxPlayer)   Player and active Camera2D owner
├── ResourceManager                       Shared resource amounts and production sources
├── SaveSystem                            Compact save slots and wall-clock catch-up
├── GoldOre/FishingSpot/Tree instances     Mineable resource deposits
├── GoldShack/GemShack/Fish/Wood crates    Player-built resource capacity structures
├── FoxAsha (FoxAsha)                      Click-to-approach persistent stat shop
├── FoxNia / FoxLio (StoryFox)             Clickable roaming story characters
├── StoryManager                           Persistent story conditions and dialogue beats
├── EnemySpawnPoint instances             Cow/Bull instances are added at runtime
├── GridOverlay (CanvasLayer)             2px black world-tile grid
└── HUD (CanvasLayer)                     Edge backplates, damage, resource, minimap, and inventory UI
```

`world.tscn` owns the two `TileMapLayer` resources and their painted cell data. `FloorTerrain` is the source of truth for walkable cells. `WallTerrain` overrides walkability: any painted wall cell is solid even if there is also a floor tile beneath it.

`FloorTerrain` uses `Shaders/floor_tile_variation.gdshader`. The shader first resolves the real world-locked 64-pixel TileMap cell, then applies a shared `(-32, -32)` sampling offset to two independently seeded, unbounded Perlin fields. Their sampling scales are 30% below the previous values. Each tile keeps one stable hue/brightness sample through its center, while an eight-pixel edge band smoothly rejoins the corresponding continuous world-space fields so neighboring samples cannot form long color seams. Hue remains limited to 15 degrees and brightness to 15 percentage points. World coordinates prevent the fields from resetting or repeating at TileMap render-chunk and viewport boundaries.

### `Scenes/world.tscn`

The game entry scene contains the hand-painted floor and wall tilemaps, the fox at `(224, 96)`, GoldOre at `(800, 160)`, a Gold Ore reward cow spawn at `(416, 96)`, and a Jewel reward bull spawn at `(800, 288)`.

Add additional enemy locations by instancing `enemy_spawn_point.tscn` under `World`, placing the marker on a painted floor cell, and changing its exported values in the Inspector. Do not place a spawn on a wall or empty cell: the spawn will correctly refuse to create an enemy there.

### `Scenes/fox.tscn`

Contains a `CharacterBody2D`, fox sprite, collision shape, outlined green `HealthBar` with numeric HP overlay, and child `Camera2D`.

The camera has zero local offset and is enabled, so its target is the fox's position. Position smoothing is enabled at speed `7.0`; this produces follow lag while keeping the camera centered on the player target. The fox's base health and mana regeneration each restore one point every three seconds; higher regeneration preserves the total rate but spaces it into continuous one-point restores. Mana starts at 10, is saved, and its blue world bar remains hidden until the first player skill unlocks. The fox faces right with a horizontal flip, snaps to a tile center whenever idle, and immediately respawns at its original scene position with full health on death.

### `Scenes/chicken_enemy.tscn`

Contains the reusable enemy body, collision shape, health UI, reward label, and telegraphed-skill runtime. Every sprite variant inherits it; Toad, Dung Beetle, Spider, and Salamander are the newest variants. The label displays the spawn point's `stat_reward_amount`, unless the enemy belongs to a rewardless wave restored after its room was abandoned.

### `Scenes/enemy_spawn_point.tscn`

A `Marker2D` with `EnemySpawnPoint`. It is deliberately small so level designers can instance it freely in `world.tscn` without visible gameplay art. Once all enemies from a point are gone, it draws a radial respawn clock and countdown until the next spawn.

### `Scenes/damage_popup.tscn`

A world-space `Label` for hit feedback. It displays a red outlined negative number, starts above the damaged actor, rises 30 pixels, eases into full size, fades, and removes itself. Its high z-index keeps it in front of wall tiles.

### Dungeon scenes and objects

`Scenes/dungeon_entrance.tscn` is the reusable overworld entrance. It exports a stable dungeon id, a separate `DungeonLevel` scene, a display/area name, and difficulty 1-6. Its compact hover card places a rounded, one-pixel white `Cleared` badge directly under the title when complete, followed by the named/color-coded difficulty and six tightly spaced, unconnected dots; Cave Moss instructional/production copy is omitted. The exported name appears once when entering its dungeon, while cleared entrances also show the outlined `Cleared` label above the cave and cannot be re-entered.

`Scenes/dungeon_door.tscn`, `dungeon_door_locked.tscn`, `dungeon_chest.tscn`, and `dungeon_stairs.tscn` are reusable room objects. Room doors stop blocking and disappear after their camera room has no living enemies. Locked doors consume the active dungeon's own key or show Mira's key-required dialogue. Chests export item/stat/key/resource rewards plus permanent inventory, equipment-pair, and skill-bar slot rewards. They begin non-blocking with their sprite hidden and a white dotted outline around their tile until their room has no living enemies, play `sfxChestVisible` when revealed, use the closed/open sprites and purchase sound, use Mira's player sprite in the dialogue, and show an upright reward above her inside independently rotating light rays for the dialogue duration. Opened state persists. Stairs use `Stairs.webp`, route Mira to an adjacent tile when clicked, then animate her from the sprite's bottom-right to its top-left over 1.2 seconds along a path shifted 20 pixels upward. The dungeon exit transition begins 0.8 seconds into that walk and holds the dungeon long enough for the traversal to complete before using the same snapshot/stat-transfer flow as the map button.

`Scenes/dungeon_template.tscn` (Mossroot Grotto template) and `Scenes/test_dungeon_two.tscn` (Sunken Burrow) are attachable examples with dungeon room objects and enemies. Dungeons have no predefined room list: navigation begins in the room containing `entry_cell` and expands into adjacent room coordinates only as needed, while every painted `WallTerrain` cell is solid.

## Scripts and public behavior

### `Scripts/world.gd` — `WorldNavigation`

Builds the navigation grid from the already-painted tilemaps in `_ready()`.

- `floor_layer.get_used_cells()` supplies allowed cells.
- `wall_layer.get_cell_source_id(cell) != -1` makes a cell solid.
- Empty cells outside the floor artwork are solid, preventing paths through unpainted space.
- Diagonal routes are disabled.
- Jump Point Search is enabled for efficient long-distance uniform-grid searches.
- `find_path(from_world, to_world, moving_actor)` returns centered, direction-compressed movement waypoints while treating other actors, buildings, and resource deposits as blockers. A moving actor's starting cell is always released so actors already overlapping a structure or deposit can leave it.
- `get_patrol_destination()` chooses a random walkable cell within a circular tile radius.
- `get_patrol_path()` rejects a route that would leave that patrol radius.

The script handles left clicks. Clicking a valid painted floor cell asks the player fox to follow the calculated path; clicking an enemy starts chase behavior. Clicking any story fox selects the shortest available adjacent tile and routes the player there. FoxAsha opens the shop when the current story state has no Asha conversation waiting. NPC, building, and ore/tree tiles participate in navigation and construction blocking for both player and enemies unless the moving actor already overlaps that tile. Clicking a pickup does not collect it and instead behaves as a floor click when applicable.

### `Scripts/fox_player.gd` — `FoxPlayer`

Exports `move_speed`, `max_health`, `attack_damage`, `attack_range`, and `attack_cooldown`.

Mira follows dynamically occupied-cell-aware waypoint paths, flips her sprite on rightward movement, and bounces/rotates while walking. When an enemy is on an adjacent tile, she attacks automatically after her current weapon's cooldown using the summed damage for that enemy's configured taken-damage color. Each weapon has an independent cooldown. She reserves an inventory slot when stepping onto a pickup tile, then the pickup shrinks and moves into her before being added to inventory. Receiving red, yellow, or blue damage subtracts the matching flat color defense plus equipped shield block, with a minimum of one damage, then updates health, creates a damage popup, and plays a hit reaction.

Player skills are saved unlocks equipped into four slots. Quick Roll costs 5 mana, lasts 0.3 seconds, grants full damage immunity, and moves clockwise to the next adjacent tile around the fixed enemy target, falling back counter-clockwise when the clockwise tile is blocked; recruited Asha rolls 0.2 seconds later. Using Quick Roll during the delayed Q tutorial window consumes that one-time tutorial immediately so its dialogue cannot appear after the roll. Golden Guard costs 15 mana and blocks all yellow damage for one second. Back Roll costs 5 mana and moves two tiles away; Arc Roll costs 5 mana and travels clockwise to the opposite adjacent tile. All three rolls have four-second cooldowns, while Golden Guard has a twelve-second cooldown. Dungeon chests can grant any of the four skills. Two seconds after the reward dialogue for Mira's second distinct skill closes, a saved one-time tutorial locks its dialogue open and pulses the picker button yellow until that button is clicked. The picker is a persistent, text-free five-column icon grid. Its player and picker frames remain compact at 42 pixels with 32-pixel skill artwork, matching the compact sidebar item slots. Pressing a picker icon immediately holds it centered under the cursor; assignment is drag-only and releasing within 24 pixels of a valid unlocked slot snaps it into place. Escape or an outside click closes arranging mode. Every player roll plays `sfxPlayerRoll`; attempting an unavailable, untargeted, unaffordable, cooling-down, or otherwise invalid player skill plays `sfxSkillUnavailable`.

Player attacks lunge, squash/stretch, and create three compact semi-transparent weapon-grade colored slash lines with black outlines on the target. The player has a white ground ring while adjacent to an enemy.

The fox belongs to the `player` group. Keep that group if renaming or replacing the scene; chickens locate their target through it.

### `Scripts/chicken_enemy.gd` — `ChickenEnemy`

Exports movement, range, cooldown, and color values. A spawn point supplies each chicken's health and attack damage through `setup()` before the chicken joins the tree.

Chickens:

- belong to the `enemies` group;
- choose passable targets at most two tiles from their spawn cell;
- use the shared wall-aware navigation paths;
- pause for a random 3–7 seconds after reaching a patrol target;
- avoid occupied player/enemy tiles while selecting and following patrol routes;
- bounce and rotate while walking;
- attack a fox on a directly adjacent tile once per cooldown, for the `enemy_damage` and outgoing color configured by their spawn point;
- when `aggressive` is enabled, notice the fox within three tiles and take the shortest available route to a cardinally adjacent tile;
- after any enemy disengages, follow the fox for three traversed tiles, reset that allowance when damaged, and then return to their spawn area;
- show the reward amount above the health bar; Resource rewards use the GoldOreResource icon tinted to the selected resource color;
- launch a randomized reward orb to the matching damage HUD row, player, or resource HUD before the configured Damage, Health, or Resource reward is applied;
- own an item drop table, exposed through the enemy hover tooltip, and roll configured item pickups when their health reaches zero.

Enemies clear their patrol path and remain stationary while directly adjacent to the fox. Their attacks use the same lunge/squash and compact semi-transparent outlined slash treatment. Enemy armor is a flat reduction with a minimum of one incoming damage. After the out-of-combat delay, enemies regenerate 10% of maximum health once per second. Beneath the health bar, the outgoing-color dot is followed by the enemy's damage amount in the health-number font size. The combat ring and slash use the outgoing damage color.

Each spawn has three explicit enemy-skill Inspector slots with skill, damage override, damage type, cooldown, and initial cooldown offset. A zero damage override uses five times normal attack damage; a zero cooldown uses the selected skill default. First engagement starts each timer at its initial offset. Timers continue through dodge and pursuit so multi-ability enemies can reach later slots, then reset only when the fight actually disengages. Skills stop movement and normal attacks, show `Big Attack` above the caster, slowly pull the sprite backward, tint the enemy 25% toward the selected damage color, lock their target cells, and fade red/yellow/blue tile rectangles with a flashing outline in that same damage color until resolution. Starting a charge plays frame-deduplicated `sfxEnemyCharge`; every resolving target tile independently plays `sfxBigAttack`, including tiles resolving together. Crushing Blow winds up for two seconds and hits the front tile. Cascading Sweep winds up for one second and resolves its front/outward targets at 0.0, 0.08, 0.16, and 0.24 seconds. Cascading Surround repeats that sweep and also hits both tiles immediately beside the caster after 0.4 seconds. Fan Strike targets the player's tile immediately and both perpendicular side tiles after 0.2 seconds; Driving Strike targets the player's tile immediately and the tile behind the player after 0.2 seconds. Both new patterns have Quick (0.8-second) and Charged (1.5-second) variants. Snaring draws a three-pixel white circle around Mira. The first enemy skill pauses after 0.4 seconds for a saved, tile-click-only dodge tutorial whose two valid side tiles glow yellow. Choosing one clears any click-to-chase enemy target before applying a direct adjacent step, preventing chase updates from cancelling the tutorial movement. The first snare before Quick Roll is unlocked pauses after 0.2 seconds for its saved warning. The first Cascading Sweep or Cascading Surround after Mira unlocks a skill also waits 0.4 seconds before pausing for a saved Q-only tutorial; opening it clears slot one's cooldown and raises current mana to at least five, then Q immediately uses slot one before combat resumes.

### `Scripts/enemy_spawn_point.gd` — `EnemySpawnPoint`

Exports:

- `respawn_time`: seconds between spawn attempts while below capacity;
- `max_enemies`: maximum live chickens owned by this marker;
- `stat_reward_amount`: displayed stat reward value;
- `enemy_health`: health assigned to every chicken created by this marker;
- `enemy_damage`: attack damage assigned to every chicken created by this marker;
- `enemy_damage_color`: outgoing attack/slash color;
- `enemy_armor`: flat incoming-damage reduction;
- `aggressive`: enables three-tile player detection and pursuit behavior;
- `boss`: marks this spawner's enemies as bosses; their combat music and camera framing remain active through pursuit and pauses until the boss actually disengages;
- `enemy_damage_taken_color`: selects which player damage-color row applies;
- `enemy_type`: Inspector selection for every reusable sprite variant, including Toad, Dung Beetle, Spider, and Salamander;
- `enemy_scene`: optional custom-scene override;
- `reward_type`: Damage, Health, or Resource;
- `damage_reward_color`: the color increased by a Damage reward;
- `reward_resource_id`: the resource granted by a Resource reward.

The active list is explicitly rebuilt as a typed `Array[ChickenEnemy]`; do not replace it with `Array.filter()` without a safe typed conversion, because Godot returns an untyped `Array` and will raise a type-assignment error. `item_drops` is an Inspector-friendly array of `EnemyDropEntry` resources, each with item, chance, and grade selectors. The hidden legacy dictionary table remains load-compatible with already placed spawners.

### `Scripts/damage_popup.gd` — `DamagePopup`

`show_damage(amount)` formats `-<amount>`, starts the position/scale/fade tween, and connects tween completion to `queue_free()`. Emphasized enemy-skill damage remains fully visible for 0.8 seconds before fading. It deliberately uses a completion callback rather than `await`, which keeps headless tests and shutdown clean.

### `Scripts/save_system.gd` — `SaveSystem`

Provides slots 0-9 at `user://s0` through `user://s9`. Shift plus a number saves; the number alone loads. State uses short positional arrays, millisecond timer integers, and bit masks. Compact JSON is compressed with whichever built-in compression mode produces the fewest bytes, then Base64-encoded as one file string. Loading validates the version and decompressed-size bound before applying data.

Saved progression includes player position, health, recovery timing, hidden defense, stats, damage matrix, inventory/equipment with merge totals and unlocked slot counts, player skills and the swap-tutorial flag, weapon cooldowns, resources/discovery, built producers and production progress, typed Gold/Gem/Fish/Wood capacity-building positions, FoxAsha purchases and position, FoxLio/FoxNia positions and carried helper items, dialogue progress and one-time event flags, map overlay preferences, gate unlocks, ground pickups, spawn timers, and live enemy position/health/reward eligibility. Dialogue runtime flags are cleared before saved flags are restored so state from the currently running slot cannot leak into the loaded slot. Spawn state is keyed by stable marker name so scene child ordering cannot mix enemies between spawns; legacy positional saves, grade-only equipment, and former story formats still migrate on load. The wall-clock timestamp advances player/enemy recovery, weapon cooldowns, all mine/lodge production, and every elapsed spawn interval. Offline spawn attempts stop at each marker's `max_enemies`.

Dungeon save data is appended compatibly to the existing save array. It stores the one-time centered entry tutorial, one-time first-exit reaction, per-dungeon temporary stats and transferred baseline, separate key counts, Mira's dungeon tile/current room/previous-room respawn state, explored/visited rooms, remaining enemy snapshots and reward eligibility, opened chests/locked doors, dungeon ground pickups, cleared state, and the active dungeon id. Automatic and Shift-number saves capture an active unfinished dungeon live. Number-key loading works inside dungeons and directly rebuilds the dungeon saved in that slot, restoring Mira's position and temporary stats along with keys, exact enemy locations/health, pickups, exploration, chests, and doors; restored spawn timers are clamped to their configured interval. Older saves without an active-dungeon id still load into the overworld. Leaving restores overworld stats, snaps the camera to Mira, captures the dungeon again, transfers newly gained dungeon stat deltas at ten-frame intervals, and writes the auto-save. A cleared dungeon returns directly to its overworld entrance with the camera already centered there, without the normal emergence camera movement. Cleared dungeon count drives Cave Moss at one per 600 seconds each, including offline catch-up.

## Art and tile conventions

- All navigation tiles are 64 × 64 pixels; maintain this size when adding art or update `WorldNavigation.TILE_SIZE` and both TileSet region sizes together.
- `FloorTiles.webp` has twelve atlas cells arranged 4 columns by 3 rows.
- The first three atlas cells in row one play the Grass playlist, the first three in row two play the `Forrest1.mp3`/`Forrest2.mp3` playlist and announce `Whippersnapper Woods`, and the first three in row three play the Desert playlist. Atlas coordinates are zero-based in code.
- `WallTiles.webp` has three atlas cells arranged 3 columns by 1 row.
- Walls currently drive navigation by occupancy, not TileSet physics collision. If physics collisions are later added to the wall TileSet, retain the grid checks because they are the pathfinding authority.
- Textures use nearest filtering for pixel-art presentation.
- Floor art receives deterministic, tile-specific HSV variation from separate unbounded hue and brightness Perlin distributions. Every world-locked cell keeps one stable value across its center, then blends back to the continuous fields within eight pixels of each edge; both sides therefore meet at the same color without a multi-tile staircase seam. The fields do not reset or repeat at TileMap render-chunk boundaries. Both patterns use a `(-32, -32)` sampling offset, scales reduced by 30%, and shifts within -15 to +15 (degrees and percentage points, respectively).

## Styling and feedback

- Both health bars use opaque `StyleBoxFlat` resources with a two-pixel black outline, dark background, green fill, and centered current/max HP text.
- The top-left damage panel is a bordered spreadsheet-style table: its blank first cell is followed by active weapon types across the top. Active damage colors run down the left in fixed red, yellow, blue order. Each value is its color/weapon sum; values of one are not drawn, and a row or column appears only when it has a value above one. Weapon headers show their equipped item, or the generic damage icon when that damage column has no equipped item.
- Inventory and Equipment are labeled sections inside one content-fitted bottom-right card. Inventory, weapon, and armor item slots are 42x42 and wrap into six columns. New players start with one full six-slot inventory row. Equipment has six weapon and six armor positions; the first pair starts unlocked and the other five pairs start locked. A gold `Auto Merge` button spans the five columns beside the trash slot and repeatedly combines matching items in the inventory. The Quest Log button occupies the left side of the Inventory header. Toolbar clicks return an unlocked item to inventory.
- Equipment stores a merge total beginning at one. Dragging two matching item IDs of any grade—or using Auto Merge—adds both totals into the target; grades advance at totals 2, 4, 8, 16, and so on. Clicking alone never merges. Equipment icons show their merge total in small outlined white text at bottom-right, and compatible merge targets gain a yellow outline while dragging.
- Item grades progress through Crude (gray), Ordinary (white), Superior (green), Elite (blue), Masterwork (purple), Mythic (orange), Divine (pink), Immortal (teal), animated-rainbow Omnipotent, and Void (black). Further merges are unlimited and display as `Void +1`, `Void +2`, and so on. Every grade has a matching background in inventory, toolbar, and enemy-drop cards; Omnipotent also animates player attack slashes. A grade raises a stat to 210% of the prior grade (double plus 10%), rounded to whole damage/block values and saturating at the maximum signed 64-bit value.
- Combat feedback is intentionally world-space, not CanvasLayer UI, so it moves with actors and the camera. Combat uses colored ground rings, lunge/hit reactions, compact semi-transparent black-outlined slash effects, and wall-front damage popups.
- The only gameplay text is the enemy reward number and temporary negative-damage popup. There is no persistent HUD/status text.

## Current additions: enemies, resources, and UI

- `EnemySpawnPoint` exports rewards (including permanent Mana and Mana Regeneration), health, damage, one shared red/yellow/blue combat color, flat armor, three skill loadouts, a typed drop list, an Enemy Type selector, and a `boss` checkbox. Engaging a living marked boss overrides biome music with `Boss.mp3` and smoothly zooms the camera to 1.12x; both persist through pursuit and dialogue/gameplay pauses until the boss disengages. The placed Bull, Evil Goat, and Mad Coyote encounters are marked as bosses. Its sprite variants now also include Toad, Dung Beetle, Spider, and Salamander.
- `ResourceManager` is a scalable resource economy backed by `GameResourceDefinition`. Each definition has an id, name, icon, display color, maximum amount, starting amount, and base production speed. Gold Ore, Jewels, Fish, Wood, and Cave Moss are current definitions.
- Cave Moss is the fifth resource (`Resources/cave_moss.tres`, `IconCaveMoss.webp`). Every cleared dungeon contributes `1 / 600` Cave Moss per second; entrance tooltips no longer include its instructional or production line.
- `DungeonManager` owns the centered first-entry warning, entry/exit presentation, entry-only exported area title, one-time first-exit line, isolated dungeon viewport, temporary stat snapshots, ten-frame reward transfers, per-dungeon keys, persistence, and Cave Moss production. Entering a dungeon closes overworld popups, and their story, building, helper, item, and off-world enemy-hover producers remain suppressed until exit. New dungeons reset Mira to 10/10 health, 10/10 mana, and zero defense in all three colors; legacy untouched `[1, 1, 1]` dungeon baselines migrate to zero. Max mana and mana regeneration participate in the same temporary dungeon gain/overworld transfer model. While any dungeon is active, `GameAudio` crossfades to the alternating `Dungeon1.mp3` / `Dungeon2.mp3` playlist using the same continuous playlist and volume behavior as overworld biome music, then restores location-appropriate overworld music on exit. The original Camera2D remains frozen at its current overworld screen center while a separate fixed camera serves the dungeon viewport. On exit, the overworld camera is positioned and flushed at the entrance while still covered by the dungeon view, preventing a one-frame camera jump; the dungeon view then closes, the camera reattaches, and Mira emerges from the entrance to her saved adjacent overworld tile with a one-second reverse entry animation. `DungeonLevel` dynamically expands its navigation grid into any adjacent signed room coordinate, with no predefined room data, declared-layout boundary, or code-drawn room walls; only manually painted `WallTerrain` tiles block movement. Fixed whole-room camera transitions work anywhere along their directional threshold: right triggers three tiles from its edge and lands three tiles into the next room, left triggers two and lands four, while vertical transitions trigger one tile from the edge and land two tiles in. Merely standing at a threshold does nothing; an outward movement path or outward click performs the transfer automatically. Activating a room completes the initial wave for its spawn points after their cells become navigable, preventing off-room spawns from falling into their long configured respawn timers. Leaving an occupied room immediately restores its full fresh wave: replacements corresponding to surviving enemies preserve their reward eligibility, while only replacements for enemies already killed are rewardless. Full maps and minimaps derive their content bounds from explored cells (visited rooms in dungeons), preserve their aspect ratio, and cache transforms by exploration revision; saved visited-room data restores dynamic dungeon navigation rooms on re-entry. Authored dungeon walls overlay the visited floor as black on both maps. Map terrain, wall lists, bounds, and transforms are revision-cached, the full map redraw is throttled to 10 Hz, and opening no longer repeats marker rebuilding. It also provides room-local fog, a seed reset to `1` on every new room, room-clear rapid health and mana regeneration, previous-room full-health death respawns, and off-camera enemy freezing. Both health and mana regeneration pause without advancing their timers while the current dungeon room contains enemies; the regeneration HUD cell is gray with a three-pixel red cross-out from bottom-left to top-right.
- Resource rewards launch an orb to the resource HUD before adding their amount. The bottom-left resource panel begins explicitly hidden and appears as soon as the first resource is acquired. Its 296-pixel-wide list uses one vertical row per discovered resource, eight-pixel outer margins, native 32px icons, and left-aligned 24px `amount/max` plus optional `+speed/m` values separated by 32 pixels. Unlocked Auto Fight retains the full sidebar width and stacks immediately above resources.
- The GoldOre scene uses `Gold Ore.webp`. Hovering an empty ore or built mine outlines its tile in yellow. A built mine with room for another capacity building shows `Build` over `More` on hover. Clicking an empty ore reveals a centered Build Mine button without moving the fox. Its hover card is content-fitted with an 8px margin, places `Costs:` and resource rows on the left, shows the full-size building sprite on the right, and stays above the button. Its default build cost is 5 Gold Ore and 2 Jewels. Each MinerStructure registers 1 Gold Ore per 300 seconds and displays a green floating `+1` when it produces on screen.
- Clicking a built mine shows capacity-building buttons on valid cardinally adjacent floor tiles without walls, ores, actors, gates, or buildings. Every capacity building starts at 10 of the resource it stores. Producer and capacity-building prices increase by 25%, rounded up after each prior building of the same resource type. Capacity bonuses stack and their tiles become navigation/placement blockers.
- TileGrid is a 20%-opaque screen overlay aligned to the moving world and draws 2px black lines for every visible 64x64 tile. The top-right minimap fills a 296x207.2 rectangle within the right sidebar (30% shorter vertically than its former square). A matching 296x44 `Map` header sits eight pixels above it and contains the Settings gear. The map renders explored nearby terrain at a twenty-tile radius, draws NPCs as green dots, and draws only explored enemies within twenty tiles as red, yellow, or blue dots matching their damage color. Clicking it routes Mira to that tile; blocked or fog-covered clicks search outward for the nearest explored, reachable tile within thirty steps. While Mira moves, both the minimap and Tab world map trace her remaining explored route with a blue dotted line.
- The damage grid starts hidden, then filters its color-by-weapon sums to values above one. Yellow and Blue rows require their base color damage to exceed one and cannot be revealed by weapon damage alone. A matching armor grid appears to its right after a shield has first been equipped, uses ShieldIcon, shows negative flat-defense values, and reveals yellow/blue rows after those base color defenses first increase. Damage and defense grids use matching 40x40 cells, four-pixel internal gaps, and eight-pixel panel padding; the neighboring grids and vitals groups are separated by eight pixels. Damage, shield, heart, regeneration, mana, and resource textures use native 32x32 artwork. Top-left numeric text uses 22px, while bottom-left resource values remain 24px. Heart current/max and regeneration cells sit beneath the grids. Empty armor and weapon toolbar slots remain beneath their lock overlay, while equipment tooltips render above the locks.

## Testing and maintenance

Run the smoke test from the project root with the local executable:

```powershell
$env:APPDATA = (Resolve-Path .\.godot).Path
$env:LOCALAPPDATA = (Resolve-Path .\.godot).Path
.\Godot_v4.7.1-stable_win64.exe --headless --rendering-method gl_compatibility --path . --script res://Tests/world_smoke_test.gd
```

The world test verifies map routing and fox flipping, occupied-tile avoidance, cow/bull spawn selection, delayed Gold Ore and Jewel rewards, selectable damage reward color, compact resource HUD text, the Gold mine cost, mine production feedback, HUD progression, auto merging, and respawn. `save_system_smoke_test.gd` verifies compressed strings, physical number-key bindings, state restoration, and ten minutes of offline health, spawn, and mine progression. `building_smoke_test.gd` verifies visible damage dots, tooltip layout, hover outlines, valid shack placement, stacked capacity, save restoration, and Shift+P.

`dungeon_system_smoke_test.gd` verifies both attached test scenes, the centered first-entry popup, authored-wall path rejection and safe entry placement, unrestricted dynamic room expansion at arbitrary coordinates, wall-free generated room edges, movement-gated directional thresholds and landing offsets, fixed one-length camera movement, off-camera enemy freezing, dungeon fog, temporary stat reset/restoration, static chest reward icons, separate keys, chests, locked doors, clear snapshots, first-exit behavior, safe snapshot re-entry, save inclusion, and one-Cave-Moss-per-ten-minute production. `dungeon_music_smoke_test.gd` verifies boss presentation through pursuit/pause/disengagement, off-room combat-audio suppression, dungeon entry playlists, and overworld music restoration. `requested_combat_fixes_smoke_test.gd` verifies the saved one-time no-Quick-Roll snare warning and its 0.2-second pause. `dungeon_map_smoke_test.gd` verifies the absence of a predefined-room export and that only dynamically visited rooms control cached map cells, black walls, bounds, and restored navigation. `dungeon_stairs_camera_smoke_test.gd` verifies the separate frozen overworld camera, one-second diagonal stairs traversal, and reverse entrance emergence ending at the saved overworld position.

`skill_system_smoke_test.gd` verifies the simplified dungeon hover card, Bat/Millipede variants, spawn-configured enemy skill timing/telegraphs/cascade/tint, tutorial cooldown and mana preparation, player roll immunity and placement, Golden Guard, toolbar locks/icons, Asha's bar, chest skill rewards, zero-defense dungeon reset vitals, and skill/mana persistence. `dungeon_reward_extensions_smoke_test.gd` also covers the forced swap tutorial, compact skill frames, immediate cursor-centered dragging, 24-pixel snapping, drag-only assignment, persistent multi-swap editing, and picker exit paths.

`hud_edge_bars_smoke_test.gd` verifies the left/right five-tile and top/bottom three-tile black HUD backplates, their screen-edge anchoring, input passthrough, placement beneath the GUI controls, content-fitted corner panels, the fixed-width 30%-shorter minimap and its Settings header, native 32px left icons, full-width vertical resource rows with left-aligned values and a 32px amount/rate gap, primary/secondary vital styling, 22px top-left values, eight-pixel margins, standardized 40x40 damage/defense cells, the unified Quest/Inventory/Equipment card, six-column 42px item slots, six-slot starting inventory/equipment backing data, locked added equipment positions, four-slot save migration, and non-overlapping side stacks.

`sep01_requested_changes_smoke_test.gd` covers merge totals and grade milestones, merge persistence, revised item stats/tooltips, full-health potion rejection, Quest Log/shop state, Show Enemies defaults, and helper item handoff persistence. `sep01_dungeon_load_smoke_test.gd` round-trips a live active-dungeon enemy's health and position and verifies restored cooldown bounds. `sep01_map_quest_visual_smoke_test.gd` verifies exact quest cross-out geometry, the active floor atlas's first three second-row colors, and black unpainted full-map coordinates. `sep01_quest_stats_skill_feedback_smoke_test.gd` verifies quest-location labels, opaque button styling, 50%-brightened icon sizing and inventory alignment, red-dot absorption feedback, stat hover names, and player-originating cooldown/mana failure text. `settings_menu_smoke_test.gd` also verifies fractional viewport scaling and that disk controls stay unavailable without a graphical Windows display.

When editing the project:

1. Preserve `FloorTerrain`, `WallTerrain`, and `Fox` node names unless corresponding `$NodeName` references are updated in `world.gd`.
2. Paint floor beneath all intended traversable spawn and patrol cells.
3. Use `WallTerrain` for every blocking tile; the pathfinder reads that layer directly.
4. Keep `player`, `enemies`, and `world_navigation` groups intact unless all lookup sites are updated.
5. Update this file after every user prompt, even if the prompt only changes a small behavior.

## Current UI and feedback behavior

- The top-left panel begins hidden and becomes a filtered damage matrix once a color/weapon sum exceeds one. Its first cell is blank; each visible weapon type is an icon header, visible color-dot rows are always ordered red, yellow, then blue, and cells with a value of one are blank. An active row or column always has at least one displayed number. Damage and defense use matching 40x40 cells, 22px values, and eight-pixel container padding/spacing.
- Inventory and Equipment meet inside one framed bottom-right card with eight-pixel section rhythm and centered section titles; Equipment has a subtly darker inset to distinguish secondary information without changing its lock icons. Inventory/equipment and bottom-center skill slots are all 42x42. New players start with six inventory slots. The Quest Log button is embedded at the left of the Inventory header, balanced by an equal right spacer so the title remains centered. The gold `Auto Merge` button is present only while an inventory merge is possible; on click, each source item visibly travels onto its matching target before their merge totals are added. Dragging matching equipment also merges regardless of grade, while clicking an item only equips or moves it. The toolbar retains six weapon and six armor slots: the first weapon/armor pair is unlocked and the remaining five pairs are visibly locked until rewarded. Empty unlocked slots identify themselves as `Armor - None` or `Weapon - Claws`; locked slots show `Armor/Weapon - None` followed by `Locked`. Empty armor slots use HelmetIcon and empty weapon slots use SwordIcon, under the unchanged lock overlay. Clicking an unlocked toolbar item moves it only to an empty compatible inventory slot. Weapon slot icons have independent transparent-black cooldown overlays that shrink as cooldown expires. Saves persist all six positions, while legacy four-position saves preserve their damage grouping and pad the two new positions.
- Item and enemy drop tooltips are clamped to the camera viewport. Item titles use `<grade> <name>`, such as `Crude Yellow Sword`. Orange Shield blocks both red and yellow damage and shows two color-specific ShieldIcon rows; Yellow Sword adds five yellow damage. Potions cannot be consumed at full health and instead shake, play the unavailable-skill sound, and raise red `Full Health` text. Hovering top-left damage, defense, health, health-regeneration, mana, or mana-regeneration cells opens the same description tooltip with that stat's name. Player skills rejected for cooldown or insufficient mana also raise their exact slot error (`Cooling Down` or `No Mana`) as large outlined red text from Mira.
- Ground pickups have a translucent elliptical shadow and a gentle vertical float.
- Resources are stored in a full-width vertical list at bottom-left only after first acquisition. Removed rows are detached immediately so invisible queued controls never affect sizing; each row uses a native icon followed by left-aligned 24px `amount/max` and optional `+speed/m` values with an exact 32px gap between the two labels. The clickable 296x207.2 top-right minimap and its 44px `Map`/Settings header show explored local terrain and a white player dot, green NPC dots, explored damage-color enemy dots within twenty tiles, and Mira's active route as blue dots; the Tab map shows the same route treatment. Blocked or fog-covered minimap destinations fall back to the nearest explored, reachable tile within thirty steps. A 20%-opaque black 2px grid follows every visible 64x64 world tile.
- Mines and shacks show resource-icon hover cards for production and capacity; mine production is displayed per minute. Mines with an available capacity-building tile show a two-line `Build\nMore` hover label. Shack buttons remain available on temporarily actor-occupied cells, while walls, gates, deposits, and buildings remain permanent blockers. A built mine has no yellow hover outline once every adjacent shack tile is permanently blocked.
- `GemOre` uses `PileOfGems.webp`; its mine starts at 5 Jewels and 2 Wood and produces one Jewel every 180 seconds. Gem storage starts at 10 Jewels, while `GemShack.webp` adds 10 Jewel capacity.
- `FishingSpot` uses `FishSillouhettes.webp`; its construction button says `Build Fishery`, the built producer uses `FishingMine.webp`, and it produces one Fish every 60 seconds. Fisheries start at 5 Fish and 2 Gold; Fish storage starts at 10 Fish. Fish starts with 20 capacity, and a `FishCrate` adds 5 capacity.
- `OakTree` and `PalmTree` use their matching sprites and build `WoodCuttingLodge.webp` producers. Oak produces one Wood every five minutes and palm every three minutes. Lodges start at 5 Wood and 2 Fish; Wood storage starts at 10 Wood. A `WoodCrate` adds 15 capacity. Wood uses `WoodResource.webp`, starts at 10 capacity, and lodge progress continues during offline save/load time.
- The debug menu is hidden by default beneath the top-left combat HUD and fits its controls when shown. Shift+O toggles it; its plus/minus controls edit max health, regeneration, and red/yellow/blue base damage and defense.
- FoxAsha, FoxLio, and FoxNia roam within two tiles of their scene positions using Mira's bob-and-tilt walk cycle, pause while approached, block navigation, and show a yellow hover outline. Before recruitment, FoxAsha's Store opens only after Mira reaches an adjacent tile and no story conversation is due. Its top rows sell one Fish or Wood for 2 Gold, followed by its stat upgrades; the former Fish-priced health upgrade is no longer offered. Buying Deru's Spare Cart Parts recruits Asha, permanently closes her Store, and turns her into Mira's healing follower. Her join moment locks gameplay while a text-height black banner slides in from the right beneath Asha, then pauses for 0.25 seconds between the portrait appearing, rotating sun rays fading in, and `Asha joins the party!` popping into view. `AshaJoins.mp3` begins with the banner while biome music quickly fades out; the title receives the camera punch. There are no explanatory lines below it. After at least three seconds a continue prompt appears, and the rays keep rotating until any key or mouse click closes the celebration and restores biome music. `Lios Shop` sells one Gold for 2 Fish, +4 red damage for 5 Fish, and +20 health for 5 Jewels. Lucie's shop sells Fish for 2 Jewels. Store buttons remain enabled and visibly highlight even when unaffordable. Inventory-style hover cards appear instantly, follow the pointer, and preview the current and resulting amount. Rows stagger into view, lift and enlarge their icon on hover, flash and send icons toward the HUD on success, or shake and show the missing cost on failure. Asha and Lio react to their first purchases, and the dialogue preserves the focused row and pointer when the Store reopens. The centered box fits visible rows with exact 8px content margins and closes via its top-right X, Escape, or an outside click.
- Giving the Spare Cart Parts to Deru repairs his cart and recruits him as a hunter instead of unlocking a shop. He uses Lio's invulnerable hunter loop against eligible AreaID 2 enemies but deals 7 damage per hit, carries stat and item drops, returns to the AreaID 2 campfire, and waits there for handoff. Lio uses the same item-carrying helper flow. If Mira lacks room for every carried item, a two-inventory popup permits dragging items in either direction before confirmation; confirming applies Mira's chosen layout and clears the helper's carried items. Small stat handoffs are free; larger handoffs cost Deru's distinct 3-Gem fee rather than Lio's 3 Gold. Hovering a helper who is waiting with rewards at a campfire opens the shared equipment-style tooltip, listing every carried reward followed by `Price: Free` or the helper's price. Hunter state, collected stat and item rewards, fee authorization, position, and repaired visuals persist in saves, including migration from older saves.
- The compact bottom dialogue panel fits the longest message in each conversation horizontally up to a readable wrapping limit, stays centered, and enters with a short slide-and-scale motion. Text reveals progressively with punctuation pauses; the first advance completes the line and the next continues. A pulsing arrow replaces instructional copy after each line finishes, while the active portrait pops, brightens, and gently bobs. Mira's unflipped portrait and name appear on the left; NPC identity appears on the right with the portrait flipped toward the text, except Asha, whose portrait remains unflipped. All story foxes stop walking while it is open. Lio's first interaction introduces his work, adds `If only I had some way to automate it, hah!`, and begins the gold-mine quest; before the nearby mine is built, later talks repeat his automation wish. Asha's welcome runs only on her first direct interaction and opens the shop afterward. Mad Coyote's first snare pauses 0.2 seconds after its skill and gives skill-sensitive escape dialogue; its first defeat celebrates the path opening. Persistent remarks include a seven-tile cave-bull warning, the first Spider defeat's mana reminder, and a ChickenSpawn12 Evil Goat kill trigger.
- The Quest Log button has a fully opaque dark frame, uses `iconQuest.webp` at its native size with the sprite modulated 50% brighter, sits inside the Inventory header, and badges the number of active quests at bottom-right. Starting or advancing a quest sends a circular red dot from Mira into the button, which grows, contracts, and settles as it absorbs the update. Its popup closes by X, outside click, or Escape. Quest title buttons append their location in parentheses, expand through the current step, cross completed steps in red, and prefix completed quests with a green checkmark. Lio's Tiny Woods automation quest begins on his first conversation and requires his nearby mine and both remaining gold mines before recruitment; Deru's Snakemouth Expanse cart-parts line is the second quest.
- Settings uses a 36px gear embedded in the minimap header and retains portable clipboard-string Export/Import controls on every platform. Graphical Windows desktop builds additionally create native-filesystem `Save to Disk` and `Load from Disk` buttons for `.absorber` files; web and headless builds do not create those controls. Disk loads pass through the same validation/application path as other saves and refresh the autosave.
- Enemy physics calculates player adjacency once per enemy tick, caches player/world references, and uses one world-level occupied/target-cell cache per physics frame instead of scanning every enemy for every moving enemy. Newly spawned enemies receive a randomized initial patrol delay so mass spawns do not request paths together. The minimap redraws at 10 Hz instead of every rendered frame; these changes keep large enemy populations from producing quadratic patrol-conflict costs and synchronized pathfinding spikes.
- Tab opens a terrain-scaled world map overlay with persistent fog of war and a six-tile reveal radius. Unpainted map coordinates remain black instead of receiving fallback terrain colors, and the first three tiles in the active floor atlas's second row render `#44442B` on both map and minimap. Enemy and building sprite overlays each have a bottom-left visibility toggle; Show Enemies defaults on and both states persist in saves. Overworld boss spawn markers show a compact, text-free respawn progress circle sized within three-by-three tiles. Only visited Campfires appear and accept teleporting. Reaching Campfire2 shows `TAB` above the fox until Tab is pressed. Exploration, Campfire visits, overlay preferences, and tutorial dismissal persist; Tab toggles and Escape closes the map.
- Enemy health bars use the original compact colored dot beneath the bar. A spawner's single enemy combat color now controls both the damage color it deals and the color of player damage used against it; armor remains a flat reduction with minimum-one damage.
- Mine hover stats display production as a per-minute rate with two decimals, or three decimals below 0.01/m. Tooltip hides are owner-aware so leaving one structure cannot dismiss another structure's popup.
- Actors standing on a newly built structure may traverse their current cell and path to an unoccupied neighboring tile, preventing players and enemies from becoming trapped.
- Enemy patrol targets are reserved deterministically. When enemies select the same tile or one selects another enemy's occupied tile, the yielding enemy targets its own current tile instead of pushing indefinitely.
- Enemy reward icons are 16px. Resource reward icons above enemy health bars retain their original texture colors, while their numbers are always gold. All enemy reward text is 22px.

## Recent prompt log

- 2026-09-01 - Left-aligned resource production rates beside their amounts and standardized the space between those two values at 32 pixels.
- 2026-09-01 - Restored resources to one full-width vertical row per resource, changed expandable-mine hover text to the two-line `Build` / `More`, and converted mine production hover stats from per-second to per-minute rates.
- 2026-09-01 - Consolidated the corner HUD into a Map/Settings header, one Quest/Inventory/Equipment card, and compact two-column resource cards with right-aligned tabular values; standardized eight-pixel section spacing and differentiated primary Health/Mana from secondary regeneration, while intentionally leaving Damage/Defense labels and lock-icon prominence unchanged.
- 2026-09-01 - Kept the shortened minimap at its prior 296px width, reduced top-left values to 22px, added consistent eight-pixel stat padding/spacing, standardized damage/defense cells at 40x40, and reviewed the screenshot for further non-coded layout improvements.
- 2026-09-01 - Restored inventory/equipment slots to 42x42, used six columns, expanded new-player inventory and weapon/armor backing data to six positions with legacy-save migration and locked added equipment pairs, content-fitted the top-left and bottom-right panels, and reduced minimap height by 30%.
- 2026-09-01 - Set all left-sidebar texture icons to their native 32x32 size with matching 24px values, doubled item slots from 42x42 to 84x84, and reflowed inventory/equipment into centered two-column grids without changing the compact bottom-center skill bar.
- 2026-09-01 - Expanded side GUI panels to the black bars' 296-pixel inner width, distributed the combat/vitals cells, stacked full-width resources and Auto Fight, enlarged the minimap to 296x296, and centered inventory/equipment contents in full-width right panels.
- 2026-09-01 - Added opaque black HUD backplates five tiles deep on the left/right and three tiles deep on the top/bottom, anchored to every screen edge behind all GUI controls.
- 2026-09-01 - Made the Quest Log control fully opaque and its native icon 50% brighter; added Windows-desktop-only native Save to Disk/Load from Disk settings controls; and changed viewport scale mode from integer to fractional so fullscreen resizing fills the screen borders.
- 2026-09-01 - Moved the native-size `iconQuest` Quest Log button above the inventory, added Tiny Woods/Snakemouth Expanse quest locations and player-to-button red-dot absorption feedback for starts/updates, added shared hover names to top-left stats, and made cooldown/mana skill failures fly upward from Mira in large red text.
- 2026-09-01 - Made Quest Log cross-outs overlap only the objective glyphs at their exact rendered width, mapped the actually painted floor atlas's first three second-row tiles to `#44442B`, and stopped the full map from painting fallback colors into unpainted coordinates.
- 2026-09-01 - Rechecked the September feature set after an editor save, restored the missing `HUD/QuestLog` scene connection without disturbing new drop-chance or enemy-aggression scene edits, and reran both focused smoke tests successfully.
- 2026-09-01 - Added merge-count equipment progression across grades, revised tooltips/slots/potion feedback and Orange Shield/Yellow Sword stats; renamed the Fishery, Lios Shop, and Lucie; added the two-quest expandable Quest Log; persisted helper item deliveries and active-dungeon enemies safely; corrected dungeon-clear camera placement and map colors/defaults/boss cooldown circles; reset dialogue flags before loads; and added Mad Coyote tutorial/clear dialogue.

- 2026-08-28 - Made pre-dialogue Quick Roll consume the pending Q tutorial; made final-chest completion permanent and non-reenterable with Cave Moss production and outlined `Cleared` badges; and changed the completion ascent to a fixed camera, two-second half-opacity light fade, six-second rotating float, and transition after five floating seconds.
- 2026-08-28 - Colored enemy-skill flashing outlines by damage type, added a three-pixel white snare circle, suppressed overworld popups in dungeons, preserved multi-skill cooldown rotation through pursuit, standardized charge text as `Big Attack`, and moved the mana-warning dialogue to the first Spider defeat.

- 2026-08-28 - Kept boss music/zoom active through pursuit and pauses until disengagement; added the saved first-snare warning for players without Quick Roll; persisted dungeon player/room/respawn locations; and suppressed off-room enemy combat audio.

- 2026-08-28 - Enabled number-key loading while inside dungeons with direct restoration of the saved active dungeon, and added Toad, Dung Beetle, Spider, and Salamander enemy variants.

- 2026-08-27 - Limited dungeon equipment cross-outs to occupied slots, added final range/world validation to player Auto Fight and Lio hunter damage, and added quick/charged Fan Strike and Driving Strike enemy skills with 0.8/1.5-second windups and 0.2-second secondary impacts.

- 2026-08-27 - Made skill-picker clicks immediately hold a centered 32px icon for drag-only assignment with 24px slot snapping, standardized skill frames at 42px, and added a final-chest light-beam ascent that flows into the overworld dungeon exit.

- 2026-08-27 - Replaced the skill picker with a text-free five-column icon grid; shifted skill icons two pixels up-left and anchored hotkeys at bottom-right; disabled equipment bonuses with red slot lines in dungeons; crossed out occupied-room mana regeneration; and made Cascading Sweep/Surround snare Mira with movement-skill escapes and feedback.

- 2026-08-27 - Reworked skill changing into a persistent arranging mode with larger targets, movement diagrams, replacement previews, drag and click assignment, valid/invalid highlights, magnetic hover and snap confirmation, plus Done/Escape/outside-click closing; retained the existing icons and sounds.

- 2026-08-27 - Reviewed the skill-changing interaction and recommended prioritizing distinct skill identities, clearer drag targets and replacement previews, and a brief audiovisual snap confirmation after equipping.

- 2026-08-27 - Changed every resolving enemy-skill tile to independently play `sfxBigAttack`, and made active unfinished dungeons auto/manual-save and round-trip their temporary stats, keys, enemies, reward flags, pickups, exploration, chests, and doors while loading Mira safely in the overworld.

- 2026-08-27 - Preserved rewards when still-living enemies are replaced after room abandonment while keeping previously killed slots rewardless, and changed the blocked-regeneration mark to a three-pixel bottom-left-to-top-right cross-out.

- 2026-08-27 - Made abandoned-room replacement enemies permanently rewardless; added persistent inventory, equipment-pair, and skill-slot chest rewards; added the forced second-skill swap-button tutorial; added Cascading Surround with two 0.4-second caster-side strikes; and added the Evil Scorpion enemy variant.

- 2026-08-27 - Fixed Snakemouth enemies outside the starting room by completing each room's initial enemy wave when its navigation activates, without changing authored long cooldowns or reviving cleared one-time spawns.

- 2026-08-27 - Paused health and mana regeneration in occupied dungeon rooms; restored full enemy waves when abandoning an uncleared room; set all three rolls to four-second cooldowns; added Quick Roll's counter-clockwise blocked-tile fallback; and outlined hidden chests with white dots.

- 2026-08-27 - Made the Cascading Sweep tutorial clear Q's cooldown and provide five mana; removed unintended dungeon defense baselines; fit both maps to explored bounds; gated dungeon chest visibility and its reveal sound on room clear; and added charge, roll, unavailable-skill, and damage-tint feedback with same-frame charge-sound deduplication.

- 2026-08-27 - Fixed the first enemy-skill tutorial side-step being cancelled on the next frame when combat began through an active click-to-chase target.

- 2026-08-27 - Changed both the first enemy-skill movement tutorial and the first Cascading Sweep Q tutorial to pause their windups after a 0.4-second delay.

- 2026-08-27 - Kept enemy-skill damage numbers visible for 0.8 seconds, raised default enemy-skill damage to five times normal, and added persistent first-skill side-tile and first-Cascading-Sweep Q-cast combat tutorials with action-locked dialogue.

- 2026-08-26 - Simplified dungeon hover cards; changed dungeon starting health to 10; added Bat/Millipede enemies, three-slot telegraphed enemy skills, saved player mana/regeneration, four player skills, skill/chest rewards, player/Asha toolbars and picker, skill tooltips, and rapid clear-room dungeon mana regeneration.

- 2026-08-26 - Extended the dungeon-stairs upward walk to 1.2 seconds and made its exit transition begin after 0.8 seconds while allowing the traversal to finish behind it.

- 2026-08-26 - Added an alternating `Dungeon1.mp3` / `Dungeon2.mp3` background playlist that crossfades on dungeon entry and restores overworld music on exit.

- 2026-08-26 - Raised the one-second stairs traversal by 20 pixels and pre-positioned/flushed the overworld camera beneath the dungeon transition to eliminate its one-frame exit jump.

- 2026-08-26 - Removed predefined dungeon-room data and legacy layout-room state, added a one-second diagonal stairs traversal, and returned Mira beside the same overworld entrance with a one-second reverse emergence after the screen transition.

- 2026-08-26 - Added reusable dungeon exit stairs, preserved the overworld camera with a separate dungeon camera, made visited rooms the sole map/minimap visibility source, drew dungeon walls black, and removed map-opening spikes with revision caches and throttled redraws.

- 2026-08-26 - Made dungeon maps and minimaps display and scale only to visited rooms, including dynamically explored rooms beyond the predefined layout and their restoration from snapshots.

- 2026-08-26 - Moved every dungeon room-transition trigger one tile closer to its camera boundary while preserving the existing arrival depths and manual wall blocking.

- 2026-08-26 - Removed coded dungeon border walls and declared-room movement gates; navigation now expands indefinitely in every direction, with only manually painted wall tiles blocking movement.
- 2026-08-26 - Added left, upper, and lower room markers to Test Dungeon 1 so its starting room supports all four transition directions without modifying its existing exported room layout.
- 2026-08-26 - Made authored dungeon wall tiles solid for navigation, safely relocates a wall-authored entry point without changing its export, and requires outward movement intent at each camera margin before automatically transferring rooms.
- 2026-08-26 - Added the centered dungeon tutorial popup, corrected chest portrait/static reward presentation, implemented directional room thresholds and landing depths, made entrance names entry-only area titles, snapped the exit camera, added Mira's saved first-exit reaction, and fixed freed-node snapshot scans during dungeon re-entry.
- 2026-08-26 - Changed dungeon room transitions to trigger on connecting edge tiles and move Mira onto the next tile inside the adjacent room, with doorway re-arming that prevents immediate bounce-back.
- 2026-08-26 - Fixed standalone Dungeon Entrance placement failing to parse by removing its circular compile-time dependency on `DungeonManager`; added regression coverage for loading and instantiating the entrance without a manager.
- 2026-08-26 - Added the reusable isolated dungeon system with animated entrances, fixed room cameras, off-camera enemy freezing, independent maps/fog, temporary/persistent dungeon stats, map exits, per-dungeon snapshots and keys, clear/locked doors, reward chests, clear labels, Cave Moss production, difficulty tooltips, death/room healing rules, and two attached test dungeon scenes.

- 2026-08-26 - Removed long floor-color seams by retaining flat Perlin variation in tile interiors while feathering the tint into the continuous world-space fields across each eight-pixel tile edge.
- 2026-08-25 - Added a return-finished centering phase so entering the enemy's home radius mid-step cannot leave it halfway between tiles before patrol resumes.
- 2026-08-25 - Added a one-time tile-centering phase when an enemy exhausts its three-tile post-combat pursuit, before it begins returning home.
- 2026-08-25 - Made combat centering independent per participant: stationary players, helpers, and enemies center themselves while any moving participant remains untouched.
- 2026-08-25 - Revalidated combat alignment against current positions whenever both actors stop, fixing stale escape-pursuit state that could leave stationary enemies off-center.
- 2026-08-25 - Gated combat centering until both participants are stationary and made new movement cancel an active centering tween, ensuring movement and escape paths always take priority.
- 2026-08-25 - Preserved completed combat-entry alignment throughout the three-tile escape pursuit so an enemy catching up on later tiles cannot repeatedly lerp the fleeing player backward.
- 2026-08-25 - Made combat tile-centering a one-time entry transition so the player can immediately path away afterward, while enemies retain their three-tile post-combat pursuit.
- 2026-08-25 - Reduced both floor Perlin sampling scales by 30% and made players, hunter NPCs, and enemies lerp to their intended tile centers before combat attacks begin.
- 2026-08-25 - Aligned floor-color quantization with the real 64-pixel TileMap boundaries and moved the Perlin sampling offset after cell selection, removing half-tile color splits and visible noise seams.
- 2026-08-25 - Restored one whole hue and brightness value per floor cell while retaining world-locked Perlin coordinates to eliminate TileMap chunk seams and repetition.
- 2026-08-25 - Replaced tile-quantized floor color sampling with unbounded continuous world-space Perlin fields, removing the long abrupt transition bands while keeping location-specific variation.
- 2026-08-25 - Doubled the spatial scale of both floor Perlin patterns by halving their hue and brightness sampling frequencies.
- 2026-08-25 - Offset both floor color-variation grids by `(-32, -32)` pixels while retaining tile-specific Perlin sampling.
- 2026-08-25 - Widened both per-floor-tile Perlin color shifts from -5 through +5 to -15 through +15.
- 2026-08-25 - Added deterministic per-floor-tile hue and brightness variation from two independent Perlin noise distributions, each constrained to -5 through +5.
- 2026-08-25 - Renamed the forest music area to Whippersnapper Woods, raised Deru's hunter damage to 7, tightened Asha's banner around its title beneath her portrait, shortened reveal pauses to 0.25 seconds, replaced the gate sound with immediate `AshaJoins.mp3`, and ducked biome music until dismissal.
- 2026-08-25 - Refined Asha's input-gated join celebration into a spaced sequence of a right-entering black banner, portrait reveal, persistent rotating sun-ray fade, and title pop with no explanatory lines; mapped the first three second-row floor tiles to the Forrest1/Forrest2 playlist; and added boss-marked spawners whose fights play `Boss.mp3` and slightly zoom the camera.
- 2026-08-25 - Replaced Deru's repaired-cart shop with an AreaID 2 hunter/helper loop and supplied dialogue, gave him a 3-Gem large-handoff fee, added campfire helper reward/price hover cards, and permanently retired Asha's shop after recruitment.
- 2026-08-24 - Prevented minimap fog clicks from entering unexplored terrain by limiting their thirty-tile nearest-reachable fallback to explored cells.
- 2026-08-24 - Added a fog-respecting blue dotted trace of Mira's remaining movement route to both the minimap and Tab world map.
- 2026-08-24 - Restored fog of war on the terrain minimap, widened its horizontal terrain scale to fill the panel, and added click-to-move with a thirty-step nearest-reachable fallback for blocked destinations.
- 2026-08-24 - Made the top-right minimap a terrain-scaled local version of the world map, added green NPC dots, and limited damage-color enemy dots to a twenty-tile radius.
- 2026-08-21 - Named the player Mira; made unaffordable shop rows hoverable with instant inventory-style cards; expanded bull warning range to seven tiles; added health/regeneration cells and a progressive ShieldIcon color-defense grid; implemented saved red/yellow/blue flat defense; and explicitly connected ChickenSpawn12's Evil Goat dialogue.
- 2026-08-21 - Added typewriter dialogue with punctuation timing, two-step advance, portrait/box motion, a pulsing continue arrow, and stable per-conversation sizing; added staggered Store rows, animated hover and result previews, purchase/failure feedback, HUD-bound reward motion, Asha reactions, and interaction-state restoration after the thank-you dialogue.
- 2026-08-20 - Changed Asha's introduction to a first-interaction welcome followed by the shop; added persistent one-time dialogue for the first shop purchase, producer builds, campfire adjacency/discovery/teleport, cave-bull proximity and victory, gate crossing, and Evil Goat kill; and queued overlapping story events safely.
- 2026-08-20 - Simplified every story conversation to at most six messages; delayed Nia's opening until the player enters her three-tile radius; focused Nia/Lio on the cave bull blocking the desert; added their one-line repeat interactions; gave Asha the requested wares prompt; and made dialogue width fit each line.
- 2026-08-20 - Reduced the story to four focused conversations, strengthened the player's goal and the roles of Asha and Lio, and made dialogue identity switch sides and portrait orientation by speaker.
- 2026-08-20 - Rewrote the first seven story beats as natural conversations, centered and narrowed the dialogue box, paused all story fox movement during dialogue, corrected Asha's opening direction to east, cached enemy occupancy/target conflicts and combat adjacency, staggered initial patrol work, and throttled minimap redraws to address high-enemy-count frame loss.
- 2026-08-20 - Added a persistent bottom-screen portrait dialogue system and the first seven story beats; renamed the shopkeeper asset and scene to FoxAsha; added roaming FoxLio and FoxNia characters using their supplied sprites; and connected story progress to proximity, enemy Health absorption, distance-based returns, runtime respawns, and the first gate.
- 2026-08-20 - Added persistent explored-area fog of war and discovered-only Campfire/resource/shop map markers; drew independent dark-gray obstacles and terrain-type colors; restored compact enemy color dots and merged enemy combat colors; flipped and animated the shopkeeper; improved unaffordable/damage shop presentation and lowered damage's base cost to 5 Gold; and added Kangaroo Rat and Mad Coyote enemies.

- 2026-08-20 - Renamed and rebuilt the Stats Shop with icon-led full-row purchase buttons; made buildings and deposits conditional universal route blockers; added enemy outgoing/taken colors, flat armor, combat-stat icons, and minimum-one damage; saved hidden player defense; made the shopkeeper roam and highlight; and added a Tab world map with campfire teleport buttons.

- 2026-08-20 - Added Snake, Camel, Crocodile, and Mouse enemy variants; added a blocking clickable shopkeeper that the player approaches before opening a content-fitted shop; implemented discovery-gated Gold/Jewel/Fish/Wood stat purchases with linearly escalating prices; and persisted purchase counts with X, Escape, and outside-click closing.

- 2026-08-20 - Added Inspector-friendly typed enemy drop rows; renamed the fishing construction action to Build Hut; changed higher regeneration into evenly spaced one-health restores; added the Shift+O debug stat menu; and added persistent Oak/Palm wood lodges plus +15 Wood Crates using the requested sprites and production intervals.

- 2026-08-20 - Allowed players and enemies to leave tiles occupied by newly built structures; made building tooltip ownership robust; changed mine production hover text to per-second rates; added Evil Goat and Crab enemy variants; and added the Fish resource, Fishing Spot/Mine, +5 Fish Crate capacity building, placement, production, and save support.

- 2026-08-19 - Made damage dots renderer-safe; corrected exact resource-panel content fitting; kept shack buttons available under actors and suppressed exhausted mine highlights; added icon-led mine/shack stat hover cards; resolved enemy shared-target pushing by yielding to the current tile; and added persistent PileOfGems mines plus +10-capacity Gem Shacks with the requested Jewel/Gold costs and three-minute production.

- 2026-08-19 - Raised damage dots above grid cells; rebuilt the mine-cost card with a full-size image, left-side costs, 8px margins, and above-button placement; added yellow ore/mine hover outlines; added adjacent Gold Shack construction for 10 Gold with stackable +15 capacity and save support; and added Shift+P resource filling.

- 2026-08-19 - Fixed damage-row dots to red/yellow/blue order; added compressed save slots 0-9 with Shift-number save and number load; persisted player, resources, mines, gates, pickups, spawns, and enemies; and added wall-clock catch-up for recovery, cooldowns, production, and repeated respawns up to capacity.

- 2026-08-19 - Rebuilt the top-left damage HUD as a filtered color-by-weapon sum matrix; hid values of one and empty row/column categories; made the TileGrid 20% opaque; and added HelmetIcon/SwordIcon placeholders beneath toolbar locks.

- 2026-08-17 - Preserved all placed-node exported values; made enemy rewards larger and bottom-aligned, with 16px icons and icon-free `+damage`; added the visible 16px Damage header; made discovered resources explicitly reveal the bottom-left HUD; made affordable mine controls tooltiped, disabled when unaffordable, and HUD-layered over the grid; and made Auto Merge conditional with pre-merge item travel animation.

- 2026-08-17 - Reworked enemy rewards into selectable Damage, Health, and Resource types with color/resource selection and flying reward orbs; added Jewels, a 5 Gold/2 Jewel mine cost, compact 8px-margin resource UI, mine +1 feedback, and color-only damage rows.
- 2026-08-17 - Added selectable Cow and Bull enemy variants, spawn-exported stat rewards and resource drops, progressive damage HUD visibility, satisfying merge feedback, a black 64px grid, Gold Ore mining, a capped multi-resource production system, bottom-left discovered resources, and a color-dot minimap.

- 2026-08-17 — Added persistent document-maintenance protocol: read `codex.md` at the start of every prompt and update it after the request is handled.
- 2026-08-17 — Made combat stationary for adjacent enemies; added lunge, hit, and opaque black-outlined multi-slash feedback; granted enemy color rewards on death; replaced enemy reward dot with a colored/yellow reward label; rebuilt the top-left damage panel as a progressive color-by-equipped-weapon sum table.
- 2026-08-17 — Changed ground items to tile-step absorption pickups with floating shadows; added combat rings, per-weapon cooldown overlays, viewport-clamped tooltips, toolbar locks, and inventory/toolbar repositioning.
- 2026-08-17 — Made the damage HUD a persistent color-by-four-weapon sum table; added inventory Auto Merge; moved enemy health and damage controls to spawn markers; reduced and softened slash effects; and raised damage popups over walls.
