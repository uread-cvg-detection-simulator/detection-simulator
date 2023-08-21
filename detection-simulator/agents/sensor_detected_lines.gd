extends Node2D

@export var sensor: Sensor = null

func _process(delta):
	if sensor:
		queue_redraw()

func _draw():
	if sensor:
		var detected_objects = sensor.current_detections

		for agent in detected_objects:
			draw_line(position, agent.position, sensor.detection_line_colour, sensor.detection_line_width)
