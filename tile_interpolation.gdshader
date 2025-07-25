shader_type canvas_item;

   uniform float interpolation_strength : hint_range(0.0, 1.0) = 1;

   void fragment() {
       vec2 uv = UV;
       vec4 color = texture(TEXTURE, uv);
       vec4 blended = mix(color, texture(TEXTURE, uv + vec2(1.0/TEXTURE_PIXEL_SIZE.x, 0.0)), interpolation_strength);
       blended = mix(blended, texture(TEXTURE, uv + vec2(0.0, 1.0/TEXTURE_PIXEL_SIZE.y)), interpolation_strength);
       COLOR = blended;
   }