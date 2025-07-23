extends Node

# Reference to the note scene
var note_scene = preload("res://Note.tscn")

# Pixels per second for note sizing (adjustable for future lane speed config)
var pixels_per_second: float = 200.0

# Timer for spawning multiple notes
var spawn_timer: Timer

func _ready():
	# Wait a frame to ensure the scene is fully loaded
	await get_tree().process_frame
	
	# Create a timer to spawn notes every 2 seconds
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 2.0
	spawn_timer.timeout.connect(spawn_demo_note)
	spawn_timer.autostart = true
	add_child(spawn_timer)
	
	# Spawn the first note immediately
	spawn_demo_note()

func spawn_demo_note():
	# Get reference to Lane 1's NoteContainer and Judgement line
	var lane1_container = get_node("../UI/MarginContainer/AspectRatioContainer/VBoxContainer/Row 4/Lane 1/Background/NoteContainer")
	var lane1_judgement = get_node("../UI/MarginContainer/AspectRatioContainer/VBoxContainer/Row 4/Lane 1/Judgement")
	
	if not lane1_container or not lane1_judgement:
		print("Error: Could not find Lane 1 NoteContainer or Judgement")
		return
	
	# Calculate judgement line thickness to match note lines
	var judgement_thickness = lane1_judgement.size.y
	
	# Create the note instance
	var note = note_scene.instantiate()
	
	# Update note line thickness to match judgement line
	note.line_thickness = judgement_thickness
	
	# Initialize the note with 0.1 second duration
	note.initialize(0.0, 0.1, 1)  # start_time, end_time, lane_number
	
	# Calculate note dimensions including white lines
	var duration = note.get_duration()
	var duration_height = duration * pixels_per_second  # 0.1 * 200 = 20 pixels
	var line_thickness = note.get_total_line_thickness()  # judgement_thickness * 2
	var total_note_height = duration_height + line_thickness
	
	# Get the container size to position and size the note properly
	var container_size = lane1_container.size
	var note_width = container_size.x  # Full width of the lane
	
	# Set note size (includes the white lines)
	note.size = Vector2(note_width, total_note_height)
	
	# Update the line heights in the note to match judgement thickness
	var top_line = note.get_node("TopLine")
	var bottom_line = note.get_node("BottomLine")
	if top_line:
		top_line.offset_bottom = judgement_thickness
	if bottom_line:
		bottom_line.offset_top = -judgement_thickness
	
	# Position the note above the container (start falling from top)
	var start_y_position = -total_note_height  # Start above the container
	note.position = Vector2(0, start_y_position)
	
	# Add the note to the container
	lane1_container.add_child(note)
	
	# Start the note falling
	note.start_falling(pixels_per_second)  # Use same speed as sizing for consistency
