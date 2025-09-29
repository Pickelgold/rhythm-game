extends VBoxContainer
class_name Note

var start_time: float = 0.0
var end_time: float = 0.0
var lane_number: int = 0

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
