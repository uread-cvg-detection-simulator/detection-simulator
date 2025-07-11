class_name AgentWaypointHandler
extends Node

@export var parent_object: Agent = null
@onready var starting_node: Waypoint = $fake_start
@onready var waypoint_lines: Node2D = $zzz_waypoint_lines
@onready var undo_stored_nodes: Node2D = $zzz_undo_stored_nodes

var waypoints: Array[Waypoint] = []
var waypoint_scene = preload("res://agents/waypoint.tscn")

@export var link_line_size = 5.0
@export var link_line_colour = Color(0.0, 0.0, 0.0, 1.0)

@export var camera: Camera2D = null : set = _set_camera
@export var disabled: bool = false : set = _set_disabled

var initialised = false
var clickable = true : set = _set_clickable
var base_editor: ScenarioEditor = null : set = _set_editor

func _ready():
	initialised = true

	_set_camera(camera)

	# Set the starting node
	starting_node.global_position = parent_object.global_position
	starting_node.parent_object = parent_object

	# Set the waypoint_lines parent variable
	waypoint_lines.waypoint_object = self

func get_save_data() -> Dictionary:
	var save_data = {}
	save_data["waypoints"] = []
	save_data["waypoints_version"] = 1
	save_data["starting_node"] = starting_node.get_save_data()

	for waypoint in waypoints:
		save_data["waypoints"].append(waypoint.get_save_data())

	return save_data

func load_save_data(data: Dictionary):
	if data.has("waypoints_version"):
		if data["waypoints_version"] <= 1:
			starting_node.load_save_data(data["starting_node"])

			for waypoint_data in data["waypoints"]:
				var new_waypoint = add_to_end(Vector2.ZERO, false)
				new_waypoint.load_save_data(waypoint_data)

func is_empty():
	return waypoints.is_empty()

func _find_corresponding_exit_waypoint(enter_waypoint_index: int) -> Waypoint:
	# Look through subsequent waypoints in the same agent to find the next EXIT waypoint
	# Since ENTER/EXIT are created as pairs, the next EXIT waypoint should be the corresponding one

	var enter_waypoint = get_waypoint(enter_waypoint_index)

	if not enter_waypoint:
		return null

	var current_wp = enter_waypoint.pt_next

	while current_wp != null:
		if current_wp.waypoint_type == Waypoint.WaypointType.EXIT:
			return current_wp
		current_wp = current_wp.pt_next

	return null

func _find_corresponding_enter_waypoint(exit_waypoint_index: int) -> Waypoint:
	# Look through previous waypoints in the same agent to find the most recent ENTER waypoint
	# Since ENTER/EXIT are created as pairs, the most recent ENTER waypoint should be the corresponding one

	var exit_waypoint = get_waypoint(exit_waypoint_index)

	if not exit_waypoint:
		return null

	var current_wp = exit_waypoint.pt_previous

	while current_wp != null:
		if current_wp.waypoint_type == Waypoint.WaypointType.ENTER:
			return current_wp

		current_wp = current_wp.pt_previous

	return null

