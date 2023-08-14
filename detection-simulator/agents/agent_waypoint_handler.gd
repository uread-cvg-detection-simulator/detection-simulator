extends Node

@export var parent_object: Agent = null
@onready var starting_node: Waypoint = $fake_start
@onready var waypoint_lines: Node2D = $zzz_waypoint_lines

var waypoints: Array[Waypoint] = []
var waypoint_scene = preload("res://agents/waypoint.tscn")

@export var link_line_size = 5.0
@export var link_line_colour = Color(0.0, 0.0, 0.0, 1.0)

@export var camera: Camera2D = null : set = _set_camera

var initialised = false

func _ready():
	initialised = true

	_set_camera(camera)

	# Set the starting node
	starting_node.global_position = parent_object.global_position

	# Set the waypoint_lines parent variable
	waypoint_lines.waypoint_object = self


func is_empty():
	return waypoints.is_empty()

func delete_waypoint(del_point: Waypoint):

	var current_point_index = get_waypoint_index(del_point)
	var previous_point_index = current_point_index - 1 if current_point_index > 0 else -1
	var next_point_index = current_point_index + 1 if current_point_index < len(waypoints) - 1 else null

	if previous_point_index == null and next_point_index == null:
		print_debug("Error: Could not find previous or next point")
		return

	# Create undo action
	var undo_action = UndoRedoAction.new()
	undo_action.action_name = "Delete Waypoint %d" % current_point_index

	########
	# DO
	########

	# Get the agent
	var undo_agent_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [parent_object.agent_id])
	undo_action.manual_add_item_to_store(parent_object, undo_agent_ref)

	# Get the waypoints
	var current_point_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(x, curr_point_index):
		return x.waypoints.waypoints[curr_point_index]
		, [undo_agent_ref, current_point_index], undo_agent_ref
	)

	var previous_point_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(x, prev_point_index):
		return x.waypoints.waypoints[prev_point_index] if prev_point_index != null and prev_point_index != -1 else x.waypoints.starting_node
		, [undo_agent_ref, previous_point_index], undo_agent_ref
	)

	var next_point_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(x, nxt_point_index):
		return x.waypoints.waypoints[nxt_point_index] if nxt_point_index != null else null
		, [undo_agent_ref, next_point_index], undo_agent_ref
	)

	# Update the links in the points
	undo_action.action_method(UndoRedoAction.DoType.Do, func(previous_point, next_point):
		if previous_point and next_point:
			previous_point.pt_next = next_point
			next_point.pt_previous = previous_point
		else:
			if previous_point:
				previous_point.pt_next = null
			if next_point:
				next_point.pt_previous = null
		, [previous_point_ref, next_point_ref], [previous_point_ref, next_point_ref]
	)

	# Remove from array and scene tree
	undo_action.action_method(UndoRedoAction.DoType.Do, func(agent, current_point):
		agent.waypoints.waypoints.erase(current_point)
		, [undo_agent_ref, current_point_ref], [undo_agent_ref, current_point_ref]
	)

	# Disable point's visibility
	undo_action.action_method(UndoRedoAction.DoType.Do, func(current_point):
		current_point.disabled = true
		, [current_point_ref], current_point_ref
	)


	# Queue redraw
	undo_action.action_method(UndoRedoAction.DoType.Do, func(agent):
		agent.waypoints.waypoint_lines.queue_redraw()
		, [undo_agent_ref], [undo_agent_ref]
	)

	########
	# UNDO
	########

	# Re-insert the point into the array
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(agent, current_point, current_point_index):
		agent.waypoints.waypoints.insert(current_point_index, current_point)
		, [undo_agent_ref, current_point_ref, current_point_index], [undo_agent_ref, current_point_ref]
	)

	# Re-link the points
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(previous_point, next_point, current_point):
		if previous_point and next_point:
			previous_point.pt_next = current_point
			next_point.pt_previous = current_point
		else:
			if previous_point:
				previous_point.pt_next = current_point
			if next_point:
				next_point.pt_previous = current_point
		, [previous_point_ref, next_point_ref, current_point_ref], [previous_point_ref, next_point_ref, current_point_ref]
	)

	# Enable point's visibility
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(current_point):
		current_point.disabled = false
		, [current_point_ref], current_point_ref
	)

	# Queue redraw
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(agent):
		agent.waypoints.waypoint_lines.queue_redraw()
		, [undo_agent_ref], [undo_agent_ref]
	)

	######
	# FINALISE
	######

	# Free the point when the action is deleted
	undo_action.action_method(UndoRedoAction.DoType.OnRemoval, func(current_point):
		if current_point:
			current_point.queue_free()
		, [current_point_ref], current_point_ref
	)

	UndoSystem.add_action(undo_action)

