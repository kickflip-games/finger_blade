extends RigidBody2D

class_name Fruit

var velocity = Vector2.ZERO
var is_sliced = false

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

# Fruit types with colors
var fruit_colors = [
	Color.RED,      # Apple
	Color.ORANGE,   # Orange  
	Color.YELLOW,   # Banana
	Color.GREEN,    # Lime
	Color.PURPLE    # Grape
]

func _ready():
	# Set random fruit color
	sprite.modulate = fruit_colors[randi() % fruit_colors.size()]
	linear_velocity = velocity

func update_physics(delta) -> bool:
	# Check if fruit fell off screen
	if position.y > get_viewport().size.y + 100:
		return true
	return false

func check_slice_collision(line_start: Vector2, line_end: Vector2) -> bool:
	if is_sliced:
		return false
		
	# Simple circle-line collision
	var fruit_center = global_position
	var fruit_radius = 40  # Adjust based on your fruit size
	
	# Distance from point to line
	var line_vec = line_end - line_start
	var line_length = line_vec.length()
	
	if line_length == 0:
		return false
		
	var line_normalized = line_vec / line_length
	var to_fruit = fruit_center - line_start
	var projection = to_fruit.dot(line_normalized)
	
	# Clamp projection to line segment
	projection = clamp(projection, 0, line_length)
	var closest_point = line_start + line_normalized * projection
	
	var distance = fruit_center.distance_to(closest_point)
	
	return distance <= fruit_radius

func slice():
	if is_sliced:
		return
		
	is_sliced = true
	
	# Visual slice effect
	var tween = create_tween()
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.3)
	
	# Disable collision
	collision_shape.set_deferred("disabled", true)
	
	# Add particle effect or slice animation here
