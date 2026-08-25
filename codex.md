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
- Combat: actors automatically attack enemies on a directly adjacent tile. Enemies stop patrolling when engaged. Enemy rewards are Damage, Health, or Resource and are granted only when their flying orb reaches its destination. Damage is stored in a four-weapon by three-enemy-color matrix, while collectible weapons add their grade-scaled bonus.
- HUD: the top-left panel is a filtered color-by-weapon damage table. It shows only weapon columns and color rows that contain a summed damage value above one. Compact resources appear bottom-left after discovery, and the minimap is top-right. The inventory is bottom-right with the toolbar directly below it.
- Terrain is editor-authored. Do not generate, replace, or clear the tilemap layers in code.

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
│   ├── evil_goat_enemy.tscn / crab_enemy.tscn  Additional reusable enemy variants
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
│   ├── fox_player.gd                     Fox movement, health, attacks, and damage UI effects
│   ├── chicken_enemy.gd                  Chicken patrol, health, attacks, and damage UI effects
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
└── HUD (CanvasLayer)                     Damage, resource, minimap, and inventory UI
```

`world.tscn` owns the two `TileMapLayer` resources and their painted cell data. `FloorTerrain` is the source of truth for walkable cells. `WallTerrain` overrides walkability: any painted wall cell is solid even if there is also a floor tile beneath it.

`FloorTerrain` uses `Shaders/floor_tile_variation.gdshader`. The shader first resolves the real world-locked 64-pixel TileMap cell, then applies a shared `(-32, -32)` sampling offset to two independently seeded, unbounded Perlin fields. Their sampling scales are 30% below the previous values. Applying the offset after cell selection keeps it from putting a color boundary through the middle of a tile. Every cell receives one whole hue offset of at most 15 degrees and one whole brightness offset of at most 15 percentage points. World coordinates prevent the fields from resetting or repeating at TileMap render-chunk and viewport boundaries.

### `Scenes/world.tscn`

The game entry scene contains the hand-painted floor and wall tilemaps, the fox at `(224, 96)`, GoldOre at `(800, 160)`, a Gold Ore reward cow spawn at `(416, 96)`, and a Jewel reward bull spawn at `(800, 288)`.

Add additional enemy locations by instancing `enemy_spawn_point.tscn` under `World`, placing the marker on a painted floor cell, and changing its exported values in the Inspector. Do not place a spawn on a wall or empty cell: the spawn will correctly refuse to create an enemy there.

### `Scenes/fox.tscn`

Contains a `CharacterBody2D`, fox sprite, collision shape, outlined green `HealthBar` with numeric HP overlay, and child `Camera2D`.

The camera has zero local offset and is enabled, so its target is the fox's position. Position smoothing is enabled at speed `7.0`; this produces follow lag while keeping the camera centered on the player target. The fox's base regeneration is one health every three seconds; higher regeneration preserves the total rate but spaces it into continuous one-health restores instead of three-second bursts. The fox faces right with a horizontal flip, snaps to a tile center whenever idle, and immediately respawns at its original scene position with full health on death.

### `Scenes/chicken_enemy.tscn`

Contains the reusable enemy body, collision shape, health UI, and reward label. Cow and Bull scenes inherit it and replace the sprite texture. The label displays the spawn point's `stat_reward_amount`.

### `Scenes/enemy_spawn_point.tscn`

A `Marker2D` with `EnemySpawnPoint`. It is deliberately small so level designers can instance it freely in `world.tscn` without visible gameplay art. Once all enemies from a point are gone, it draws a radial respawn clock and countdown until the next spawn.

### `Scenes/damage_popup.tscn`

A world-space `Label` for hit feedback. It displays a red outlined negative number, starts above the damaged actor, rises 30 pixels, eases into full size, fades, and removes itself. Its high z-index keeps it in front of wall tiles.

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
- `boss`: marks this spawner's enemies as bosses for combat music and camera framing;
- `enemy_damage_taken_color`: selects which player damage-color row applies;
- `enemy_type`: Inspector selection for Chicken, Cow, Bull, Mole, Mole 2, Goat, Evil Goat, Crab, Snake, Camel, Crocodile, or Mouse;
- `enemy_scene`: optional custom-scene override;
- `reward_type`: Damage, Health, or Resource;
- `damage_reward_color`: the color increased by a Damage reward;
- `reward_resource_id`: the resource granted by a Resource reward.

The active list is explicitly rebuilt as a typed `Array[ChickenEnemy]`; do not replace it with `Array.filter()` without a safe typed conversion, because Godot returns an untyped `Array` and will raise a type-assignment error. `item_drops` is an Inspector-friendly array of `EnemyDropEntry` resources, each with item, chance, and grade selectors. The hidden legacy dictionary table remains load-compatible with already placed spawners.

### `Scripts/damage_popup.gd` — `DamagePopup`

`show_damage(amount)` formats `-<amount>`, starts the position/scale/fade tween, and connects tween completion to `queue_free()`. It deliberately uses a completion callback rather than `await`, which keeps headless tests and shutdown clean.

### `Scripts/save_system.gd` — `SaveSystem`

Provides slots 0-9 at `user://s0` through `user://s9`. Shift plus a number saves; the number alone loads. State uses short positional arrays, millisecond timer integers, and bit masks. Compact JSON is compressed with whichever built-in compression mode produces the fewest bytes, then Base64-encoded as one file string. Loading validates the version and decompressed-size bound before applying data.