func _add_waypoint_deletion_do_actions(del_point: Waypoint, undo_action: UndoRedoAction, custom_indices: Dictionary = {}) -> Dictionary:
	var current_point_index = custom_indices.get("current_point_index", get_waypoint_index(del_point))
	var previous_point_index = custom_indices.get("previous_point_index", current_point_index - 1 if current_point_index > 0 else -1)
	var next_point_index = custom_indices.get("next_point_index", current_point_index + 1 if current_point_index < len(waypoints) - 1 else null)


	# If the next point is EXIT node, then skip it (as it will be deleted too)
	if next_point_index != null and next_point_index != -1:
		var next_point = waypoints[next_point_index]

		if next_point.waypoint_type == Waypoint.WaypointType.EXIT:
			next_point_index += 1 if next_point_index < len(waypoints) - 1 else null

	if previous_point_index == null and next_point_index == null:
		print_debug("Error: Could not find previous or next point")
		return {}

	# Get the agent
	var undo_agent_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [parent_object.agent_id])
	undo_action.manual_add_item_to_store(parent_object, undo_agent_ref)

	# Store the waypoint objects directly and recalculate indices at execution time
	var current_point_ref = undo_action.manual_add_item_to_store(del_point)

	var previous_point = waypoints[previous_point_index] if previous_point_index != null and previous_point_index != -1 else starting_node
	var previous_point_ref = undo_action.manual_add_item_to_store(previous_point)

	var next_point = waypoints[next_point_index] if next_point_index != null else null
	var next_point_ref = undo_action.manual_add_item_to_store(next_point)

	var undo_ref_wp_agent = null
	var undo_ref_wp = null

	if del_point.vehicle_wp:
		undo_ref_wp_agent = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [del_point.vehicle_wp.parent_object.agent_id])
		undo_action.manual_add_item_to_store(del_point.vehicle_wp.parent_object, undo_ref_wp_agent)

		var reference_waypoint_index = del_point.vehicle_wp.parent_object.waypoints.get_waypoint_index(del_point.vehicle_wp)

		undo_ref_wp = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(x, ref_wp_index):
			return x.waypoints.waypoints[ref_wp_index]
			, [undo_ref_wp_agent, reference_waypoint_index], [undo_ref_wp_agent]
		)

		undo_action.manual_add_item_to_store(del_point.vehicle_wp, undo_ref_wp)

	# Update the links in the points
	undo_action.action_method(UndoRedoAction.DoType.Do, func(previous_point, next_point):
		if previous_point:
			previous_point.pt_next = next_point
		if next_point:
			next_point.pt_previous = previous_point
		, [previous_point_ref, next_point_ref], [previous_point_ref, next_point_ref]
	)

	# Remove from reference waypoint if enter/exit type
	if del_point.vehicle_wp:
		undo_action.action_method(UndoRedoAction.DoType.Do, func(ref_wp, current_point):
			if current_point.waypoint_type == Waypoint.WaypointType.ENTER:
				ref_wp.enter_nodes.erase(current_point)
			elif current_point.waypoint_type == Waypoint.WaypointType.EXIT:
				ref_wp.exit_nodes.erase(current_point)
			, [undo_ref_wp, current_point_ref], [undo_ref_wp, current_point_ref]
		)

	# Remove from array and scene tree
	undo_action.action_method(UndoRedoAction.DoType.Do, func(agent, current_point):
		var del_index = agent.waypoints.get_waypoint_index(current_point)
		agent.waypoints.waypoints.erase(current_point)
		agent.waypoints.remove_child(current_point)
		agent.waypoints.undo_stored_nodes.add_child(current_point)

		# Update event waypoint indices for deletion
		if agent.waypoints.base_editor and agent.waypoints.base_editor.event_emittor:
			agent.waypoints.base_editor.event_emittor.update_waypoint_indices_after_deletion(agent.agent_id, del_index)
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

	# Redraw the reference agent's waypoints
	if del_point.vehicle_wp and undo_ref_wp_agent:
		undo_action.action_method(UndoRedoAction.DoType.Do, func(ref_agent):
			ref_agent.waypoints.waypoint_lines.queue_redraw()
			, [undo_ref_wp_agent], [undo_ref_wp_agent]
		)

	# Return the calculated data for UNDO actions
	return {
		"current_point_index": current_point_index,
		"previous_point_index": previous_point_index,
		"next_point_index": next_point_index,
		"current_point_ref": current_point_ref,
		"previous_point_ref": previous_point_ref,
		"next_point_ref": next_point_ref,
		"undo_agent_ref": undo_agent_ref,
		"undo_ref_wp": undo_ref_wp,
		"undo_ref_wp_agent": undo_ref_wp_agent
	}

func _add_waypoint_deletion_undo_actions(del_point: Waypoint, undo_action: UndoRedoAction, do_data: Dictionary):
	# Use the data calculated during DO actions
	var current_point_index = do_data["current_point_index"]
	var current_point_ref = do_data["current_point_ref"]
	var previous_point_ref = do_data["previous_point_ref"]
	var next_point_ref = do_data["next_point_ref"]
	var undo_agent_ref = do_data["undo_agent_ref"]
	var undo_ref_wp = do_data["undo_ref_wp"]
	var undo_ref_wp_agent = do_data["undo_ref_wp_agent"]

	# Re-insert the point into the array
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(agent, current_point, previous_point, next_point):
		# Recalculate insertion index based on current state
		var insert_index = 0
		if previous_point == agent.waypoints.starting_node:
			insert_index = 0
		elif previous_point and previous_point in agent.waypoints.waypoints:
			insert_index = agent.waypoints.waypoints.find(previous_point) + 1
		elif next_point and next_point in agent.waypoints.waypoints:
			insert_index = agent.waypoints.waypoints.find(next_point)
		else:
			insert_index = agent.waypoints.waypoints.size()

		agent.waypoints.waypoints.insert(insert_index, current_point)
		agent.waypoints.undo_stored_nodes.remove_child(current_point)
		agent.waypoints.add_child(current_point)

		# Undo event waypoint indices update for deletion (restore by insertion)
		if agent.waypoints.base_editor and agent.waypoints.base_editor.event_emittor:
			agent.waypoints.base_editor.event_emittor.update_waypoint_indices_after_insertion(agent.agent_id, insert_index)
		, [undo_agent_ref, current_point_ref, previous_point_ref, next_point_ref], [undo_agent_ref, current_point_ref, previous_point_ref, next_point_ref]
	)

	# Re-setup enter/exit nodes
	if del_point.vehicle_wp and undo_ref_wp:
		undo_action.action_method(UndoRedoAction.DoType.Undo, func(ref_wp, current_point):
			if current_point.waypoint_type == Waypoint.WaypointType.ENTER:
				ref_wp.enter_nodes.append(current_point)
				current_point.vehicle_wp = ref_wp
			elif current_point.waypoint_type == Waypoint.WaypointType.EXIT:
				ref_wp.exit_nodes.append(current_point)
				current_point.vehicle_wp = ref_wp
			, [undo_ref_wp, current_point_ref], [undo_ref_wp, current_point_ref]
		)

	# Re-link the points
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(previous_point, next_point, current_point):
		# Set current point's links
		current_point.pt_previous = previous_point
		current_point.pt_next = next_point

		# Update neighboring points to link to current point
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

	# Redraw the reference agent's waypoints if this is an enter/exit waypoint
	if del_point.vehicle_wp and undo_ref_wp_agent:
		undo_action.action_method(UndoRedoAction.DoType.Undo, func(ref_agent):
			ref_agent.waypoints.waypoint_lines.queue_redraw()
			, [undo_ref_wp_agent], [undo_ref_wp_agent]
		)

	# Free the point when the action is deleted
	undo_action.action_method(UndoRedoAction.DoType.OnRemoval, func(current_point):
		if current_point:
			current_point.queue_free()
		, [current_point_ref], current_point_ref
	)

