extends Node2D

const tilemap_scene: PackedScene = preload("res://SingleTileMap.tscn")
#const tilemap_scene: PackedScene = preload("res://test_tile_map_layer.tscn")
var textures: Array[Texture2D] = [
	preload("res://CustomTiles/Output/terrain.png"),
	preload("res://tiles_grass.png"),
	preload("res://tiles_red.png"),
	preload("res://tiles_sand.png")
]

var tile_id_to_atlas: Dictionary = {
	0: Vector2i(0, 0),  # Flat ("00")
	4: Vector2i(0, 1),  # West ("04 W")
	5: Vector2i(1, 1),  # South ("05 S")
	6: Vector2i(2, 1),  # East ("06 E")
	7: Vector2i(3, 1),  # North ("07 N")
	8: Vector2i(0, 2),  # North-West ("08 NW")
	9: Vector2i(1, 2),  # South-West ("09 SW")
	10: Vector2i(2, 2), # South-East ("10 SE")
	11: Vector2i(3, 2), # North-East ("11 NE")
	12: Vector2i(0, 3), # North-West-South ("12 NWS")
	13: Vector2i(1, 3), # West-South-East ("13 WSE")
	14: Vector2i(2, 3), # North-East-South ("14 SEN")
	15: Vector2i(3, 3), # North-West-East ("15 ENW")
	16: Vector2i(0, 4), # Steep South ("16 S+")
	17: Vector2i(1, 4), # Steep West ("17 W+")
	18: Vector2i(2, 4), # Steep North ("18 N+")
	19: Vector2i(3, 4), # Steep East ("19 E+")
	20: Vector2i(0, 5), # North-South ("20 NS")
	21: Vector2i(1, 5)  # West-East ("21 EW")
}

@export var world_width: int = 10
@export var world_height: int = 10
@export var levels: int = 15
@export var level_offset: Vector2 = Vector2(0, -8)
@export var slopes: bool = true
@export var smooth: bool = false
@export var stacking: bool = false
@export var staggered_display: bool = true
@export var tiles_per_frame: int = 10
@export var texturing: bool = false
@export var randomization: bool = true
@export_range(1, 6) var noise_octaves: int = 4
@export_range(0.0, 40.0) var noise_period: float = 30.0
@export_range(0.0, 1.0) var noise_persistence: float = 0.8
@export var noise_frequency: float = 1.0

var grid: Dictionary = {}
var tile_ids: Dictionary = {}
var maps: Array[TileMapLayer] = []

var directions: Dictionary = {
	"CORNER_N": Vector2(-1, -1),
	"CORNER_W": Vector2(-1, 1),
	"CORNER_E": Vector2(1, -1),
	"CORNER_S": Vector2(1, 1)
}

var sides: Dictionary = {
	"SIDE_N": Vector2(0, -1),
	"SIDE_W": Vector2(-1, 0),
	"SIDE_E": Vector2(1, 0),
	"SIDE_S": Vector2(0, 1)
}

var bitmasks: Dictionary = {
	"CORNER_S": 1,
	"CORNER_E": 2,
	"CORNER_W": 4,
	"CORNER_N": 8,
	"STEEP": 16
}

@export var bit_tiles: Dictionary = {
	0: 0,   # Flat tile ("00")
	1: 5,   # South corner higher ("05 S")
	2: 6,   # East corner higher ("06 E")
	3: 10,  # South and east corners higher ("10 SE")
	4: 4,   # West corner higher ("04 W")
	5: 9,   # South and west corners higher ("09 SW")
	6: 21,  # West and east corners higher ("21 EW")
	7: 13,  # South, west, and east corners higher ("13 WSE")
	8: 7,   # North corner higher ("07 N")
	9: 20,  # North and south corners higher ("20 NS")
	10: 11, # North and east corners higher ("11 NE")
	11: 14, # North, east, and south corners higher ("14 SEN")
	12: 8,  # North and west corners higher ("08 NW")
	13: 12, # North, west, and south corners higher ("12 NWS")
	14: 15, # North, west, and east corners higher ("15 ENW")
	15: 15, # North-west-east, for coherence ("15 ENW")
	16: 16, # Steep south slope ("16 S+")
	17: 17, # Steep west slope ("17 W+")
	18: 18, # Steep north slope ("18 N+")
	19: 19, # Steep east slope ("19 E+")
	20: 17, # Steep west slope ("17 W+")
	21: 16, # Steep south slope ("16 S+")
	22: 0,  # Fallback flat ("00")
	23: 16, # Steep south slope ("16 S+")
	24: 18, # Steep north slope ("18 N+")
	25: 16, # Steep south slope ("16 S+")
	26: 19, # Steep east slope ("19 E+")
	27: 19, # Steep east slope ("19 E+")
	28: 17, # Steep west slope ("17 W+")
	29: 16, # Steep south slope ("16 S+")
	30: 0,  # Fallback flat ("00")
	31: 16  # Steep south slope ("16 S+")
}

