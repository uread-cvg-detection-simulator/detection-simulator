extends Node2D

var grid_size: float = 64.0 : set = _grid_size_set
var camera: Camera2D = null : set = _camera_set

var _labels: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	if camera != null:
		draw_labels()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_camera_change(_old, _new):
	draw_labels()

func draw_labels():
	# Determine which labels are on screen
	var positions_required: Array[Vector2i] = []

	var size = camera.get_viewport_rect().size * camera.zoom / 2

	for x in range(int((camera.position.x - size.x) / grid_size) - 1, int((size.x + camera.position.x) / grid_size) + 1):
		for y in range(int((camera.position.y - size.y) / grid_size) - 1, int((size.y + camera.position.y) / grid_size) + 1):
			if y % 10 == 0 and x % 10 == 0:
				positions_required.append(Vector2i(x, y))

	# Remove any labels no longer needed
	for position in _labels:
		var value: Label = _labels[position]

		if not positions_required.has(position):
			_labels.erase(position)
			value.queue_free()

	# Create new labels
	for position in positions_required:
		if not _labels.has(position):
			var new_label = $template_label.duplicate()
			add_child(new_label)

			new_label.text = "(%d,%d)" % [position.x, -position.y]

			var pos_x = float(position.x * 64) - (float(new_label.size.x) / 2.0)

			new_label.set_global_position(Vector2(pos_x, position.y * 64))
			new_label.visible = true

			_labels[position] = new_label

func _camera_set(new_camera: Camera2D):
	# Disconnect from the old camera
	if camera != null:
		camera.disconnect("camera_moved", self._on_camera_change)
		camera.disconnect("camera_zoomed", self._on_camera_change)

	# Connect to the new camera
	camera = new_camera

	camera.connect("camera_moved", self._on_camera_change)
	camera.connect("camera_zoomed", self._on_camera_change)

	draw_labels()

func _grid_size_set(value):
	grid_size = value
	draw_labels()
