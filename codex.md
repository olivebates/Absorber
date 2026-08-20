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
- Input: left-click a painted floor tile to move the fox; click an enemy to chase it. Clicking a resource deposit opens its centered construction button; clicking a built producer opens capacity-building buttons on valid adjacent tiles. Clicking the White Tiger routes the fox adjacent and opens its stat shop. Ground items are collected by stepping onto their tile, never by clicking them. Shift+0-9 saves, 0-9 loads, Shift+P fills every resource to capacity, and Shift+O toggles the debug stat menu.
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
│   ├── white_tiger.tscn                 Static clickable stat-shop NPC
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
│   ├── white_tiger.gd                    Shopkeeper interaction and saved purchases
│   ├── tiger_shop.gd                     Resource-priced stat shop interface
│   ├── minimap.gd                        Top-right enemy/player map dots
│   ├── tile_grid.gd                      Screen-space 64-pixel grid overlay
│   ├── gold_ore.gd                       Ore selection and mine construction
│   ├── miner_structure.gd                Registers mine output with resources
│   ├── gold_shack.gd                     Registers a stackable Gold capacity bonus
│   ├── reward_orb.gd                     Animated enemy-reward travel orb
│   ├── damage_popup.gd                   Popup tween animation and cleanup
│   └── *.gd.uid                          Godot-generated script UID metadata; do not hand-edit
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
├── WhiteTiger (WhiteTiger)                Click-to-approach persistent stat shop
├── EnemySpawnPoint instances             Cow/Bull instances are added at runtime
├── GridOverlay (CanvasLayer)             2px black world-tile grid
└── HUD (CanvasLayer)                     Damage, resource, minimap, and inventory UI
```

`world.tscn` owns the two `TileMapLayer` resources and their painted cell data. `FloorTerrain` is the source of truth for walkable cells. `WallTerrain` overrides walkability: any painted wall cell is solid even if there is also a floor tile beneath it.

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
- `find_path(from_world, to_world, moving_actor)` returns centered, direction-compressed movement waypoints while treating other actors' cells as temporary blockers.
- `get_patrol_destination()` chooses a random walkable cell within a circular tile radius.
- `get_patrol_path()` rejects a route that would leave that patrol radius.

The script handles left clicks. Clicking a valid painted floor cell asks the fox to follow the calculated path; clicking an enemy starts chase behavior. Clicking the White Tiger selects the shortest available adjacent tile and routes the fox there before opening the shop. NPC tiles participate in navigation and construction blocking. Clicking a pickup does not collect it and instead behaves as a floor click when applicable.

### `Scripts/fox_player.gd` — `FoxPlayer`

Exports `move_speed`, `max_health`, `attack_damage`, `attack_range`, and `attack_cooldown`.

The fox follows dynamically occupied-cell-aware waypoint paths, flips its sprite on rightward movement, and bounces/rotates while walking. When a chicken is on an adjacent tile, it attacks automatically after its current weapon's cooldown using the summed damage for that enemy color. Each weapon has an independent cooldown. The fox reserves an inventory slot when it steps onto a pickup tile, then the pickup shrinks and moves into the fox before being added to inventory. Receiving damage updates the numeric health bar, creates a damage popup, and plays a hit reaction.

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
- attack a fox on a directly adjacent tile once per cooldown, for the `enemy_damage` configured by their spawn point;
- show the reward amount above the health bar; Resource rewards use the GoldOreResource icon tinted to the selected resource color;
- launch a randomized reward orb to the matching damage HUD row, player, or resource HUD before the configured Damage, Health, or Resource reward is applied;
- own an item drop table, exposed through the enemy hover tooltip, and roll configured item pickups when their health reaches zero.

Enemies clear their patrol path and remain stationary while directly adjacent to the fox. Their attacks use the same lunge/squash and compact semi-transparent outlined slash treatment. Enemies have a ground ring in their own damage color while in combat.

### `Scripts/enemy_spawn_point.gd` — `EnemySpawnPoint`

Exports:

- `respawn_time`: seconds between spawn attempts while below capacity;
- `max_enemies`: maximum live chickens owned by this marker;
- `stat_reward_amount`: displayed stat reward value;
- `enemy_health`: health assigned to every chicken created by this marker;
- `enemy_damage`: attack damage assigned to every chicken created by this marker;
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

Saved progression includes player position, health, recovery timing, stats, damage matrix, inventory/equipment, weapon cooldowns, resources/discovery, built producers and production progress, typed Gold/Gem/Fish/Wood capacity-building positions, White Tiger purchase counts, gate unlocks, ground pickups, spawn timers, and live enemy position/health. The wall-clock timestamp advances player/enemy recovery, weapon cooldowns, all mine/lodge production, and every elapsed spawn interval. Offline spawn attempts stop at each marker's `max_enemies`.

## Art and tile conventions

- All navigation tiles are 64 × 64 pixels; maintain this size when adding art or update `WorldNavigation.TILE_SIZE` and both TileSet region sizes together.
- `FloorTiles.webp` has twelve atlas cells arranged 4 columns by 3 rows.
- `WallTiles.webp` has three atlas cells arranged 3 columns by 1 row.
- Walls currently drive navigation by occupancy, not TileSet physics collision. If physics collisions are later added to the wall TileSet, retain the grid checks because they are the pathfinding authority.
- Textures use nearest filtering for pixel-art presentation.

## Styling and feedback

- Both health bars use opaque `StyleBoxFlat` resources with a two-pixel black outline, dark background, green fill, and centered current/max HP text.
- The top-left damage panel is a bordered spreadsheet-style table: its blank first cell is followed by active weapon types across the top. Active damage colors run down the left in fixed red, yellow, blue order. Each value is its color/weapon sum; values of one are not drawn, and a row or column appears only when it has a value above one. Weapon headers show their equipped item, or the generic damage icon when that damage column has no equipped item.
- The inventory is bottom-right and the toolbar is directly below it. A gold `Auto Merge` button below the inventory slots repeatedly combines matching items in the inventory. All toolbar slots are locked except weapon slot one; only that weapon slot can receive a toolbar drag/drop. Toolbar clicks return its item to inventory.
- Equipment is non-stackable. Dragging two matching item IDs of the same grade together deletes the dragged item and upgrades the target; compatible merge targets gain a yellow outline while dragging.
- Item grades progress through Gray, White, Green, Blue, Purple, Orange, Pink, and Black. Every grade has a matching background in inventory, toolbar, and enemy-drop cards. A grade raises a stat to 210% of the prior grade (double plus 10%), rounded to whole damage/block values.
- Combat feedback is intentionally world-space, not CanvasLayer UI, so it moves with actors and the camera. Combat uses colored ground rings, lunge/hit reactions, compact semi-transparent black-outlined slash effects, and wall-front damage popups.
- The only gameplay text is the enemy reward number and temporary negative-damage popup. There is no persistent HUD/status text.

## Current additions: enemies, resources, and UI

- `EnemySpawnPoint` exports a stat reward amount, Damage/Health/Resource reward type, damage reward color, resource id, Enemy Type selector (Chicken, Cow, or Bull), and optional custom scene override. Cow and Bull reuse the common enemy behavior while swapping their sprite scenes.
- `ResourceManager` is a scalable resource economy backed by `GameResourceDefinition`. Each definition has an id, name, icon, display color, maximum amount, starting amount, and base production speed. Gold Ore, Jewels, Fish, and Wood are current definitions.
- Resource rewards launch an orb to the resource HUD before adding their amount. The bottom-left resource panel begins explicitly hidden and appears as soon as the first resource is acquired; it uses an exact 8px outer margin and displays only `amount/max +speed/s` beside the icon.
- The GoldOre scene uses `Gold Ore.webp`. Hovering an empty ore or built mine outlines its tile in yellow. Clicking an empty ore reveals a centered Build Mine button without moving the fox. Its hover card is content-fitted with an 8px margin, places `Costs:` and resource rows on the left, shows the full-size building sprite on the right, and stays above the button. Its default build cost is 5 Gold Ore and 2 Jewels. Each MinerStructure registers 1 Gold Ore per 60 seconds and displays a green floating `+1` when it produces on screen.
- Clicking a built mine shows `Build Shack` buttons on valid cardinally adjacent floor tiles without walls, ores, actors, gates, or buildings. A Gold Shack costs 10 Gold and adds 15 to Gold capacity; bonuses stack and shack tiles become navigation/placement blockers.
- TileGrid is a 20%-opaque screen overlay aligned to the moving world and draws 2px black lines for every visible 64x64 tile. The minimap is top-right and draws a white player dot plus red, yellow, or blue enemy dots from each enemy's color.
- The damage grid starts hidden, then filters its color-by-weapon sums to values above one. Its first header cell is blank, its weapon headers use the equipped item or a generic 16px Damage icon, and red/yellow/blue color dots use an explicit foreground z-index above the cell panels. Empty armor and weapon toolbar slots show HelmetIcon and SwordIcon respectively; both remain beneath their lock overlay. Weapon slots that can accept a dragged weapon are outlined yellow. Successful merges now pulse, flash, and show an `UP!` burst.

## Testing and maintenance

Run the smoke test from the project root with the local executable:

```powershell
$env:APPDATA = (Resolve-Path .\.godot).Path
$env:LOCALAPPDATA = (Resolve-Path .\.godot).Path
.\Godot_v4.7.1-stable_win64.exe --headless --rendering-method gl_compatibility --path . --script res://Tests/world_smoke_test.gd
```

The world test verifies map routing and fox flipping, occupied-tile avoidance, cow/bull spawn selection, delayed Gold Ore and Jewel rewards, selectable damage reward color, compact resource HUD text, the 5 Gold/2 Jewel mine cost, mine production feedback, HUD progression, auto merging, and respawn. `save_system_smoke_test.gd` verifies compressed strings, physical number-key bindings, state restoration, and ten minutes of offline health, spawn, and mine progression. `building_smoke_test.gd` verifies visible damage dots, tooltip layout, hover outlines, valid shack placement, stacked capacity, save restoration, and Shift+P.

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
- Resources are stored in a content-fitted bottom-left panel only after first acquisition. Removed rows are detached immediately so invisible queued controls never affect sizing; its rows show icon plus `amount/max +speed/s`, and the panel has an exact 8px content margin. The top-right minimap shows a white player dot and color-coded enemy dots. A 20%-opaque black 2px grid follows every visible 64x64 world tile.
- Mines and shacks show resource-icon hover cards for production and capacity. Shack buttons remain available on temporarily actor-occupied cells, while walls, gates, deposits, and buildings remain permanent blockers. A built mine has no yellow hover outline once every adjacent shack tile is permanently blocked.
- `GemOre` uses `PileOfGems.webp`; its mine costs 5 Jewels and 2 Gold and produces one Jewel every 180 seconds. Its adjacent `GemShack` costs 10 Jewels, uses `GemShack.webp`, and adds 10 Jewel capacity.
- `FishingSpot` uses `FishSillouhettes.webp`; its construction button says `Build Hut`, the built producer uses `FishingMine.webp`, and it produces one Fish every 60 seconds. Fish starts with 20 capacity, and an adjacent 10-Fish `FishCrate` adds 5 capacity.
- `OakTree` and `PalmTree` use their matching sprites and build `WoodCuttingLodge.webp` producers. Oak produces one Wood every five minutes and palm every three minutes. Both offer adjacent 10-Wood `WoodCrate` storage that adds 15 capacity. Wood uses `WoodResource.webp`, starts at 10 capacity, and lodge progress continues during offline save/load time.
- The debug menu is hidden by default beneath the top-left damage grid. Shift+O toggles it; its plus/minus controls edit max health, regeneration, and current-weapon red/yellow/blue base damage while enforcing minimum stat values of one.
- The White Tiger shop opens only after the fox reaches an adjacent tile. Its centered box fits visible rows with exact 8px content margins and closes via its top-right X, Escape, or an outside click. Gold damage is always shown; Jewel regeneration, Fish health, and Wood health rows reveal permanently after that resource is first owned. Purchases grant +1 red damage for Gold (base 10), +1 regeneration for Jewels (base 5), or +20 max health for Fish/Wood (base 5/3). Each repeat adds its base price, and purchase counts persist in saves.
- Mine hover stats display production as a per-second rate with two decimals, or three decimals below 0.01/s. Tooltip hides are owner-aware so leaving one structure cannot dismiss another structure's popup.
- Actors standing on a newly built structure may traverse their current cell and path to an unoccupied neighboring tile, preventing players and enemies from becoming trapped.
- Enemy patrol targets are reserved deterministically. When enemies select the same tile or one selects another enemy's occupied tile, the yielding enemy targets its own current tile instead of pushing indefinitely.
- Enemy reward icons are 16px. Damage rewards instead show a colored, bottom-aligned `+amount` flush to the health bar's left edge, with no reward icon; all enemy reward text is 22px.

## Recent prompt log

- 2026-08-20 - Added Snake, Camel, Crocodile, and Mouse enemy variants; added a blocking clickable White Tiger that the fox approaches before opening a content-fitted shop; implemented discovery-gated Gold/Jewel/Fish/Wood stat purchases with linearly escalating prices; and persisted purchase counts with X, Escape, and outside-click closing.

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
