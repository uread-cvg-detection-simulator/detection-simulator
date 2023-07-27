extends Node2D

@export var on = true
@export var camera: Camera2D
@export var grid_colour: Color = Color.DARK_GRAY
@export var grid_size: float = 64.0

var camera_position = null
var camera_zoom = null

func _draw():
	if on:
		var size = get_viewport_rect().size * camera.zoom / 2

		var camera_position = camera.position

		for i in range(int((camera_position.x - size.x) / grid_size) - 1, int((size.x + camera_position.x) / grid_size) + 1):
			draw_line(Vector2(i * grid_size, camera_position.y + size.y + 100), Vector2(i * grid_size, camera_position.y - size.y - 100), grid_colour)

		for i in range(int((camera_position.y - size.y) / grid_size) - 1, int((size.y + camera_position.y) / grid_size) + 1):
			draw_line(Vector2(camera_position.x + size.x + 100, i * grid_size), Vector2(camera_position.x - size.x - 100, i * grid_size), grid_colour)

func _ready():
	camera.connect("camera_moved", self._on_camera_change)
	camera.connect("camera_zoomed", self._on_camera_change)

func _process(delta):
	pass

func _on_camera_change(_old, _new):
	self.queue_redraw()
