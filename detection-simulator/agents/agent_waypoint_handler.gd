extends Node2D

var waypoints: Array[Waypoint] = []
var waypoint_scene = preload("res://agents/waypoint.tscn")

func delete_waypoint(del_point: Waypoint):
	# Update the other waypoints
	for i in len(waypoints):
		var search_point = waypoints[i]

		if search_point == del_point:
			# Get the previous and next points
			var previous_point = del_point.pt_previous
			var next_point = del_point.pt_next

			# Update the links in the points
			if previous_point and next_point:
				previous_point.pt_next = next_point
				next_point.pt_previous = previous_point
			else:
				if previous_point:
					previous_point.pt_next = null
				if next_point:
					next_point.pt_previous = null

	# Remove from array and scene tree
	waypoints.erase(del_point)
	del_point.queue_free()

func add_to_end(new_global_point: Vector2):
	# Get the end point of the array to use as a link
	var previous_point = waypoints[-1] if not waypoints.is_empty() else null

	# Instantiate and append
	waypoints.append(_instantiate_waypoint(new_global_point, previous_point, null))

func insert_after(current_point: Waypoint, new_global_point: Vector2) -> bool:
	# Insert after the waypoint specified
	for i in len(waypoints):
		var search_point = waypoints[i]

		if search_point == current_point:
			var insert_pos = i + 1

			if insert_pos == len(waypoints):
				# If we're inserting at the end, just add_to_end
				add_to_end(new_global_point)
			else:
				# Otherwise, get the next point and
				var next_point = current_point.pt_next

				waypoints.insert(insert_pos, _instantiate_waypoint(new_global_point, current_point, next_point))
			return true

	return false

func _instantiate_waypoint(new_global_point: Vector2, previous_point: Waypoint, next_point: Waypoint):
	var new_waypoint: Node2D = waypoint_scene.instantiate()
	new_waypoint.global_position = new_global_point

	add_child(new_waypoint)

	if previous_point:
		previous_point.pt_next = new_waypoint
		new_waypoint.pt_prev = previous_point

	if next_point:
		next_point.pt_previous = new_waypoint
		new_waypoint.pt_next = next_point