Saved progression includes player position, health, recovery timing, hidden defense, stats, damage matrix, inventory/equipment, weapon cooldowns, resources/discovery, built producers and production progress, typed Gold/Gem/Fish/Wood capacity-building positions, FoxAsha purchases and position, FoxLio/FoxNia positions, dialogue progress and one-time event flags, map overlay preferences, gate unlocks, ground pickups, spawn timers, and live enemy position/health. Spawn state is keyed by stable marker name so scene child ordering cannot mix enemies between spawns; legacy positional saves and former story formats still migrate on load. The wall-clock timestamp advances player/enemy recovery, weapon cooldowns, all mine/lodge production, and every elapsed spawn interval. Offline spawn attempts stop at each marker's `max_enemies`.

## Art and tile conventions

- All navigation tiles are 64 × 64 pixels; maintain this size when adding art or update `WorldNavigation.TILE_SIZE` and both TileSet region sizes together.
- `FloorTiles.webp` has twelve atlas cells arranged 4 columns by 3 rows.
- The first three atlas cells in row one play the Grass playlist, the first three in row two play the `Forrest1.mp3`/`Forrest2.mp3` playlist and announce `Whippersnapper Woods`, and the first three in row three play the Desert playlist. Atlas coordinates are zero-based in code.
- `WallTiles.webp` has three atlas cells arranged 3 columns by 1 row.
- Walls currently drive navigation by occupancy, not TileSet physics collision. If physics collisions are later added to the wall TileSet, retain the grid checks because they are the pathfinding authority.
- Textures use nearest filtering for pixel-art presentation.
- Floor art receives deterministic, tile-specific HSV variation from separate unbounded hue and brightness Perlin distributions. Every world-locked cell receives one whole value from each field, with no reset or repetition at TileMap render-chunk boundaries. Both patterns apply a `(-32, -32)` sampling offset after selecting the cell, use sampling scales reduced by 30%, and keep shifts within -15 to +15 (degrees and percentage points, respectively).

## Styling and feedback

- Both health bars use opaque `StyleBoxFlat` resources with a two-pixel black outline, dark background, green fill, and centered current/max HP text.
- The top-left damage panel is a bordered spreadsheet-style table: its blank first cell is followed by active weapon types across the top. Active damage colors run down the left in fixed red, yellow, blue order. Each value is its color/weapon sum; values of one are not drawn, and a row or column appears only when it has a value above one. Weapon headers show their equipped item, or the generic damage icon when that damage column has no equipped item.
- The inventory is bottom-right and the toolbar is directly below it. A gold `Auto Merge` button below the inventory slots repeatedly combines matching items in the inventory. All toolbar slots are locked except weapon slot one; only that weapon slot can receive a toolbar drag/drop. Toolbar clicks return its item to inventory.
- Equipment is non-stackable. Dragging two matching item IDs of the same grade together deletes the dragged item and upgrades the target; compatible merge targets gain a yellow outline while dragging.
- Item grades progress through Gray, White, Green, Blue, Purple, Orange, Pink, and Black. Every grade has a matching background in inventory, toolbar, and enemy-drop cards. A grade raises a stat to 210% of the prior grade (double plus 10%), rounded to whole damage/block values.
- Combat feedback is intentionally world-space, not CanvasLayer UI, so it moves with actors and the camera. Combat uses colored ground rings, lunge/hit reactions, compact semi-transparent black-outlined slash effects, and wall-front damage popups.
- The only gameplay text is the enemy reward number and temporary negative-damage popup. There is no persistent HUD/status text.

