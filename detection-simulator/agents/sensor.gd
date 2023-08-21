extends Node2D
class_name Sensor

@export_group("Parameters")
@export var sensor_fov_degrees: float = 90.0 : set = _set_sensor_fov
@export var detection_line_width: float = 3.0
@export var detection_line_colour: Color = Color.RED
@export var draw_sensor_detections: bool = true
@export var draw_vision_cone: bool = true: set = _set_draw_cone

@export_group("Internal")
@export var vision_cone: VisionCone2D = null

var sensor_id: int = -1
var current_detections: Array[Agent] = []

# Called when the node enters the scene tree for the first time.
func _ready():
	sensor_fov_degrees = sensor_fov_degrees
	draw_vision_cone = draw_vision_cone

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _set_sensor_fov(new_value: float):
	sensor_fov_degrees = new_value

	if vision_cone:
		vision_cone.angle_deg = new_value
		vision_cone.recalculate_vision(true)
		#vision_cone.ray_count = int(new_value / 3)

func _set_draw_cone(new_value: bool):
	draw_vision_cone = new_value

	if vision_cone:
		vision_cone.debug_shape = true

func _on_vision_cone_area_body_entered(body):
	if body is Agent:
		current_detections.append(body)

func _on_vision_cone_area_body_exited(body):
	if body is Agent:
		current_detections.erase(body)
