extends TileMapLayer

@export var override_texture: Texture2D

func _ready() -> void:
	if override_texture and tile_set and tile_set.get_source_count() > 0:
		var source: TileSetAtlasSource = tile_set.get_source(0) as TileSetAtlasSource
		if source:
			source.texture = override_texture

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Convert mouse position to map coordinates
		var mouse_pos = get_global_mouse_position()
		var map_pos = local_to_map(to_local(mouse_pos))
		
		# Get tile data at the clicked position
		var tile_data = get_cell_tile_data(map_pos)
		if tile_data:
			# Extract atlas coordinates
			var atlas_coords = get_cell_atlas_coords(map_pos)
			
			# Placeholder for texture offset (to be set in TileSet editor)
			var texture_offset = Vector2(0, 0)
			
			# Extract tile ID and bitmask from custom data
			var tile_id = tile_data.get_custom_data("tile_id") if tile_data.get_custom_data("tile_id") != null else -1
			var bitmask = tile_data.get_custom_data("bitmask") if tile_data.get_custom_data("bitmask") != null else -1
			
			# Get height from parent node (assuming SuperTilemap_Main manages grid)
			var parent = get_parent()
			var height = -1
			if parent and parent.has_method("_ready") and parent.grid.has(map_pos):
				height = parent.grid[map_pos]
			else:
				print("Warning: Could not retrieve height for position: ", map_pos)
			
			# Check neighboring tiles with Vector2i offsets
			var neighbors = {
				"up": map_pos + Vector2i(0, -1),
				"down": map_pos + Vector2i(0, 1),
				"left": map_pos + Vector2i(-1, 0),
				"right": map_pos + Vector2i(1, 0)
			}
			var neighbor_details = {}
			for dir in neighbors:
				var neighbor_pos = neighbors[dir]
				var neighbor_tile_data = get_cell_tile_data(neighbor_pos)
				var neighbor_height = -1
				if parent and parent.grid.has(neighbor_pos):
					neighbor_height = parent.grid[neighbor_pos]
				neighbor_details[dir] = {
					"position": neighbor_pos,
					"tile_id": neighbor_tile_data.get_custom_data("tile_id") if neighbor_tile_data and neighbor_tile_data.get_custom_data("tile_id") != null else -1,
					"height": neighbor_height
				}
			
			# Print the details
			print("Clicked Tile - Map Position: ", map_pos)
			print("Atlas Coordinates: ", atlas_coords)
			print("Texture Origin: ", texture_offset)
			print("Tile ID: ", tile_id)
			print("Bitmask: ", bitmask)
			print("Height: ", height)
			print("Neighbor Details:")
			for dir in neighbor_details:
				print("  ", dir, ": Position=", neighbor_details[dir]["position"], 
					  ", Tile ID=", neighbor_details[dir]["tile_id"], 
					  ", Height=", neighbor_details[dir]["height"])
		else:
			print("No tile data at position: ", map_pos)
