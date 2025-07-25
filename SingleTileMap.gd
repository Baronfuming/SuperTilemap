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
			# Extract atlas coordinates using get_cell_atlas_coords
			var atlas_coords = get_cell_atlas_coords(map_pos)
			
			# Note: Texture offset is not directly retrievable via get_tile_texture_offset
			# It should be set in the TileSet editor and can be verified there
			var texture_offset = Vector2(0, 0) # Placeholder, check editor for actual values
			
			# Extract tile ID, bitmask, and height (assuming height is stored in custom data)
			var tile_id = tile_data.get_custom_data("tile_id") if tile_data.get_custom_data("tile_id") != null else -1
			var bitmask = tile_data.get_custom_data("bitmask") if tile_data.get_custom_data("bitmask") != null else -1
#			var height = tile_data.get_custom_data("height") if tile_data.get_custom_data("height") != null else -1
			
			# Print the details
			print("Clicked Tile - Map Position: ", map_pos)
			print("Atlas Coordinates: ", atlas_coords)
			print("Texture Origin: ", texture_offset) # Note: This is a placeholder
			print("Tile ID: ", tile_id)
			print("Bitmask: ", bitmask)
#			print("Height: ", height)
			print("-------------------")
		else:
			print("No tile data at position: ", map_pos)
