extends Node
class_name InputController

# Signals for the game to listen to
signal position_updated(position: Vector2)
signal input_mode_changed(mode: String)
signal hand_tracking_status_changed(is_active: bool)

# Input modes
enum InputMode {
	HAND_TRACKING,
	MOUSE_FALLBACK,
	TOUCH_FALLBACK
}

# Current state
var current_mode: InputMode = InputMode.MOUSE_FALLBACK
var current_position: Vector2 = Vector2.ZERO
var last_position: Vector2 = Vector2.ZERO

# Hand tracking variables
var hand_data_timeout: float = 0.0
var max_hand_timeout: float = 0.5
var hand_position_smoothing: float = 0.3
var hand_movement_history: Array[Vector2] = []
var max_history_size: int = 5
var last_valid_hand_timestamp: float = 0.0
var hand_data_freshness_threshold: float = 1.0

# Mouse/touch tracking
var mouse_in_window: bool = false
var touch_active: bool = false

# Configuration
@export var enable_hand_tracking: bool = true
@export var enable_mouse_fallback: bool = true
@export var enable_touch_fallback: bool = true
@export var debug_mode: bool = false
@export var auto_start_hand_tracking: bool = true
@export var prefer_hand_tracking: bool = true

# Hand tracking initialization
var hand_tracking_initialization_attempted: bool = false
var hand_tracking_initialization_delay: float = 2.0  # Wait longer for template to load
var initialization_timer: float = 0.0

func _ready():
	if debug_mode:
		print("InputController initialized (Custom Template Mode)")
		print("  Hand Tracking: ", enable_hand_tracking)
		print("  Mouse Fallback: ", enable_mouse_fallback)
		print("  Touch Fallback: ", enable_touch_fallback)
		print("  Auto Start: ", auto_start_hand_tracking)
	
	# Initialize at screen center
	current_position = get_viewport().size / 2
	last_position = current_position
	hand_movement_history.clear()
	
	# STARTUP TEST
	get_tree().create_timer(3.0).timeout.connect(func():
		var test_result = JavaScriptBridge.eval("testGodotConnection()")
		print("JavaScript connection test: ", test_result)
	)
	
	get_tree().create_timer(2.0).timeout.connect(func():
		print("Testing simple function...")
		var result = JavaScriptBridge.eval("testFunction()")
		print("Simple test result: ", result)

		var number = JavaScriptBridge.eval("getSimpleNumber()")
		print("Simple number: ", number)
	)
	

func _process(delta):
	# Handle hand tracking initialization
	if enable_hand_tracking and auto_start_hand_tracking and not hand_tracking_initialization_attempted:
		initialization_timer += delta
		if initialization_timer >= hand_tracking_initialization_delay:
			attempt_hand_tracking_initialization()
	
	update_hand_tracking(delta)
	update_input_mode()
	process_current_input()
	
	if debug_mode and Engine.get_process_frames() % 120 == 0:
		debug_print_status()

func _input(event):
	# Handle mouse and touch input
	if event is InputEventMouseButton:
		handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event is InputEventScreenTouch:
		handle_touch(event)
	elif event is InputEventScreenDrag:
		handle_touch_drag(event)

func attempt_hand_tracking_initialization():
	if hand_tracking_initialization_attempted:
		return
	
	if debug_mode:
		print("Checking if MediaPipe functions are available...")
	
	# Test if functions are available using the Godot-compatible calls (no window. prefix)
	var func_availability = JavaScriptBridge.eval("typeof getHandData")
	var has_functions = (func_availability == "function")
	var test_connection = JavaScriptBridge.eval("testGodotConnection()")
	
	if not has_functions:
		if debug_mode:
			print("MediaPipe functions not ready yet. Function type: ", func_availability)
			print("Test connection result: ", test_connection)
		return  # Don't mark as attempted, keep trying
	
	hand_tracking_initialization_attempted = true
	
	if debug_mode:
		print("MediaPipe functions are ready!")
		print("Test connection result: ", test_connection)
		print("Attempting to initialize hand tracking...")
	
	# Try to start hand tracking using the Godot-compatible call
	var start_result = JavaScriptBridge.eval("startHandTracking(); 'started'")
	
	if debug_mode:
		print("Hand tracking initialization result: ", start_result)