func get_waypoint_index(waypoint: Waypoint):
	for i in len(waypoints):
		if waypoints[i] == waypoint:
			return i

	return -1

func add_to_end(new_global_point: Vector2) -> Waypoint:
	# Get the end point of the array to use as a link
	var previous_point = waypoints[-1] if not waypoints.is_empty() else starting_node

	# Instantiate and append
	var new_waypoint = _instantiate_waypoint(new_global_point, previous_point, null)
	waypoints.append(new_waypoint)

	# Queue line redraw
	waypoint_lines.queue_redraw()

	########
	# DO
	########

	# Create undo action
	var undo_action = UndoRedoAction.new()
	undo_action.action_name = "Add Waypoint"

	# Get the agent
	var undo_agent_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [parent_object.agent_id])
	undo_action.manual_add_item_to_store(parent_object, undo_agent_ref)

	# Get the previous point
	var undo_previous_point = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(x):
		return x.waypoints.waypoints[-1] if not x.waypoints.waypoints.is_empty() else x.waypoints.starting_node
		, [undo_agent_ref], undo_agent_ref
	)

	# Instantiate the new waypoint
	var undo_new_waypoint = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(x, new_global_point, previous_point):
		return x.waypoints._instantiate_waypoint(new_global_point, previous_point, null)
		, [undo_agent_ref, new_global_point, undo_previous_point], [undo_agent_ref, undo_previous_point]
	)

	undo_action.manual_add_item_to_store(new_waypoint, undo_new_waypoint)
	undo_action.manual_add_item_to_store(previous_point, undo_previous_point)

	# Add to waypoints
	undo_action.action_method(UndoRedoAction.DoType.Do, func(new_wp, agent):
		agent.waypoints.waypoints.append(new_wp)
		, [undo_new_waypoint, undo_agent_ref], [undo_new_waypoint, undo_agent_ref]
	)

	# Queue line redraw
	undo_action.action_method(UndoRedoAction.DoType.Do, func(agent):
		agent.waypoints.waypoint_lines.queue_redraw()
		, [undo_agent_ref], [undo_agent_ref]
	)

	########
	# UNDO
	########

	# Remove from waypoints
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(agent):
		agent.waypoints.waypoints.resize(len(agent.waypoints.waypoints) - 1)
		, [undo_agent_ref], [undo_agent_ref]
	)

	# Reset the previous point
	undo_action.action_property_ref(UndoRedoAction.DoType.Undo, undo_previous_point, "pt_next", null)


	# Delete the waypoint
	undo_action.action_object_call_ref(UndoRedoAction.DoType.Undo, undo_new_waypoint, "queue_free")
	undo_action.action_remove_item(UndoRedoAction.DoType.Undo, undo_new_waypoint)

	# Queue line redraw
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(agent):
		agent.waypoints.waypoint_lines.queue_redraw()
		, [undo_agent_ref], [undo_agent_ref]
	)

	UndoSystem.add_action(undo_action, false)

	return new_waypoint


func _get_insert_pos(current_point: Waypoint) -> Array:
	var insert_pos = -1
	var next_point: Waypoint = null

	if current_point == starting_node:
		next_point = null if waypoints.is_empty() else waypoints[0]
		insert_pos = 0
	else:
		# Insert after the waypoint specified
		for i in len(waypoints):
			var search_point = waypoints[i]

			if search_point == current_point:
				insert_pos = i + 1
				next_point = current_point.pt_next if insert_pos != len(waypoints) else null
				break

	return [insert_pos, next_point]

