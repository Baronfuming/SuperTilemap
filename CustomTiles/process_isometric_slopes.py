from PIL import Image
import os
import numpy as np
import subprocess

# Configuration variables
INPUT_FOLDER = "./Input"
OUTPUT_FOLDER = "./Output"
TEXTURE_PATH = "./texture.png"
TARGET_SIZE = (256, 128)  # Dimensions for resizing images and texture
SHADING_FACTOR = 0.4  # Base shading intensity for shadermap
COLOR_TOLERANCE = 75.0 / 255.0  # Tolerance for detecting CYM colors

def load_texture(texture_path):
    """Load and return the texture image."""
    return Image.open(texture_path).convert('RGBA')

def create_shadermap(img_array, target_size=TARGET_SIZE):
    """Create a shadermap image based on CYM color-coded shading regions."""
    # Define color thresholds (normalized to [0,1])
    def g(v): return v / 255.0
    colors = {
        "unshaded": np.array([g(0), g(255), g(255)]),  # Cyan
        "lightly_shaded": np.array([g(255), g(0), g(255)]),  # Magenta
        "heavily_shaded": np.array([g(255), g(255), g(0)])  # Yellow
    }
    
    # Create shading map based on color pixels
    rgb = img_array[:, :, :3]
    
    # Initialize shading factor
    shading_factor = np.zeros((img_array.shape[0], img_array.shape[1]))
    
    # Detect main colors and assign shading factors
    total_pixels = np.prod(img_array.shape[:2])
    for category, color in colors.items():
        color_distance = np.sqrt(np.sum((rgb - color) ** 2, axis=2))
        mask = color_distance < COLOR_TOLERANCE
        if category == "unshaded":
            shading_factor[mask] = 0.0  # No shading (white)
        elif category == "lightly_shaded":
            shading_factor[mask] = 1.5  # Medium-dark shading
        elif category == "heavily_shaded":
            shading_factor[mask] = 1.0  # Dark shading
        # Debug: Print percentage of pixels classified
        if np.any(mask):
            percent = np.sum(mask) / total_pixels * 100
            print(f"{category}: {percent:.2f}% of pixels")
    
    # Interpolate for unclassified pixels (gradients)
    for y in range(img_array.shape[0]):
        for x in range(img_array.shape[1]):
            if shading_factor[y, x] == 0.0:  # Not classified
                pixel = rgb[y, x]
                distances = {cat: np.sqrt(np.sum((pixel - col) ** 2)) for cat, col in colors.items()}
                sorted_dists = sorted(distances.items(), key=lambda x: x[1])
                cat1, dist1 = sorted_dists[0]
                cat2, dist2 = sorted_dists[1]
                if dist1 < COLOR_TOLERANCE * 2:  # Wider tolerance for fallback
                    shading_factor[y, x] = {
                        "unshaded": 0.0,
                        "lightly_shaded": 1.5,
                        "heavily_shaded": 1.0
                    }[cat1]
                else:
                    # Interpolate between closest two colors
                    total_dist = dist1 + dist2
                    if total_dist == 0:
                        continue
                    t = dist1 / total_dist
                    if cat1 == "unshaded" and cat2 == "lightly_shaded" or cat1 == "lightly_shaded" and cat2 == "unshaded":
                        shading_factor[y, x] = t * 0.0 + (1 - t) * 1.5
                    elif cat1 == "lightly_shaded" and cat2 == "heavily_shaded" or cat1 == "heavily_shaded" and cat2 == "lightly_shaded":
                        shading_factor[y, x] = t * 1.5 + (1 - t) * 1.0
                    elif cat1 == "unshaded" and cat2 == "heavily_shaded" or cat1 == "heavily_shaded" and cat2 == "unshaded":
                        shading_factor[y, x] = t * 0.0 + (1 - t) * 1.0
    
    # Debug: Print shadermap grayscale values for key colors
    for category, color in colors.items():
        mask = np.sqrt(np.sum((rgb - color) ** 2, axis=2)) < COLOR_TOLERANCE
        if np.any(mask):
            avg_shading = np.mean(shading_factor[mask] * SHADING_FACTOR)
            print(f"Shadermap grayscale value for {category} color {color*255}: {1.0 - avg_shading:.3f}")
    
    # Create shadermap (grayscale with alpha)
    shadermap = np.ones_like(img_array)  # Initialize with white
    shadermap[:, :, :3] = (1.0 - shading_factor * SHADING_FACTOR)[:, :, np.newaxis]  # Shading intensity
    shadermap[:, :, 3] = img_array[:, :, 3]  # Preserve alpha for all non-transparent pixels
    
    return shadermap

