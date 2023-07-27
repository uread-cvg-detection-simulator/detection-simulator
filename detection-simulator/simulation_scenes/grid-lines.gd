extends Node2D

@export var on = true
@export var grid_colour: Color = Color.DARK_GRAY

var grid_size: float = 64.0 : set = _grid_size_set
var camera: Camera2D = null : set = _camera_set

var camera_position = null
var camera_zoom = null

func _draw():
	if on:
		var size = camera.get_viewport_rect().size * camera.zoom / 2

		var camera_position = camera.position

		for i in range(int((camera_position.x - size.x) / grid_size) - 1, int((size.x + camera_position.x) / grid_size) + 1):
			draw_line(Vector2(i * grid_size, camera_position.y + size.y + 100), Vector2(i * grid_size, camera_position.y - size.y - 100), grid_colour, 3.0 if (i % 10 == 0) else 1.0)

		for i in range(int((camera_position.y - size.y) / grid_size) - 1, int((size.y + camera_position.y) / grid_size) + 1):
			draw_line(Vector2(camera_position.x + size.x + 100, i * grid_size), Vector2(camera_position.x - size.x - 100, i * grid_size), grid_colour, 3.0 if (i % 10 == 0) else 1.0)

func _ready():
	pass

func _process(delta):
	pass

func _on_camera_change(_old, _new):
	self.queue_redraw()

func _camera_set(new_camera: Camera2D):
	# Disconnect from the old camera
	if camera != null:
		camera.disconnect("camera_moved", self._on_camera_change)
		camera.disconnect("camera_zoomed", self._on_camera_change)
	
	# Connect to the new camera
	camera = new_camera
	
	camera.connect("camera_moved", self._on_camera_change)
	camera.connect("camera_zoomed", self._on_camera_change)

func _grid_size_set(value):
	grid_size = value
	self.queue_redraw()
