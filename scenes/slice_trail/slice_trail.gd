extends Line2D
class_name SliceTrail

enum TrailStyle {
	DEFAULT,
	NEON_GLOW,
	FIRE_SLASH,
	ICE_SPARKLE
}

@export var trail_style: TrailStyle = TrailStyle.DEFAULT
@export var debug_mode: bool = false
@export var max_points: int = 15
@export var fade_duration: float = 0.3

func _ready():
	set_as_top_level(true)
	visible = true
	z_index = 100
	modulate.a = 1.0
	clear_points()

	apply_trail_style()

func _process(_delta):
	if debug_mode:
		var mouse = get_viewport().get_mouse_position()
		add_slice_point(mouse)

func add_slice_point(point: Vector2):
	add_point(point)
	if get_point_count() > max_points:
		remove_point(0)

func fade_and_clear():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(func():
		clear_points()
		modulate.a = 1.0
	)

# ============================================================================
# Style Presets
# ============================================================================

func apply_trail_style():
	match trail_style:
		TrailStyle.DEFAULT:
			width = 5
			default_color = Color.CYAN
			texture = null
			gradient = null

		TrailStyle.NEON_GLOW:
			width = 20
			default_color = Color(0, 1, 1, 0.9)
			texture = make_soft_glow_texture()
			texture_mode = Line2D.LINE_TEXTURE_STRETCH
			gradient = make_gradient([
				[0.0, Color(0, 0.8, 1, 0)],
				[0.2, Color(0, 1, 1, 0.8)],
				[1.0, Color(1, 1, 1, 0)],
			])
			

		TrailStyle.FIRE_SLASH:
			width = 16
			default_color = Color(1, 0.3, 0, 1)
			texture = make_soft_glow_texture()
			texture_mode = Line2D.LINE_TEXTURE_STRETCH
			gradient = make_gradient([
				[0.0, Color(1, 1, 0.5, 0)],
				[0.3, Color(1, 0.4, 0.1, 0.9)],
				[1.0, Color(0.3, 0, 0, 0)],
			])
			

		TrailStyle.ICE_SPARKLE:
			width = 12
			default_color = Color(0.6, 0.9, 1.0, 0.8)
			texture = make_soft_glow_texture()
			texture_mode = Line2D.LINE_TEXTURE_STRETCH
			gradient = make_gradient([
				[0.0, Color(1, 1, 1, 0)],
				[0.2, Color(0.8, 1, 1, 0.9)],
				[1.0, Color(0.5, 0.9, 1.0, 0)],
			])
			

# ============================================================================
# Helpers
# ============================================================================

func make_gradient(points: Array) -> Gradient:
	var g := Gradient.new()
	for p in points:
		g.add_point(p[0], p[1])
	return g

func make_soft_glow_texture() -> GradientTexture1D:
	var tex := GradientTexture1D.new()
	var grad := Gradient.new()
	grad.add_point(0.0, Color(1, 1, 1, 0.0))
	grad.add_point(0.2, Color(1, 1, 1, 1.0))
	grad.add_point(0.8, Color(1, 1, 1, 1.0))
	grad.add_point(1.0, Color(1, 1, 1, 0.0))
	tex.gradient = grad
	return tex
