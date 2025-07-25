shader_type canvas_item;

uniform vec2 tile_size = vec2(256.0, 192.0); // Size of each tile in pixels
uniform float overlap_factor : hint_range(0.0, 100) = 100; // Fraction of tile size to overlap (0.0 to 0.1)

void fragment() {
    // Get the UV coordinates
    vec2 uv = UV;
    
    // Calculate the tile's local UV within its grid (0.0 to 1.0 per tile)
    vec2 local_uv = fract(uv * (1.0 / (tile_size / TEXTURE_PIXEL_SIZE)));
    
    // Offset UV to overlap with adjacent tiles
    vec2 offset_uv = local_uv + vec2(overlap_factor, overlap_factor);
    offset_uv = clamp(offset_uv, 0.0, 1.0 + overlap_factor * 2.0);
    
    // Adjust sampling to use the offset UV
    vec2 final_uv = offset_uv - overlap_factor; // Shift back to align with tile center
    vec4 color = texture(TEXTURE, final_uv);
    
    // Blend with adjacent pixels for smoothness
    vec4 blended = mix(color, texture(TEXTURE, final_uv + vec2(1.0 / tile_size.x, 0.0)), 0.1);
    blended = mix(blended, texture(TEXTURE, final_uv + vec2(0.0, 1.0 / tile_size.y)), 0.1);
    
    COLOR = blended;
}