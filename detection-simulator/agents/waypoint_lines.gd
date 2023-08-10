extends Node2D

var waypoint_object = null
var camera: Camera2D = null : set = _camera_set

func _draw():
	if waypoint_object != null:
		# Get the waypoints from the waypoint object
		var waypoints: Array[Waypoint] = waypoint_object.waypoints

		if not waypoints.is_empty():
			# Draw the waypoint lines
			var line_width = waypoint_object.link_line_size
			var line_color = waypoint_object.link_line_colour

			var current_waypoint = waypoints[0]

			while current_waypoint != null:
				var previous_waypoint = current_waypoint.pt_previous

				if previous_waypoint != null:
					draw_line(current_waypoint.position, previous_waypoint.position, line_color, line_width)

				current_waypoint = current_waypoint.pt_next


func _on_camera_change(_old, _new):
	self.queue_redraw()

func _camera_set(new_camera: Camera2D):
	if camera != null:
		camera.disconnect("camera_moved", self._on_camera_change)
		camera.disconnect("camera_zoomed", self._on_camera_change)

	camera = new_camera

	camera.connect("camera_moved", self._on_camera_change)
	camera.connect("camera_zoomed", self._on_camera_change)