func delete_waypoint(del_point: Waypoint, undo_action_in: UndoRedoAction = null, prevent_paired_deletion: bool = false):
	# Create undo action
	var undo_action = undo_action_in
	var current_point_index = get_waypoint_index(del_point)

	if undo_action == null:
		undo_action = UndoRedoAction.new()
		undo_action.action_name = "Delete Waypoint %d" % current_point_index

	# DO actions: Main waypoint first, then corresponding waypoint
	var main_do_data = _add_waypoint_deletion_do_actions(del_point, undo_action)

	# Find corresponding waypoint if needed
	var corresponding_waypoint = null
	var corresponding_do_data = null
	if not prevent_paired_deletion:
		if del_point.waypoint_type == Waypoint.WaypointType.ENTER:
			corresponding_waypoint = _find_corresponding_exit_waypoint(current_point_index)
		elif del_point.waypoint_type == Waypoint.WaypointType.EXIT:
			corresponding_waypoint = _find_corresponding_enter_waypoint(current_point_index)

		# Update action name if we found a corresponding waypoint
		if corresponding_waypoint and undo_action_in == null:
			undo_action.action_name = "Delete Enter/Exit Waypoint Pair"

	if corresponding_waypoint:
		# Calculate adjusted indices for corresponding waypoint
		# Since main waypoint will be deleted first, indices after it will shift down by 1
		var corresponding_index = get_waypoint_index(corresponding_waypoint)
		var adjusted_corresponding_index = corresponding_index
		var adjusted_previous_index = corresponding_index - 1 if corresponding_index > 0 else -1
		var adjusted_next_index = corresponding_index + 1 if corresponding_index < len(waypoints) - 1 else null

		# Handle the different scenarios based on waypoint types
		var main_waypoint_type = del_point.waypoint_type
		var corresponding_waypoint_type = corresponding_waypoint.waypoint_type

		if main_waypoint_type == Waypoint.WaypointType.ENTER and corresponding_waypoint_type == Waypoint.WaypointType.EXIT:
			# ENTER -> EXIT scenario: Delete ENTER first, then EXIT
			# EXIT waypoint's previous should be ENTER's previous (starting_node)
			# EXIT waypoint's next should be EXIT's next (AFTER_EXIT)
			adjusted_corresponding_index = corresponding_index - 1  # EXIT moves down by 1
			adjusted_previous_index = current_point_index - 1 if current_point_index > 0 else -1  # ENTER's previous
			adjusted_next_index = corresponding_index + 1 if corresponding_index < len(waypoints) - 1 else null  # EXIT's next
			if adjusted_next_index != null and adjusted_next_index > current_point_index:
				adjusted_next_index = adjusted_next_index - 1  # Adjust for ENTER deletion
		elif main_waypoint_type == Waypoint.WaypointType.EXIT and corresponding_waypoint_type == Waypoint.WaypointType.ENTER:
			# EXIT -> ENTER scenario: Delete EXIT first, then ENTER
			# ENTER waypoint's previous should be ENTER's previous (starting_node)
			# ENTER waypoint's next should be EXIT's next (AFTER_EXIT)
			adjusted_corresponding_index = corresponding_index  # ENTER stays at same index
			adjusted_previous_index = corresponding_index - 1 if corresponding_index > 0 else -1  # ENTER's previous
			adjusted_next_index = current_point_index + 1 if current_point_index < len(waypoints) - 1 else null  # EXIT's next
		else:
			# Fallback to original logic for other cases
			if corresponding_index > current_point_index:
				adjusted_corresponding_index = corresponding_index - 1
				if adjusted_previous_index != -1 and adjusted_previous_index > current_point_index:
					adjusted_previous_index = adjusted_previous_index - 1
				if adjusted_next_index != null and adjusted_next_index > current_point_index:
					adjusted_next_index = adjusted_next_index - 1
			else:
				if adjusted_next_index != null and adjusted_next_index >= current_point_index:
					adjusted_next_index = adjusted_next_index - 1

		# Pass the adjusted indices to the function
		var adjusted_indices = {
			"current_point_index": adjusted_corresponding_index,
			"previous_point_index": adjusted_previous_index,
			"next_point_index": adjusted_next_index
		}
		corresponding_do_data = _add_waypoint_deletion_do_actions(corresponding_waypoint, undo_action, adjusted_indices)

		_add_waypoint_deletion_undo_actions(corresponding_waypoint, undo_action, corresponding_do_data)

	_add_waypoint_deletion_undo_actions(del_point, undo_action, main_do_data)

	# Final redraw for reference agent after all deletions are complete
	if corresponding_waypoint and del_point.vehicle_wp:
		var final_ref_agent = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [del_point.vehicle_wp.parent_object.agent_id])
		undo_action.manual_add_item_to_store(del_point.vehicle_wp.parent_object, final_ref_agent)

		undo_action.action_method(UndoRedoAction.DoType.Do, func(ref_agent):
			ref_agent.waypoints.waypoint_lines.queue_redraw()
			, [final_ref_agent], [final_ref_agent]
		)

	# Finalize undo action only if we created it
	if undo_action_in == null:
		UndoSystem.add_action(undo_action)