func update_hand_tracking(delta):
	if not enable_hand_tracking:
		return
	
	# Test function availability occasionally for debugging
	if debug_mode and Engine.get_process_frames() % 300 == 0:  # Every 5 seconds
		var func_test = JavaScriptBridge.eval("typeof getHandData")
		print("JavaScript function availability: ", func_test)
	
	# Get hand data using Godot-compatible call (no "window." prefix)
	var js_result = JavaScriptBridge.eval("getHandData()")
	
	# Debug what we receive occasionally
	if debug_mode and Engine.get_process_frames() % 120 == 0:
		print("=== GODOT HAND TRACKING DEBUG ===")
		print("JS result type: ", typeof(js_result))
		print("JS result: ", js_result)
		print("Is null? ", js_result == null)
		if js_result != null and typeof(js_result) == TYPE_DICTIONARY:
			print("Has x? ", js_result.has("x"))
			print("Has y? ", js_result.has("y"))
			if js_result.has("x"):
				print("Hand position: (", js_result.x, ", ", js_result.y, ")")
		print("=================================")
	
	# Check if we have valid hand data
	if js_result != null and typeof(js_result) == TYPE_DICTIONARY:
		if js_result.has("x") and js_result.has("y") and js_result.has("timestamp"):
			# VALID HAND DATA - Reset timeout and process
			hand_data_timeout = 0.0
			process_hand_data(js_result, delta)
			
			# Force switch to hand tracking if we're getting data but not in hand mode
			if current_mode != InputMode.HAND_TRACKING:
				if debug_mode:
					print("🔄 Hand data detected - forcing switch to hand tracking mode")
				switch_input_mode(InputMode.HAND_TRACKING)
			
			if debug_mode and Engine.get_process_frames() % 120 == 0:
				print("✅ Hand tracking active - Position: ", current_position)
			return
	
	# NO VALID DATA - Increment timeout
	if current_mode != InputMode.HAND_TRACKING:
		hand_data_timeout += delta
	else:
		hand_data_timeout += delta * 0.5  # Slower timeout when already in hand mode
	
	if debug_mode and Engine.get_process_frames() % 240 == 0:
		print("❌ No hand data, timeout: ", hand_data_timeout, " mode: ", get_input_mode_name(current_mode))

func process_hand_data(hand_data: Dictionary, delta: float):
	# Store timestamp of valid hand data
	last_valid_hand_timestamp = Time.get_ticks_msec() / 1000.0
	
	# Convert normalized coordinates to screen coordinates
	var new_hand_pos = Vector2(
		hand_data.x * get_viewport().size.x,
		hand_data.y * get_viewport().size.y
	)
	
	# Smooth the position to reduce jitter
	if current_mode == InputMode.HAND_TRACKING and hand_movement_history.size() > 0:
		current_position = current_position.lerp(new_hand_pos, hand_position_smoothing)
	else:
		current_position = new_hand_pos
	
	# Update movement history
	hand_movement_history.append(current_position)
	if hand_movement_history.size() > max_history_size:
		hand_movement_history.pop_front()

func is_hand_data_available() -> bool:
	# Direct check: try to get hand data right now
	var js_result = JavaScriptBridge.eval("getHandData()")
	var has_current_data = js_result != null and typeof(js_result) == TYPE_DICTIONARY and js_result.has("x")
	
	# Also check freshness of data
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_hand_data = current_time - last_valid_hand_timestamp
	var data_is_fresh = time_since_last_hand_data < hand_data_freshness_threshold
	
	# Available if we have current data OR recent fresh data
	var available = has_current_data or data_is_fresh
	
	if debug_mode and Engine.get_process_frames() % 120 == 0:
		print("Hand data availability check:")
		print("  Has current data: ", has_current_data)
		print("  Time since last data: ", time_since_last_hand_data)
		print("  Data is fresh: ", data_is_fresh)
		print("  Overall available: ", available)
	
	return available

func handle_mouse_button(event: InputEventMouseButton):
	if not enable_mouse_fallback or current_mode != InputMode.MOUSE_FALLBACK:
		return
	current_position = event.position

func handle_mouse_motion(event: InputEventMouseMotion):
	if not enable_mouse_fallback or current_mode != InputMode.MOUSE_FALLBACK:
		return
	current_position = event.position
	mouse_in_window = true

func handle_touch(event: InputEventScreenTouch):
	if not enable_touch_fallback or current_mode != InputMode.TOUCH_FALLBACK:
		return
	current_position = event.position
	touch_active = event.pressed

func handle_touch_drag(event: InputEventScreenDrag):
	if not enable_touch_fallback or current_mode != InputMode.TOUCH_FALLBACK:
		return
	current_position = event.position
	touch_active = true

func update_input_mode():
	var new_mode = determine_best_input_mode()
	if new_mode != current_mode:
		switch_input_mode(new_mode)

func determine_best_input_mode() -> InputMode:
	# Priority: Hand > Touch > Mouse with sticky behavior
	if enable_hand_tracking and prefer_hand_tracking and is_hand_data_available():
		return InputMode.HAND_TRACKING
	
	# Sticky behavior for hand tracking
	if current_mode == InputMode.HAND_TRACKING and enable_hand_tracking:
		var current_time = Time.get_ticks_msec() / 1000.0
		var time_since_last_data = current_time - last_valid_hand_timestamp
		if time_since_last_data < (hand_data_freshness_threshold * 2.0):
			return InputMode.HAND_TRACKING
	
	# Standard priority order
	if enable_hand_tracking and is_hand_data_available():
		return InputMode.HAND_TRACKING
	elif enable_touch_fallback and is_mobile_device():
		return InputMode.TOUCH_FALLBACK
	elif enable_mouse_fallback:
		return InputMode.MOUSE_FALLBACK
	else:
		return InputMode.MOUSE_FALLBACK