def process_image(input_path, output_path, texture, target_size=TARGET_SIZE):
    """Process a single image: scale, apply texture, and overlay shadermap."""
    # Load the input image
    img = Image.open(input_path).convert('RGBA')
    
    # Scale the image to target size
    img_scaled = img.resize(target_size, Image.Resampling.LANCZOS)
    
    # Convert images to numpy arrays
    img_array = np.array(img_scaled).astype(float) / 255.0  # Normalize to [0,1]
    
    # Debug: Print unique RGB values
    unique_colors = np.unique((img_array[:, :, :3] * 255.0).reshape(-1, 3), axis=0)
    print(f"Unique RGB values in {input_path}: {unique_colors}")
    
    # Resize texture
    texture = texture.resize(target_size, Image.Resampling.LANCZOS)
    texture_array = np.array(texture).astype(float) / 255.0  # Normalize to [0,1]
    
    # Create shadermap
    shadermap_array = create_shadermap(img_array)
    
    # Save shadermap for debugging
    shadermap_img = Image.fromarray((shadermap_array * 255.0).astype(np.uint8), mode='RGBA')
    shadermap_path = os.path.join(os.path.dirname(output_path), f"shadermap_{os.path.basename(output_path)}")
    shadermap_img.save(shadermap_path)
    
    # Create mask for non-transparent pixels (alpha > 0)
    non_transparent_mask = img_array[:, :, 3] > 0
    
    # Initialize output array with transparent background
    output_array = np.zeros_like(img_array)
    output_array[:, :, 3] = img_array[:, :, 3]  # Preserve alpha channel
    
    # Apply texture to non-transparent pixels
    output_array[non_transparent_mask, :3] = texture_array[non_transparent_mask, :3]
    
    # Apply shadermap by multiplying RGB where shadermap alpha > 0
    shade_mask = shadermap_array[:, :, 3] > 0
    output_array[shade_mask, :3] *= shadermap_array[shade_mask, :3]
    
    # Convert back to uint8 and save
    output_array = np.clip(output_array * 255.0, 0, 255).astype(np.uint8)
    output_img = Image.fromarray(output_array, mode='RGBA')
    output_img.save(output_path)

def process_folder(input_folder, output_folder, texture_path):
    """Process all images in the input folder and create a montage."""
    # Create output folder if it doesn't exist
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
    
    # Load texture
    texture = load_texture(texture_path)
    
    # Process each image in the input folder
    for filename in os.listdir(input_folder):
        if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            input_path = os.path.join(input_folder, filename)
            output_path = os.path.join(output_folder, f"processed_{filename}")
            process_image(input_path, output_path, texture)
            print(f"Processed {filename}")
    
    # Create montage using ImageMagick
    montage_command = (
        f'magick montage {os.path.join(output_folder, "processed_*.png")} '
        f'-background "transparent" -geometry {TARGET_SIZE[0]}x{TARGET_SIZE[1]} -tile 4x6 '
        f'{os.path.join(output_folder, "terrain.png")}'
    )
    try:
        subprocess.run(montage_command, shell=True, check=True)
        print("Montage created: terrain.png")
    except subprocess.CalledProcessError as e:
        print(f"Error creating montage: {e}")

if __name__ == "__main__":
    process_folder(INPUT_FOLDER, OUTPUT_FOLDER, TEXTURE_PATH)