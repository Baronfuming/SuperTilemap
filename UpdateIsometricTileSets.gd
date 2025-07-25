@tool
extends EditorScript

var tile_data: Dictionary = {
	0: {"name": "0", "bitmask": 0, "width": 64, "height": 32},
	1: {"name": "reserved_1", "bitmask": -1, "width": 64, "height": 32},
	2: {"name": "reserved_2", "bitmask": -1, "width": 64, "height": 32},
	3: {"name": "reserved_3", "bitmask": -1, "width": 64, "height": 32},
	4: {"name": "04 W", "bitmask": 4, "width": 64, "height": 32},
	5: {"name": "05 S", "bitmask": 1, "width": 64, "height": 24},
	6: {"name": "06 E", "bitmask": 2, "width": 64, "height": 32},
	7: {"name": "07 N", "bitmask": 8, "width": 64, "height": 40},
	8: {"name": "08 NW", "bitmask": 12, "width": 64, "height": 40},
	9: {"name": "09 SW", "bitmask": 5, "width": 64, "height": 24},
	10: {"name": "10 SE", "bitmask": 3, "width": 64, "height": 24},
	11: {"name": "11 NE", "bitmask": 10, "width": 64, "height": 40},
	12: {"name": "12 NWS", "bitmask": 13, "width": 64, "height": 32},
	13: {"name": "13 WSE", "bitmask": 7, "width": 64, "height": 24},
	14: {"name": "14 SEN", "bitmask": 11, "width": 64, "height": 32},
	15: {"name": "15 ENW", "bitmask": 14, "width": 64, "height": 40},
	16: {"name": "16 S+", "bitmask": 16, "width": 64, "height": 16},
	17: {"name": "17 W+", "bitmask": 17, "width": 64, "height": 32},
	18: {"name": "18 N+", "bitmask": 18, "width": 64, "height": 48},
	19: {"name": "19 E+", "bitmask": 19, "width": 64, "height": 32},
	20: {"name": "20 NS", "bitmask": 9, "width": 64, "height": 32},
	21: {"name": "21 EW", "bitmask": 6, "width": 64, "height": 32}
}

@export var tileset_path: String = "res://terrain.tres"

func _run() -> void:
	var tileset: TileSet = load(tileset_path)
	if not tileset:
		push_error("Failed to load tileset at: ", tileset_path)
		return

	var atlas_source := tileset.get_source(0) as TileSetAtlasSource
	if not atlas_source:
		push_error("No atlas source found in tileset at: ", tileset_path)
		return

	var tile_size = Vector2i(256, 192)  # Current atlas tile size
	var grid_size = Vector2i(4, 6)  # 4x6 grid
	var base_height = 32  # Reference height from data

	var index = 0
	for y in grid_size.y:
		for x in grid_size.x:
			if index < tile_data.size():
				var data = tile_data[index]
				var atlas_coords = Vector2i(x, y)

				# Ensure tile exists
				if atlas_source.has_tile(atlas_coords):
					var tile_data_instance = atlas_source.get_tile_data(atlas_coords, 0)
					if tile_data_instance:
						# Set name (using custom data since set_tile_name is invalid)
						tile_data_instance.set_custom_data("Name", data["name"])

						# Set bitmask (using custom data or terrain if configured)
						tile_data_instance.set_custom_data("bitmask", data["bitmask"])

						# Adjust offset based on proportional height
						var scaled_height = int((data["height"] / float(base_height)) * tile_size.y)
						var offset_y = (tile_size.y - scaled_height) / 2
						atlas_source.set_tile_offset(atlas_coords, Vector2i(0, int(offset_y)))

				index += 1

	# Ensure isometric settings
	tileset.set_tile_shape(1)  # Isometric
	tileset.set_tile_layout(1)  # Diamond Down

	# Save the updated tileset
	ResourceSaver.save(tileset, tileset_path)
	print("Tileset updated at: ", tileset_path)