func is_mobile_device() -> bool:
	var user_agent = JavaScriptBridge.eval("navigator.userAgent")
	if user_agent and typeof(user_agent) == TYPE_STRING:
		return "Mobile" in user_agent or "Android" in user_agent or "iPhone" in user_agent
	return false

func switch_input_mode(new_mode: InputMode):
	var old_mode = current_mode
	current_mode = new_mode
	
	if new_mode == InputMode.HAND_TRACKING:
		hand_movement_history.clear()
	
	var mode_name = get_input_mode_name(new_mode)
	input_mode_changed.emit(mode_name)
	
	# Update JavaScript UI using Godot-compatible call
	JavaScriptBridge.eval("updateInputModeDisplay('" + mode_name + "')")
	
	if debug_mode:
		print("Input mode changed: ", get_input_mode_name(old_mode), " → ", mode_name)

func get_input_mode_name(mode: InputMode) -> String:
	match mode:
		InputMode.HAND_TRACKING: return "Hand Tracking"
		InputMode.MOUSE_FALLBACK: return "Mouse"
		InputMode.TOUCH_FALLBACK: return "Touch"
		_: return "Unknown"

func process_current_input():
	# Always emit position updates
	if current_position != last_position:
		position_updated.emit(current_position)
		last_position = current_position

# Public API
func get_current_position() -> Vector2:
	return current_position

func get_last_position() -> Vector2:
	return last_position

func get_current_input_mode() -> InputMode:
	return current_mode

func get_movement_velocity() -> Vector2:
	if hand_movement_history.size() >= 2:
		return hand_movement_history[-1] - hand_movement_history[-2]
	return Vector2.ZERO

func get_hand_tracking_status() -> Dictionary:
	var status = {
		"enabled": enable_hand_tracking,
		"available": is_hand_data_available(),
		"timeout": hand_data_timeout,
		"max_timeout": max_hand_timeout,
		"initialization_attempted": hand_tracking_initialization_attempted
	}
	
	var js_status = JavaScriptBridge.eval("getInputStatus()")
	if js_status and typeof(js_status) == TYPE_DICTIONARY:
		status.merge(js_status)
	
	return status

func set_hand_sensitivity(sensitivity: float):
	sensitivity = clamp(sensitivity, 0.0, 1.0)
	hand_position_smoothing = lerp(0.1, 0.8, sensitivity)
	
	if debug_mode:
		print("Hand sensitivity set to: ", sensitivity)
		print("  Position smoothing: ", hand_position_smoothing)

func test_javascript_connection():
	"""Test the JavaScript connection manually"""
	if debug_mode:
		print("=== MANUAL JAVASCRIPT TEST ===")
		var test_result = JavaScriptBridge.eval("testGodotConnection()")
		print("Test result: ", test_result)
		print("==============================")
	return JavaScriptBridge.eval("testGodotConnection()")

func force_hand_tracking_mode():
	"""Force switch to hand tracking mode for testing"""
	if enable_hand_tracking:
		hand_data_timeout = 0.0
		last_valid_hand_timestamp = Time.get_ticks_msec() / 1000.0
		switch_input_mode(InputMode.HAND_TRACKING)
		
		if debug_mode:
			print("Forced hand tracking mode")
		return true
	return false

func restart_hand_tracking():
	"""Restart hand tracking system"""
	if not enable_hand_tracking:
		return false
	
	JavaScriptBridge.eval("stopHandTracking()")
	
	hand_tracking_initialization_attempted = false
	initialization_timer = 0.0
	hand_data_timeout = 0.0
	last_valid_hand_timestamp = 0.0
	hand_movement_history.clear()
	
	if current_mode == InputMode.HAND_TRACKING:
		switch_input_mode(InputMode.MOUSE_FALLBACK)
	
	if debug_mode:
		print("Hand tracking restart initiated")
	
	return true

func debug_print_status():
	print("=== INPUT CONTROLLER STATUS ===")
	print("Mode: ", get_input_mode_name(current_mode))
	print("Position: ", current_position)
	print("Hand timeout: ", hand_data_timeout)
	print("Hand available: ", is_hand_data_available())
	print("Mouse in window: ", mouse_in_window)
	print("Touch active: ", touch_active)
	print("Initialization attempted: ", hand_tracking_initialization_attempted)
	
	var status = get_hand_tracking_status()
	print("Hand tracking status: ", status)
