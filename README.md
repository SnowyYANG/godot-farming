# Godot Farming Game

A small pixel-art farming game made with Godot: till the soil, plant seeds, water them and harvest.

![screenshot](docs/screenshot.png)

## Features

* Tile-based field: hoe a tile into soil, water it into wet soil (TileMapLayer terrains handle the autotiling)
* Three tools: hoe, watering can, and a seed panel listing every crop with its seed icon
* 11 spring crops with 7-frame growth animations: asparagus, broccoli, cabbage, carrot, cauliflower, onion, parsnip, potato, rice, spring onion, strawberry
* Day cycle: a planted crop grows one stage per game day and only if it was watered that day - rain or shine, the wet soil dries up every morning
* Harvest animation flies into the stock panel and raises that crop's counter
* Crop data is Resource based (`data/crops/*.tres`): add a new crop by adding one resource file, and edit every crop in a single table with the bundled "Edit Resources as Table" editor plugin
* TODO:
  - Sound effects and music
  - More crops and seasons
  - Save and load

## How to play

Pick a tool at the bottom left, then left click a tile on the field:

1. **Hoe** a tile: grass turns into soil
2. pick a **seed** in the right hand column and plant it on a soil tile
3. **Water** it - and water it again every game day, otherwise it stops growing
4. once the crop reaches its last stage it is harvested automatically and its counter in the left hand column goes up

## Download

Alpha builds for Windows (64-bit) are attached to the [latest release](../../releases/latest).

## Running from source

Open `project.godot` with [Godot 4.7](https://godotengine.org) and press F5. Export presets for Web and Windows Desktop are included in `export_presets.cfg`.

## About

* **Program**: [Snowy](mailto:snowyyang@outlook.com)
* **Art**: [EmanuelleDev](https://emanuelledev.itch.io) - Farm RPG - Tiny Asset Pack
* **Engine**: [Godot Engine 4.7](https://godotengine.org)
* **Editor addon**: "Edit Resources as Table" by Gennady "Don Tnowe" Krupenyov (MIT, see [LICENSE](addons/resources_spreadsheet_view/LICENSE.md))

## License

* **Project**: [GPL-3.0](LICENSE)
* **Assets**
  - **Art** (*.png* - tilesets, crops, tool icons): [Farm RPG - Tiny Asset Pack](https://emanuelledev.itch.io) by **EmanuelleDev** - free for commercial and non-commercial use, modification allowed, resale and redistribution of the assets **not** allowed, credit is mandatory → [LICENSE-assets.txt](LICENSE-assets.txt)
  - **Project icon** (*icon.svg*): Godot Engine's default project icon (MIT)
  - **Editor addon** (*addons/resources_spreadsheet_view/*): MIT, © 2022 Gennady "Don Tnowe" Krupenyov
