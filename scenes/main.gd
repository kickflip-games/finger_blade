extends Control
class_name FruitNinjaGame

@onready var input_controller = $InputController
@onready var game_area = $GameArea
@onready var slice_trail = $SliceTrail
@onready var score_label = $UI/ScoreLabel
@onready var input_mode_label = $UI/InputModeLabel

const FRUIT_SCENE = preload("res://scenes/fruit/fruit.tscn")

var score = 0
var fruits = []
var trail_points = []
var max_trail_points = 20

# Fruit spawning
var fruit_spawn_timer = 0.0
var spawn_interval = 2.0

# Trail settings
var trail_fade_time = 0.5
var min_movement_for_trail = 5.0  # Minimum movement to add trail point

func _ready():
	setup_game()
	connect_input_signals()

func setup_game():
	score_label.text = "Score: 0"
	input_mode_label.text = "Input: Detecting..."
	
	# Set up slice trail
	slice_trail.width = 5.0
	slice_trail.default_color = Color.CYAN
	
func connect_input_signals():
	# Connect to InputController signals
	input_controller.position_updated.connect(_on_position_updated)
	input_controller.input_mode_changed.connect(_on_input_mode_changed)

func _process(delta):
	update_fruit_spawning(delta)
	update_fruits(delta)
	check_collisions()
	update_trail(delta)

func _on_position_updated(position: Vector2):
	# Always update trail position
	add_trail_point(position)

func _on_input_mode_changed(mode_name: String):
	input_mode_label.text = "Input: " + mode_name
	
	# Optional: Show different UI hints based on input mode
	match mode_name:
		"Hand Tracking":
			show_hand_instructions()
		"Mouse":
			show_mouse_instructions()
		"Touch":
			show_touch_instructions()

func add_trail_point(position: Vector2):
	# Only add point if we've moved enough (reduces jitter)
	if trail_points.size() > 0:
		var last_point = trail_points[-1]
		if position.distance_to(last_point) < min_movement_for_trail:
			return
	
	# Add new point
	trail_points.append(position)
	slice_trail.add_point(position)
	
	# Keep trail length manageable
	if trail_points.size() > max_trail_points:
		trail_points.pop_front()
		slice_trail.remove_point(0)

func update_trail(delta):
	# Gradually fade the trail
	if trail_points.size() > 0:
		var fade_alpha = max(0.0, slice_trail.modulate.a - (delta / trail_fade_time))
		slice_trail.modulate.a = fade_alpha
		
		# If trail is very faded, clear it
		if fade_alpha < 0.1:
			clear_trail()

func clear_trail():
	trail_points.clear()
	slice_trail.clear_points()
	slice_trail.modulate.a = 1.0

func update_fruit_spawning(delta):
	fruit_spawn_timer += delta
	if fruit_spawn_timer >= spawn_interval:
		spawn_fruit()
		fruit_spawn_timer = 0.0
		spawn_interval = max(0.8, spawn_interval - 0.02)

func spawn_fruit():
	var fruit = FRUIT_SCENE.instantiate()
	
	fruit.position = Vector2(
		randf() * (get_viewport().size.x - 100) + 50,
		-50
	)
	
	fruit.velocity = Vector2(
		(randf() - 0.5) * 200,
		randf() * 100 + 200
	)
	
	fruits.append(fruit)
	game_area.add_child(fruit)

func update_fruits(delta):
	for i in range(fruits.size() - 1, -1, -1):
		var fruit = fruits[i]
		if fruit.update_physics(delta):
			fruits.remove_at(i)
			fruit.queue_free()

func check_collisions():
	if trail_points.size() < 2:
		return
	
	var current_position = input_controller.get_current_position()
	
	# Check collision with current position (simpler approach)
	for i in range(fruits.size() - 1, -1, -1):
		var fruit = fruits[i]
		
		# Simple distance-based collision
		var distance_to_fruit = current_position.distance_to(fruit.global_position)
		if distance_to_fruit < 50.0:  # Collision radius
			slice_fruit(fruit, i)

func slice_fruit(fruit: Fruit, index: int):
	score += 10
	score_label.text = "Score: " + str(score)
	fruit.slice()
	fruits.remove_at(index)
	
	# Add visual feedback
	create_slice_effect(fruit.global_position)
	
	var tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(fruit.queue_free)

func create_slice_effect(position: Vector2):
	# Create a bright flash at the slice position
	slice_trail.modulate = Color.WHITE
	var tween = create_tween()
	tween.tween_property(slice_trail, "modulate", Color.CYAN, 0.2)

func show_hand_instructions():
	# Optional: Show hand tracking specific UI hints
	print("Hand tracking active - move your finger to slice!")

func show_mouse_instructions():
	# Optional: Show mouse specific UI hints  
	print("Mouse mode - move cursor to slice!")

func show_touch_instructions():
	# Optional: Show touch specific UI hints
	print("Touch mode - touch and drag to slice!")

# Debug and utility functions
func get_input_status() -> Dictionary:
	return input_controller.get_hand_tracking_status()

func restart_hand_tracking():
	input_controller.restart_hand_tracking()

func set_hand_sensitivity(sensitivity: float):
	input_controller.set_hand_sensitivity(sensitivity)
