extends Camera2D

var pan_speed = 750.0 # Pixels per second
var zoom_speed = 0.2 # Zoom increment per input
var min_zoom = Vector2(0.1, 0.1) # Minimum zoom (zoomed out)
var max_zoom = Vector2(5, 5) # Maximum zoom (zoomed in)
var move_direction = Vector2.ZERO
var zoom_level = Vector2(1.0, 1.0) # Current zoom

func _ready():
	zoom = zoom_level # Set initial zoom

func _process(delta):
	# Panning
	move_direction = Vector2.ZERO
	if Input.is_action_pressed("ui_up"):
		move_direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		move_direction.y += 1
	if Input.is_action_pressed("ui_left"):
		move_direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		move_direction.x += 1

	var current_pan_speed = pan_speed
	if Input.is_key_pressed(KEY_SHIFT): # Detect if Shift is pressed
		current_pan_speed *= 2 # Adjust this multiplier as needed

	if move_direction != Vector2.ZERO:
		move_direction = move_direction.normalized()
		position += move_direction * current_pan_speed * delta

	# Zooming
	if Input.is_action_just_pressed("zoom in - scroll up"):
		zoom_level += Vector2(zoom_speed, zoom_speed)/1.5
	if Input.is_action_just_pressed("zoom out - scroll down"):
		zoom_level -= Vector2(zoom_speed, zoom_speed)/1.5

	# Clamp zoom level
	zoom_level = clamp(zoom_level, min_zoom, max_zoom)
	zoom = zoom_level