func get_waypoint_index(waypoint: Waypoint):
	for i in len(waypoints):
		if waypoints[i] == waypoint:
			return i

	if waypoint == starting_node:
		return -1

	return -2

func get_waypoint(waypoint_index: int):
	if waypoint_index == -1:
		return starting_node
	elif waypoint_index < waypoints.size():
		return waypoints[waypoint_index]
	else:
		return null

func add_to_end(new_global_point: Vector2, add_to_undo: bool = true, waypoint_type: Waypoint.WaypointType = Waypoint.WaypointType.WAYPOINT, reference_waypoint: Waypoint = null) -> Waypoint:
	# Get the end point of the array to use as a link
	var previous_point = waypoints[-1] if not waypoints.is_empty() else starting_node

	# Instantiate and append
	var new_waypoint = _instantiate_waypoint(new_global_point, previous_point, null, waypoint_type)
	waypoints.append(new_waypoint)

	# Add to the reference waypoint if enter/exit type
	if reference_waypoint:
		if waypoint_type == Waypoint.WaypointType.ENTER:
			reference_waypoint.enter_nodes.append(new_waypoint)
			new_waypoint.vehicle_wp = reference_waypoint
		elif waypoint_type == Waypoint.WaypointType.EXIT:
			reference_waypoint.exit_nodes.append(new_waypoint)
			new_waypoint.vehicle_wp = reference_waypoint

	# Queue line redraw
	waypoint_lines.queue_redraw()

	if not add_to_undo:
		return new_waypoint

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

	# If reference waypoint, get the reference waypoint
	var undo_ref_wp_agent = null
	var undo_ref_wp = null

	if reference_waypoint:
		# Get the agent
		undo_ref_wp_agent = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [reference_waypoint.parent_object.agent_id])
		undo_action.manual_add_item_to_store(reference_waypoint.parent_object, undo_ref_wp_agent)

		# Get the reference waypoint
		var reference_waypoint_index = reference_waypoint.parent_object.waypoints.get_waypoint_index(reference_waypoint)

		undo_ref_wp = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(x, ref_wp_index):
			return x.waypoints.waypoints[ref_wp_index]
			, [undo_ref_wp_agent, reference_waypoint_index], [undo_ref_wp_agent]
		)

		undo_action.manual_add_item_to_store(reference_waypoint, undo_ref_wp)

	# Instantiate the new waypoint
	var undo_new_waypoint = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(x, new_global_point, previous_point):
		return x.waypoints._instantiate_waypoint(new_global_point, previous_point, null, waypoint_type)
		, [undo_agent_ref, new_global_point, undo_previous_point], [undo_agent_ref, undo_previous_point]
	)

	undo_action.manual_add_item_to_store(new_waypoint, undo_new_waypoint)
	undo_action.manual_add_item_to_store(previous_point, undo_previous_point)

	# Add to waypoints
	undo_action.action_method(UndoRedoAction.DoType.Do, func(new_wp, agent):
		agent.waypoints.waypoints.append(new_wp)
		, [undo_new_waypoint, undo_agent_ref], [undo_new_waypoint, undo_agent_ref]
	)

	# Add to reference waypoint if enter/exit type
	if reference_waypoint:
		undo_action.action_method(UndoRedoAction.DoType.Do, func(ref_wp, new_wp):
			if waypoint_type == Waypoint.WaypointType.ENTER:
				ref_wp.enter_nodes.append(new_wp)
				new_wp.vehicle_wp = ref_wp
			elif waypoint_type == Waypoint.WaypointType.EXIT:
				ref_wp.exit_nodes.append(new_wp)
				new_wp.vehicle_wp = ref_wp
			, [undo_ref_wp, undo_new_waypoint], [undo_ref_wp, undo_new_waypoint]
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

	# Remove from reference waypoint if enter/exit type
	if reference_waypoint:
		undo_action.action_method(UndoRedoAction.DoType.Undo, func(ref_wp, new_wp):
			if waypoint_type == Waypoint.WaypointType.ENTER:
				ref_wp.enter_nodes.erase(new_wp)
			elif waypoint_type == Waypoint.WaypointType.EXIT:
				ref_wp.exit_nodes.erase(new_wp)
			, [undo_ref_wp, undo_new_waypoint], [undo_ref_wp, undo_new_waypoint]
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

func insert_after(current_point: Waypoint, new_global_point: Vector2, waypoint_type: Waypoint.WaypointType = Waypoint.WaypointType.WAYPOINT, reference_waypoint: Waypoint = null) -> Waypoint:

	var rv = _get_insert_pos(current_point)

	var insert_pos = rv[0]
	var next_point: Waypoint = rv[1]

	if insert_pos == -1:
		return null

	if next_point == null:
		return add_to_end(new_global_point, true, waypoint_type, reference_waypoint)

	var new_waypoint: Waypoint = _instantiate_waypoint(new_global_point, current_point, next_point, waypoint_type)
	new_waypoint.camera = camera

	waypoints.insert(insert_pos, new_waypoint)

	# Update event waypoint indices for insertion
	if base_editor and base_editor.event_emittor:
		base_editor.event_emittor.update_waypoint_indices_after_insertion(parent_object.agent_id, insert_pos)

	# Add to the reference waypoint if enter/exit type
	if reference_waypoint:
		if waypoint_type == Waypoint.WaypointType.ENTER:
			reference_waypoint.enter_nodes.append(new_waypoint)
			new_waypoint.vehicle_wp = reference_waypoint
		elif waypoint_type == Waypoint.WaypointType.EXIT:
			reference_waypoint.exit_nodes.append(new_waypoint)
			new_waypoint.vehicle_wp = reference_waypoint

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

	# If reference waypoint, get the reference waypoint

	var undo_ref_wp_agent = null
	var undo_ref_wp = null

	if reference_waypoint:
		undo_ref_wp_agent = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [reference_waypoint.parent_object.agent_id])
		undo_action.manual_add_item_to_store(reference_waypoint.parent_object, undo_ref_wp_agent)

		var reference_waypoint_index = reference_waypoint.parent_object.waypoints.get_waypoint_index(reference_waypoint)

		undo_ref_wp = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(x, ref_wp_index):
			return x.waypoints.waypoints[ref_wp_index]
			, [undo_ref_wp_agent, reference_waypoint_index], [undo_ref_wp_agent]
		)

		undo_action.manual_add_item_to_store(reference_waypoint, undo_ref_wp)

	# Instantiate the new waypoint
	var undo_new_waypoint = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(x, current_point, next_point):
		return x.waypoints._instantiate_waypoint(new_global_point, current_point, next_point, waypoint_type)
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

	# Add to reference waypoint if enter/exit type
	if reference_waypoint:
		undo_action.action_method(UndoRedoAction.DoType.Do, func(ref_wp, new_wp):
			if waypoint_type == Waypoint.WaypointType.ENTER:
				ref_wp.enter_nodes.append(new_wp)
				new_wp.vehicle_wp = ref_wp
			elif waypoint_type == Waypoint.WaypointType.EXIT:
				ref_wp.exit_nodes.append(new_wp)
				new_wp.vehicle_wp = ref_wp
			, [undo_ref_wp, undo_new_waypoint], [undo_ref_wp, undo_new_waypoint]
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

	# Undo event waypoint indices update for insertion
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(agent_id, pos):
		var agent = TreeFuncs.get_agent_with_id(agent_id)
		if agent and agent.waypoints.base_editor and agent.waypoints.base_editor.event_emittor:
			agent.waypoints.base_editor.event_emittor.update_waypoint_indices_after_insertion_undo(agent_id, pos)
		, [parent_object.agent_id, insert_pos]
	)

	# Remove from previous point
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(current_point, next_point):
		current_point.pt_next = next_point
		next_point.pt_previous = current_point
		, [undo_current_point, undo_next_point], [undo_current_point, undo_next_point]
	)

	# Erase from reference waypoint if enter/exit type
	if reference_waypoint:
		undo_action.action_method(UndoRedoAction.DoType.Undo, func(ref_wp, new_wp):
			if waypoint_type == Waypoint.WaypointType.ENTER:
				ref_wp.enter_nodes.erase(new_wp)
			elif waypoint_type == Waypoint.WaypointType.EXIT:
				ref_wp.exit_nodes.erase(new_wp)
			, [undo_ref_wp, undo_new_waypoint], [undo_ref_wp, undo_new_waypoint]
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

func _instantiate_waypoint(new_global_point: Vector2, previous_point: Waypoint, next_point: Waypoint, waypoint_type: Waypoint.WaypointType = Waypoint.WaypointType.WAYPOINT) -> Waypoint:

	print_debug("Instantiating waypoint at %s [%s -> %s]" % [new_global_point, previous_point, next_point])
	var new_waypoint: Waypoint = waypoint_scene.instantiate()
	new_waypoint.global_position = new_global_point
	new_waypoint.camera = camera

	if parent_object:
		new_waypoint.parent_object = parent_object

	base_editor.ui_scale_set.connect(new_waypoint.ui_scale_update)

	add_child(new_waypoint)

	if previous_point:
		previous_point.pt_next = new_waypoint
		new_waypoint.pt_previous = previous_point

	if next_point:
		next_point.pt_previous = new_waypoint
		new_waypoint.pt_next = next_point

	if waypoint_type != Waypoint.WaypointType.WAYPOINT:
		new_waypoint.disabled = true
		new_waypoint.waypoint_type = waypoint_type

	return new_waypoint

func _set_camera(new_camera):
	camera = new_camera

	# Cycle through all waypoints and set the camera
	for waypoint in waypoints:
		waypoint.camera = new_camera

func _set_clickable(value):
	clickable = value

	for waypoint in waypoints:
		waypoint.clickable = clickable

func _set_disabled(value):
	disabled = value
	waypoint_lines.draw_lines = not value
	waypoint_lines.queue_redraw()

	for waypoint in waypoints:
		waypoint.disabled = disabled

func _set_editor(editor: ScenarioEditor):
	base_editor = editor