## Current additions: enemies, resources, and UI

- `EnemySpawnPoint` exports rewards, health, damage, one shared red/yellow/blue combat color, flat armor, a typed drop list, an Enemy Type selector, and a `boss` checkbox. Fighting an adjacent living enemy from a marked spawner overrides biome music with `Boss.mp3` and smoothly zooms the camera to 1.12x; leaving combat restores the prior zoom. The placed Bull, Evil Goat, and Mad Coyote encounters are marked as bosses. Its sprite variants are Chicken, Cow, Bull, Mole, Mole 2, Goat, Evil Goat, Crab, Snake, Camel, Crocodile, Mouse, Kangaroo Rat, and Mad Coyote.
- `ResourceManager` is a scalable resource economy backed by `GameResourceDefinition`. Each definition has an id, name, icon, display color, maximum amount, starting amount, and base production speed. Gold Ore, Jewels, Fish, and Wood are current definitions.
- Resource rewards launch an orb to the resource HUD before adding their amount. The bottom-left resource panel begins explicitly hidden and appears as soon as the first resource is acquired; it uses an exact 8px outer margin and displays only `amount/max +speed/m` beside the icon.
- The GoldOre scene uses `Gold Ore.webp`. Hovering an empty ore or built mine outlines its tile in yellow. Clicking an empty ore reveals a centered Build Mine button without moving the fox. Its hover card is content-fitted with an 8px margin, places `Costs:` and resource rows on the left, shows the full-size building sprite on the right, and stays above the button. Its default build cost is 5 Gold Ore and 2 Jewels. Each MinerStructure registers 1 Gold Ore per 60 seconds and displays a green floating `+1` when it produces on screen.
- Clicking a built mine shows capacity-building buttons on valid cardinally adjacent floor tiles without walls, ores, actors, gates, or buildings. Every capacity building starts at 10 of the resource it stores. Producer and capacity-building prices increase by 25%, rounded up after each prior building of the same resource type. Capacity bonuses stack and their tiles become navigation/placement blockers.
- TileGrid is a 20%-opaque screen overlay aligned to the moving world and draws 2px black lines for every visible 64x64 tile. The top-right minimap renders explored nearby terrain at a twenty-tile radius, stretches the tile scale horizontally to fill its rectangular viewport, draws NPCs as green dots, and draws only explored enemies within twenty tiles as red, yellow, or blue dots matching their damage color. Clicking it routes Mira to that tile; blocked or fog-covered clicks search outward for the nearest explored, reachable tile within thirty steps. While Mira moves, both the minimap and Tab world map trace her remaining explored route with a blue dotted line.
- The damage grid starts hidden, then filters its color-by-weapon sums to values above one. Yellow and Blue rows require their base color damage to exceed one and cannot be revealed by weapon damage alone. A matching armor grid appears to its right after a shield has first been equipped, uses ShieldIcon, shows negative flat-defense values, and reveals yellow/blue rows after those base color defenses first increase. Heart current/max and regeneration cells sit beneath the grids. Empty armor and weapon toolbar slots remain beneath their lock overlay, while equipment tooltips render above the locks.

## Testing and maintenance

Run the smoke test from the project root with the local executable:

```powershell
$env:APPDATA = (Resolve-Path .\.godot).Path
$env:LOCALAPPDATA = (Resolve-Path .\.godot).Path
.\Godot_v4.7.1-stable_win64.exe --headless --rendering-method gl_compatibility --path . --script res://Tests/world_smoke_test.gd
```

The world test verifies map routing and fox flipping, occupied-tile avoidance, cow/bull spawn selection, delayed Gold Ore and Jewel rewards, selectable damage reward color, compact resource HUD text, the Gold mine cost, mine production feedback, HUD progression, auto merging, and respawn. `save_system_smoke_test.gd` verifies compressed strings, physical number-key bindings, state restoration, and ten minutes of offline health, spawn, and mine progression. `building_smoke_test.gd` verifies visible damage dots, tooltip layout, hover outlines, valid shack placement, stacked capacity, save restoration, and Shift+P.

