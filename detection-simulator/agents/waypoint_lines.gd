extends Node2D

var waypoint_object = null
var camera: Camera2D = null : set = _camera_set
@export var draw_lines: bool = true

func _draw():
	if waypoint_object != null and draw_lines:
		# Get the waypoints from the waypoint object
		var waypoints: Array[Waypoint] = waypoint_object.waypoints

		if not waypoints.is_empty():
			# Draw the waypoint lines
			var line_width = waypoint_object.link_line_size
			var line_color = waypoint_object.link_line_colour
			var link_line_colour = Color.YELLOW
			var enter_line_colour = Color.BLUE

			var current_waypoint = waypoints[0]

			while current_waypoint != null:
				var previous_waypoint = current_waypoint.pt_previous

				if previous_waypoint != null:
					if current_waypoint.waypoint_type != Waypoint.WaypointType.WAYPOINT or previous_waypoint.waypoint_type != Waypoint.WaypointType.WAYPOINT:
						draw_line(current_waypoint.position, previous_waypoint.position, enter_line_colour, line_width)
					else:
						draw_line(current_waypoint.position, previous_waypoint.position, line_color, line_width)

				# If linked, draw the link line
				if not current_waypoint.linked_nodes.is_empty():
					for linked_node in current_waypoint.linked_nodes:
						draw_line(current_waypoint.position, linked_node.position, link_line_colour, line_width)

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