func _ready() -> void:
	if world_width <= 0 or world_height <= 0:
		push_error("World dimensions must be positive")
		return
	if levels < 1:
		push_error("Levels must be at least 1")
		return
	if tiles_per_frame <= 0:
		push_error("Tiles per frame must be positive")
		return
	if not tilemap_scene or not tilemap_scene.can_instantiate():
		push_error("TileMap scene (res://test_tile_map_layer.tscn) is invalid")
		return
	if textures.is_empty() or textures.any(func(t): return t == null):
		push_error("One or more texture resources are invalid")
		return

	print("TileMap scene path:", tilemap_scene.resource_path)
	print("Textures:", textures.map(func(t): return t.resource_path if t else "null"))

	for height in levels:
		var instance: TileMapLayer = tilemap_scene.instantiate() as TileMapLayer
		if not instance:
			push_error("Failed to instantiate TileMapLayer for height %d" % height)
			continue
		if texturing:
			var texture_index: int = floor(float(height) / float(levels) * textures.size())
			if texture_index < textures.size() and textures[texture_index]:
				instance.override_texture = textures[texture_index]
			else:
				push_warning("Invalid texture index %d for height %d, using default" % [texture_index, height])
				instance.override_texture = textures[0] if textures.size() > 0 else null
		add_child(instance)
		instance.position = height * level_offset

	for c in get_children():
		if c is TileMapLayer:
			if not c.tile_set:
				push_warning("TileMapLayer at height %d has no TileSet assigned" % c.position.y)
			else:
				maps.append(c)

	if maps.is_empty():
		push_error("No valid TileMapLayers created")
		return

	if randomization:
		seed(randi())

	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_octaves = noise_octaves
	noise.frequency = 1.0 / noise_period
	noise.fractal_gain = noise_persistence

	var min_noise: float = INF
	var max_noise: float = -INF
	var noise_values: Dictionary = {}

	for i in world_width:
		for j in world_height:
			var noise_value: float = noise.get_noise_2d(noise_frequency * i, noise_frequency * j)
			if noise_value < min_noise:
				min_noise = noise_value
			if noise_value > max_noise:
				max_noise = noise_value
			noise_values[Vector2(i, j)] = noise_value

	for i in world_width:
		for j in world_height:
			var current_noise: float = noise_values[Vector2(i, j)]
			var gridval: int = round(remap(current_noise, min_noise, max_noise, 0, maps.size() - 1))
			grid[Vector2(i, j)] = gridval
			print("Cell %s: Noise %f, Height %d" % [Vector2(i, j), current_noise, gridval])

	var cell_index: int = 0
	for cell in grid:
		var neighbor_bits: Dictionary = {}
		var neighbors: int = 0
		var neighbor_steep: Dictionary = {}
		for dir_key in directions:
			var direction: Vector2 = directions[dir_key]
			var diag_key: Vector2 = cell + direction
			if grid.has(diag_key):
				var neighbor: int = grid[diag_key]
				var height_diff: int = neighbor - grid[cell]
				if height_diff == 1:
					neighbor_bits[direction] = 1
				elif height_diff >= 2:
					neighbor_bits[direction] = 1
					neighbor_steep[direction] = true
				else:
					neighbor_bits[direction] = 0
				# Log adjacent cell details
				var adj_tile_id = tile_ids.get(grid.get(diag_key, 0), 0)
				print("Adjacent cell %s: Tile ID %d, Atlas %s" % [diag_key, adj_tile_id, tile_id_to_atlas.get(adj_tile_id, Vector2i(0, 0))])
			else:
				neighbor_bits[direction] = 0

		var side_bits: Dictionary = {}
		for side_key in sides:
			var direction: Vector2 = sides[side_key]
			var cell_key: Vector2 = cell + direction
			if grid.has(cell_key):
				var side: int = grid[cell_key]
				var height_diff: int = side - grid[cell]
				if height_diff == 1:
					side_bits[direction] = 1
				else:
					side_bits[direction] = 0
				# Log adjacent cell details
				var adj_tile_id = tile_ids.get(grid.get(cell_key, 0), 0)
				print("Adjacent cell %s: Tile ID %d, Atlas %s" % [cell_key, adj_tile_id, tile_id_to_atlas.get(adj_tile_id, Vector2i(0, 0))])
			else:
				side_bits[direction] = 0

		neighbor_bits[directions.CORNER_N] |= side_bits[sides.SIDE_N] | side_bits[sides.SIDE_W]
		neighbor_bits[directions.CORNER_W] |= side_bits[sides.SIDE_W] | side_bits[sides.SIDE_S]
		neighbor_bits[directions.CORNER_E] |= side_bits[sides.SIDE_N] | side_bits[sides.SIDE_E]
		neighbor_bits[directions.CORNER_S] |= side_bits[sides.SIDE_S] | side_bits[sides.SIDE_E]

		for neigh_direction in directions:
			if neighbor_bits.get(directions[neigh_direction], 0) == 1:
				neighbors |= bitmasks[neigh_direction]

		var steep_dir: String = ""
		if slopes and neighbor_steep.size() > 0:
			if neighbor_steep.size() == 1:
				for dir_key in neighbor_steep:
					for dir_string in directions:
						if directions[dir_string] == dir_key:
							steep_dir = dir_string
							neighbors |= bitmasks["STEEP"]
							break
					if steep_dir:
						break
			else:
				neighbors &= ~bitmasks["STEEP"]
				steep_dir = ""

		if neighbor_steep.size() > 0:
			print("Cell %s: Steep slope detected, direction %s, neighbors %d" % [cell, steep_dir, neighbors])
		else:
			print("Cell %s: Neighbors %d, Neighbor bits %s, Side bits %s" % [cell, neighbors, neighbor_bits, side_bits])

		if smooth:
			if neighbor_bits[directions.CORNER_N] == 1 \
			and neighbor_bits[directions.CORNER_W] == 1 \
			and neighbor_bits[directions.CORNER_E] == 1 \
			and neighbor_bits[directions.CORNER_S] == 1 \
			and grid[cell] < levels - 2:
				grid[cell] = min(grid[cell] + 1, levels - 1)
				neighbors = 0
				print("Cell %s: Smoothed, new height %d, neighbors reset to 0" % [cell, grid[cell]])

		var tile_id: int = 0
		if slopes and steep_dir:
			match steep_dir:
				"CORNER_S":
					tile_id = 16
				"CORNER_W":
					tile_id = 17
				"CORNER_N":
					tile_id = 18
				"CORNER_E":
					tile_id = 19
		else:
			tile_id = bit_tiles.get(neighbors, 0)

		tile_ids[grid[cell]] = tile_id
		print("Cell %s: Height %d, Bitmask %d, Tile ID %d, Atlas %s" % [cell, grid[cell], neighbors, tile_id, tile_id_to_atlas.get(tile_id, Vector2i(0, 0))])

		var atlas_coords: Vector2i = tile_id_to_atlas.get(tile_id, Vector2i(0, 0))
		maps[grid[cell]].set_cell(Vector2i(cell.x, cell.y), 0, atlas_coords)

		if stacking:
			if grid[cell] > 0:
				for level in range(grid[cell]):
					maps[level].set_cell(Vector2i(cell.x, cell.y), 0, tile_id_to_atlas[0])

		if staggered_display:
			cell_index += 1
			if cell_index % tiles_per_frame == 0:
				await get_tree().process_frame
