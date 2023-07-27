class_name Grid
extends Node2D

@export var camera: Camera2D = null : set = _camera_set
@export var grid_size: float = 64.0 : set = _grid_size_set

@onready var grid_lines = $grid_lines
@onready var grid_labels = $grid_labels

var initialised = false

# Called when the node enters the scene tree for the first time.
func _ready():
	initialised = true

	if camera != null:
		_camera_set(camera)

	_grid_size_set(grid_size)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _camera_set(new_camera: Camera2D):
	if initialised:
		grid_lines.camera = camera
		grid_labels.camera = camera

	camera = new_camera

func _grid_size_set(value):
	grid_size = value
	
	if initialised:
		grid_lines.grid_size = value
		grid_labels.grid_size = value
