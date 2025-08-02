extends VBoxContainer
class_name Note

var start_time: float = 0.0
var end_time: float = 0.0
var lane_number: int = 0

# Movement properties
var lane_percentage_per_second: float = 1.0  # percentage of lane per second
var lane_height: float = 0.0  # height of the lane container
var is_falling: bool = false

# Visual properties
var line_thickness: float = 2.0  # thickness of top and bottom white lines

func initialize(start: float, end: float, lane: int):
	start_time = start
	end_time = end
	lane_number = lane

func get_duration() -> float:
	return end_time - start_time

func get_total_line_thickness() -> float:
	# Returns the total thickness of both lines (top + bottom)
	return line_thickness * 2.0

func start_falling(percentage_speed: float = 0.5, container_height: float = 400.0):
	lane_percentage_per_second = percentage_speed
	lane_height = container_height
	is_falling = true

func stop_falling():
	is_falling = false

func _process(delta):
	# Note positioning is now handled by MIDISpawner using absolute time
	# This function is kept for compatibility but movement logic is disabled
	pass
