extends Camera2D

signal camera_moved(old, new)
signal camera_zoomed(old, new)

@onready var _old_position = self.position
@onready var _old_zoom = self.zoom

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if _old_position != self.position:
		emit_signal("camera_moved", _old_position, self.position)
		_old_position = self.position

	if _old_zoom != self.zoom:
		emit_signal("camera_zoomed", _old_zoom, self.zoom)
		_old_zoom = self.zoom