func insert_after(current_point: Waypoint, new_global_point: Vector2) -> Waypoint:

	var rv = _get_insert_pos(current_point)

	var insert_pos = rv[0]
	var next_point: Waypoint = rv[1]

	if insert_pos == -1:
		return null

	if next_point == null:
		return add_to_end(new_global_point)

	var new_waypoint = _instantiate_waypoint(new_global_point, current_point, next_point)
	new_waypoint.camera = camera

	waypoints.insert(insert_pos, new_waypoint)

	# Queue line redraw
	waypoint_lines.queue_redraw()

	########
	# DO
	########

	# Create undo action
	var undo_action = UndoRedoAction.new()
	undo_action.action_name = "Insert Waypoint"

	# Get the agent
	var undo_agent_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [parent_object.agent_id])
	undo_action.manual_add_item_to_store(parent_object, undo_agent_ref)

	# Get the next and current points
	var undo_next_point = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(x):
		return x.waypoints.waypoints[insert_pos] if insert_pos != len(x.waypoints.waypoints) else null
		, [undo_agent_ref], undo_agent_ref
	)
	var undo_current_point = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(x):
		return x.waypoints.waypoints[insert_pos-1] if insert_pos > 0 else starting_node
		, [undo_agent_ref], undo_agent_ref
	)

	# Instantiate the new waypoint
	var undo_new_waypoint = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(x, current_point, next_point):
		return x.waypoints._instantiate_waypoint(new_global_point, current_point, next_point)
		, [undo_agent_ref, undo_current_point, undo_next_point], [undo_agent_ref, undo_current_point, undo_next_point]
	)

	undo_action.manual_add_item_to_store(new_waypoint, undo_new_waypoint)
	undo_action.manual_add_item_to_store(next_point, undo_next_point)
	undo_action.manual_add_item_to_store(current_point, undo_current_point)

	# Add to waypoints
	undo_action.action_method(UndoRedoAction.DoType.Do, func(pos, new_wp, agent):
		agent.waypoints.waypoints.insert(pos, new_wp)
		, [insert_pos, undo_new_waypoint, undo_agent_ref], [undo_agent_ref, undo_new_waypoint]
	)

	# Queue line redraw
	undo_action.action_method(UndoRedoAction.DoType.Do, func(agent):
		agent.waypoints.waypoint_lines.queue_redraw()
		, [undo_agent_ref], [undo_agent_ref]
	)

	########
	# UNDO
	########

	# Remove from waypoints
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(pos, agent):
		agent.waypoints.waypoints.remove_at(pos)
		, [insert_pos, undo_agent_ref], undo_agent_ref
	)

	# Remove from previous point
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(current_point, next_point):
		current_point.pt_next = next_point
		next_point.pt_previous = current_point
		, [undo_current_point, undo_next_point], [undo_current_point, undo_next_point]
	)

	# Delete the waypoint
	undo_action.action_object_call_ref(UndoRedoAction.DoType.Undo, undo_new_waypoint, "queue_free")

	# Queue line redraw
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(agent):
		agent.waypoints.waypoint_lines.queue_redraw()
		, [undo_agent_ref], [undo_agent_ref]
	)

	UndoSystem.add_action(undo_action, false)

	return new_waypoint

func _instantiate_waypoint(new_global_point: Vector2, previous_point: Waypoint, next_point: Waypoint):
	print_debug("Instantiating waypoint at %s [%s -> %s]" % [new_global_point, previous_point, next_point])
	var new_waypoint: Node2D = waypoint_scene.instantiate()
	new_waypoint.global_position = new_global_point
	new_waypoint.camera = camera

	if parent_object:
		new_waypoint.parent_object = parent_object

	add_child(new_waypoint)

	if previous_point:
		previous_point.pt_next = new_waypoint
		new_waypoint.pt_previous = previous_point

	if next_point:
		next_point.pt_previous = new_waypoint
		new_waypoint.pt_next = next_point

	return new_waypoint

func _set_camera(new_camera):
	camera = new_camera

	# Cycle through all waypoints and set the camera
	for waypoint in waypoints:
		waypoint.camera = new_camera
