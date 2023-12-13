class_name ImageLoaderCamera
extends Camera2D

var can_scroll: bool = true
var _scrolling: bool = false

func _unhandled_input(event):
	if can_scroll and get_tree().get_nodes_in_group("mouse_hovered").is_empty():
		# Start up the scrolling
		if event.is_action_pressed("mouse_selected"):
			if not _scrolling:
				_scrolling = true

		# Stop scrolling if mouse is released
		if _scrolling and event.is_action_released("mouse_selected"):
			_scrolling = false

		# Move the position of the mouse relative to the mouse
		if event is InputEventMouseMotion and _scrolling:
			var tmp_event: InputEventMouseMotion = event

			position -= tmp_event.relative / zoom.x

		if event.is_action_pressed("zoom_in"):
			zoom.x += 0.1
			zoom.y += 0.1


		if event.is_action_pressed("zoom_out"):
			zoom.x -= 0.1
			zoom.y -= 0.1