When editing the project:

1. Preserve `FloorTerrain`, `WallTerrain`, and `Fox` node names unless corresponding `$NodeName` references are updated in `world.gd`.
2. Paint floor beneath all intended traversable spawn and patrol cells.
3. Use `WallTerrain` for every blocking tile; the pathfinder reads that layer directly.
4. Keep `player`, `enemies`, and `world_navigation` groups intact unless all lookup sites are updated.
5. Update this file after every user prompt, even if the prompt only changes a small behavior.

## Current UI and feedback behavior

- The top-left panel begins hidden and becomes a filtered damage matrix once a color/weapon sum exceeds one. Its first cell is blank; each visible weapon type is an icon header, visible color-dot rows are always ordered red, yellow, then blue, and cells with a value of one are blank. An active row or column always has at least one displayed number.
- The inventory sits at bottom-right, above the toolbar. Its gold `Auto Merge` button is present only while an inventory merge is possible; on click, each source item visibly travels onto its matching target before the merge resolves. The toolbar retains four weapon and four armor slots, but all are visibly locked except weapon slot one. Empty armor slots use HelmetIcon and empty weapon slots use SwordIcon, under the lock overlay where present. Clicking an unlocked toolbar item moves it to the first compatible inventory slot. Weapon slot icons have independent transparent-black cooldown overlays that shrink as cooldown expires.
- Item and enemy drop tooltips are clamped to the camera viewport.
- Ground pickups have a translucent elliptical shadow and a gentle vertical float.
- Resources are stored in a content-fitted bottom-left panel only after first acquisition. Removed rows are detached immediately so invisible queued controls never affect sizing; its rows show icon plus `amount/max +speed/m`, and the panel has an exact 8px content margin. The clickable top-right minimap shows explored local terrain and a white player dot, green NPC dots, explored damage-color enemy dots within twenty tiles, and Mira's active route as blue dots; the Tab map shows the same route treatment. Blocked or fog-covered minimap destinations fall back to the nearest explored, reachable tile within thirty steps. A 20%-opaque black 2px grid follows every visible 64x64 world tile.
- Mines and shacks show resource-icon hover cards for production and capacity. Shack buttons remain available on temporarily actor-occupied cells, while walls, gates, deposits, and buildings remain permanent blockers. A built mine has no yellow hover outline once every adjacent shack tile is permanently blocked.
- `GemOre` uses `PileOfGems.webp`; its mine starts at 5 Jewels and 2 Wood and produces one Jewel every 180 seconds. Gem storage starts at 10 Jewels, while `GemShack.webp` adds 10 Jewel capacity.
- `FishingSpot` uses `FishSillouhettes.webp`; its construction button says `Build Hut`, the built producer uses `FishingMine.webp`, and it produces one Fish every 60 seconds. Huts start at 5 Fish and 2 Gold; Fish storage starts at 10 Fish. Fish starts with 20 capacity, and a `FishCrate` adds 5 capacity.
- `OakTree` and `PalmTree` use their matching sprites and build `WoodCuttingLodge.webp` producers. Oak produces one Wood every five minutes and palm every three minutes. Lodges start at 5 Wood and 2 Fish; Wood storage starts at 10 Wood. A `WoodCrate` adds 15 capacity. Wood uses `WoodResource.webp`, starts at 10 capacity, and lodge progress continues during offline save/load time.
- The debug menu is hidden by default beneath the top-left combat HUD. Shift+O toggles it; its plus/minus controls edit max health, regeneration, and red/yellow/blue base damage and defense.
- FoxAsha, FoxLio, and FoxNia roam within two tiles of their scene positions using Mira's bob-and-tilt walk cycle, pause while approached, block navigation, and show a yellow hover outline. Before recruitment, FoxAsha's Store opens only after Mira reaches an adjacent tile and no story conversation is due. Its top rows sell one Fish or Wood for 2 Gold, followed by its stat upgrades; the former Fish-priced health upgrade is no longer offered. Buying Deru's Spare Cart Parts recruits Asha, permanently closes her Store, and turns her into Mira's healing follower. Her join moment locks gameplay while a text-height black banner slides in from the right beneath Asha, then pauses for 0.25 seconds between the portrait appearing, rotating sun rays fading in, and `Asha joins the party!` popping into view. `AshaJoins.mp3` begins with the banner while biome music quickly fades out; the title receives the camera punch. There are no explanatory lines below it. After at least three seconds a continue prompt appears, and the rays keep rotating until any key or mouse click closes the celebration and restores biome music. Lio's Store sells one Gold for 2 Fish, +4 red damage for 5 Fish, and +20 health for 5 Jewels, with every offer visible immediately. Store buttons remain enabled and visibly highlight even when unaffordable. Inventory-style hover cards appear instantly, follow the pointer, and preview the current and resulting amount. Rows stagger into view, lift and enlarge their icon on hover, flash and send icons toward the HUD on success, or shake and show the missing cost on failure. Asha and Lio react to their first purchases, and the dialogue preserves the focused row and pointer when the Store reopens. The centered box fits visible rows with exact 8px content margins and closes via its top-right X, Escape, or an outside click.
- Giving the Spare Cart Parts to Deru repairs his cart and recruits him as a hunter instead of unlocking a shop. He uses Lio's invulnerable hunter loop against eligible AreaID 2 enemies but deals 7 damage per hit, carries their rewards, returns to the AreaID 2 campfire, and waits there for handoff. Small handoffs are free; larger handoffs cost Deru's distinct 3-Gem fee rather than Lio's 3 Gold. Hovering a helper who is waiting with rewards at a campfire opens the shared equipment-style tooltip, listing every carried reward followed by `Price: Free` or the helper's price. Hunter state, collected rewards, fee authorization, position, and repaired visuals persist in saves, including migration from older Deru saves.
- The compact bottom dialogue panel fits the longest message in each conversation horizontally up to a readable wrapping limit, stays centered, and enters with a short slide-and-scale motion. Text reveals progressively with punctuation pauses; the first advance completes the line and the next continues. A pulsing arrow replaces instructional copy after each line finishes, while the active portrait pops, brightens, and gently bobs. Mira's unflipped portrait and name appear on the left; NPC identity appears on the right with the portrait flipped toward the text, except Asha, whose portrait remains unflipped. All story foxes stop walking while it is open. Lio remains silent on proximity, introduces his gold-and-fish trade on first interaction, reacts when the nearest gold rock receives a mine, and thanks Mira after his first purchase. Asha's welcome runs only on her first direct interaction and opens the shop afterward. Persistent remarks include a seven-tile cave-bull warning and a ChickenSpawn12 Evil Goat kill trigger.
- Enemy physics calculates player adjacency once per enemy tick, caches player/world references, and uses one world-level occupied/target-cell cache per physics frame instead of scanning every enemy for every moving enemy. Newly spawned enemies receive a randomized initial patrol delay so mass spawns do not request paths together. The minimap redraws at 10 Hz instead of every rendered frame; these changes keep large enemy populations from producing quadratic patrol-conflict costs and synchronized pathfinding spikes.
- Tab opens a terrain-scaled world map overlay with persistent fog of war and a six-tile reveal radius. Explored terrain uses atlas-type colors; the final three second-row Biome3 wall tiles render blue while other wall obstacles are dark gray. Enemy and building sprite overlays each have a bottom-left visibility toggle, default off, and their states persist in saves. Only visited Campfires appear and accept teleporting. Reaching Campfire2 shows `TAB` above the fox until Tab is pressed. Exploration, Campfire visits, overlay preferences, and tutorial dismissal persist; Tab toggles and Escape closes the map.
- Enemy health bars use the original compact colored dot beneath the bar. A spawner's single enemy combat color now controls both the damage color it deals and the color of player damage used against it; armor remains a flat reduction with minimum-one damage.
- Mine hover stats display production as a per-second rate with two decimals, or three decimals below 0.01/s. Tooltip hides are owner-aware so leaving one structure cannot dismiss another structure's popup.
- Actors standing on a newly built structure may traverse their current cell and path to an unoccupied neighboring tile, preventing players and enemies from becoming trapped.
- Enemy patrol targets are reserved deterministically. When enemies select the same tile or one selects another enemy's occupied tile, the yielding enemy targets its own current tile instead of pushing indefinitely.
- Enemy reward icons are 16px. Resource reward icons above enemy health bars retain their original texture colors, while their numbers are always gold. All enemy reward text is 22px.

## Recent prompt log

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
