class_name Waypoint
extends Node2D

@onready var pt_next: Waypoint = null
@onready var pt_previous: Waypoint = null

@onready var _sprite = $Sprite2D
@onready var _selection_area = $SelectionArea2D
@onready var _collision_shape = $SelectionArea2D/CollisionPolygon2D

@export var disabled: bool = false : set = _disable
@export var clickable: bool = true : set = _clickable

@onready var context_menu = $ContextMenu

var ui_scale: float = 1.0

enum ContextMenuIDs {
	DELETE,
	PROPERTIES,
	LINK_WAYPOINT,
	CREATE_EVENT,
	ENTER_VEHICLE,
	EXIT_VEHICLE = 100,
	EDIT_EVENT = 200,
}

enum WaypointType {
	WAYPOINT,
	ENTER,
	EXIT,
}

var waypoint_type = WaypointType.WAYPOINT

var param_speed_mps = 1.42
var param_start_time = null
var param_wait_time = null
var param_accel: float = -1.0

var parent_object: Agent = null

var initialised = false
@export var camera: Camera2D = null

var linked_nodes: Array[Waypoint] = []
var linked_ready: bool = false : set = _linked_ready_changed
signal linked_ready_changed(value: bool)

# Vehicle enter/exit variables
var enter_nodes: Array[Waypoint] = []
var exit_nodes: Array[Waypoint] = []
var vehicle_wp = null
var enter_vehicle = null # TODO: Reset after play finished

var load_linked_nodes: Array = []
var load_enter_exit_nodes: Array = []

# event info
var _events: Array[SimulationEventExporterManual] = []

# Called when the node enters the scene tree for the first time.
func _ready():
	initialised = true

	if disabled:
		_disable(disabled)

	# Connect to the selection area's mouse events
	_selection_area.connect("selection_toggled", self._on_selected)

	_selection_area.connect("mouse_click", self._on_mouse)


func _prepare_menu():
	context_menu.clear()

	context_menu.add_item("Delete Waypoint", ContextMenuIDs.DELETE)
	context_menu.add_item("Properties", ContextMenuIDs.PROPERTIES)
	context_menu.add_item("Create Event", ContextMenuIDs.CREATE_EVENT)

	# If waypoint of another agent is selected, add "Enter Vehicle" to the menu
	var all_selected_objects = get_tree().get_nodes_in_group("selected")

	if not all_selected_objects.is_empty():
		var selected_object = all_selected_objects[0].parent_object
		var valid_enter_exit = false
		var link = false

		if selected_object is Waypoint:
			if selected_object.parent_object != parent_object:
				link = true
				if parent_object.is_vehicle:
					valid_enter_exit = true

		if selected_object is Agent:
			if selected_object != parent_object and parent_object.is_vehicle:
				link = true
				if parent_object.is_vehicle:
					valid_enter_exit = true

		if link or valid_enter_exit:
			context_menu.add_separator()

		if link:
			context_menu.add_item("Link to Target", ContextMenuIDs.LINK_WAYPOINT)

		if valid_enter_exit:
			context_menu.add_item("Enter Vehicle", ContextMenuIDs.ENTER_VEHICLE)

	# Check all previous waypoints for an unresolved enter/exit, and add items
	# to the menu if found for each agent

	var all_entered_agents_wp: Array[Waypoint] = []
	var all_exited_agents_wp: Array[Waypoint] = []
	var prev_wp = pt_previous

	while prev_wp != null:
		for enter_wps in prev_wp.enter_nodes:
			all_entered_agents_wp.append(enter_wps)

		for exit_wps in prev_wp.exit_nodes:
			all_exited_agents_wp.append(exit_wps)

		prev_wp = prev_wp.pt_previous

	# If we come across an exit, remove the corresponding enter
	for exit_wp in all_exited_agents_wp:
		var agent_id = exit_wp.parent_object.agent_id

		for enter_wp in all_entered_agents_wp:
			if enter_wp.parent_object.agent_id == agent_id:
				all_entered_agents_wp.erase(enter_wp)


	if not all_entered_agents_wp.is_empty():
		context_menu.add_separator()

		for enter_wp in all_entered_agents_wp:
			context_menu.add_item("Exit Vehicle A%d" % [enter_wp.parent_object.agent_id], ContextMenuIDs.EXIT_VEHICLE + enter_wp.parent_object.agent_id)

	if not _events.is_empty():
		context_menu.add_separator()

		for event in _events:
			context_menu.add_item("Edit Event %s" % event.description, ContextMenuIDs.EDIT_EVENT)

	# Connect to the context menu's id_pressed signal
	if not context_menu.is_connected("id_pressed", self._context_menu_id_pressed):
		context_menu.connect("id_pressed", self._context_menu_id_pressed)

func get_save_data() -> Dictionary:
	var save_data = {
		"waypoint_version": 4,
		"global_position": {
			"x": global_position.x / PlayTimer.ui_scale,
			"y": global_position.y / PlayTimer.ui_scale,
		},
		"param_speed_mps": param_speed_mps,
		"param_start_time": param_start_time,
		"param_wait_time": param_wait_time,
		"param_accel": param_accel,
		"linked_nodes": [],
		"waypoint_type": waypoint_type,
	}

	for node in linked_nodes:
		var node_data = {
			"agent_id": node.parent_object.agent_id,
			"waypoint_index": node.parent_object.waypoints.get_waypoint_index(node),
		}

		save_data["linked_nodes"].append(node_data)

	if vehicle_wp:
		save_data["vehicle_wp"] = [vehicle_wp.parent_object.agent_id, vehicle_wp.parent_object.waypoints.get_waypoint_index(vehicle_wp)]

	return save_data

func load_save_data(data: Dictionary):
	if data.has("waypoint_version"):
		if data["waypoint_version"] <= 4:
			global_position = Vector2(data["global_position"]["x"], data["global_position"]["y"])
			param_speed_mps = data["param_speed_mps"] if data["param_speed_mps"] != null else null
			param_start_time = data["param_start_time"] if data["param_start_time"] != null else null
			param_wait_time = data["param_wait_time"] if data["param_wait_time"] != null else null

			if data["waypoint_version"] >= 2:
				if not data["linked_nodes"].is_empty():
					load_linked_nodes = data["linked_nodes"]

			if data["waypoint_version"] >= 3:
				waypoint_type = data["waypoint_type"]

				if waypoint_type == WaypointType.ENTER or waypoint_type == WaypointType.EXIT:
					disabled = true

				if "vehicle_wp" in data:
					load_enter_exit_nodes = data["vehicle_wp"]

			param_accel = -1.0

			if data["waypoint_version"] >= 4:
				param_accel = data["param_accel"]

		else:
			print_debug("Unknown waypoint version: %s" % data["waypoint_version"])
	else:
		print_debug("Waypoint data has no version number")

func _process(delta):
	if not load_linked_nodes.is_empty():
		for node_data in load_linked_nodes:
			var agent_id = node_data["agent_id"]
			var waypoint_index = node_data["waypoint_index"]

			var agent: Agent = TreeFuncs.get_agent_with_id(agent_id)

			if not agent:
				printerr("Agent [ %d ] not found for waypoint link" % agent_id)
				continue

			var waypoint = agent.waypoints.get_waypoint(waypoint_index)

			if waypoint not in linked_nodes:
				linked_nodes.append(waypoint)
				waypoint.linked_nodes.append(self)

		parent_object.waypoints.waypoint_lines.queue_redraw()

		load_linked_nodes.clear()

	if not load_enter_exit_nodes.is_empty():
		var agent_id = load_enter_exit_nodes[0]
		var wp_id = load_enter_exit_nodes[1]

		var agent: Agent = TreeFuncs.get_agent_with_id(agent_id)

		if agent:
			var waypoint = agent.waypoints.get_waypoint(wp_id)

			if waypoint:
				if waypoint_type == WaypointType.ENTER:
					waypoint.enter_nodes.append(self)
				elif waypoint_type == WaypointType.EXIT:
					waypoint.exit_nodes.append(self)
				else:
					printerr("No waypoint type on load enter/exit?")

				vehicle_wp = waypoint

				load_enter_exit_nodes.clear()
		else:
			printerr("Agent [ %d ] not found for enter/exit waypoint" % agent_id)


func _context_menu_id_pressed(id: ContextMenuIDs):
	match id:
		ContextMenuIDs.DELETE:
			parent_object.waypoints.delete_waypoint(self)
		ContextMenuIDs.PROPERTIES:
			# HACK: Select the waypoint, then the properties dialog will be opened
			_selection_area.selected = true
		ContextMenuIDs.CREATE_EVENT:
			parent_object.base_editor.create_event_on_waypoint(parent_object.agent_id, parent_object.waypoints.get_waypoint_index(self))
		ContextMenuIDs.LINK_WAYPOINT:
			_on_link()
		ContextMenuIDs.ENTER_VEHICLE:
			_on_enter_vehicle()

	if id >= ContextMenuIDs.EXIT_VEHICLE and id < ContextMenuIDs.EDIT_EVENT:
		var agent_id = id - ContextMenuIDs.EXIT_VEHICLE
		var agent: Agent = TreeFuncs.get_agent_with_id(agent_id)

		# Find most recent ENTER waypoint for the agent
		var prev_wp = pt_previous
		var enter_wp = null

		while prev_wp != null:
			for wp in prev_wp.enter_nodes:
				if wp.parent_object == agent:
					enter_wp = wp
					break

			prev_wp = prev_wp.pt_previous

		# Error if no ENTER waypoint found
		if enter_wp == null:
			print_debug("No ENTER waypoint found for agent %d" % agent_id)
			return

		# If after this waypoint is another EXIT before an ENTER, remove it
		var next_wp = pt_next
		var exit_wp = null

		while next_wp != null:
			for wp in next_wp.enter_nodes:
				if wp.parent_object == agent:
					break

			for wp in next_wp.exit_nodes:
				if wp.parent_object == agent:
					exit_wp = wp
					break

			next_wp = next_wp.pt_next

		if exit_wp != null:
			agent.waypoints.delete_waypoint(exit_wp)

		# Insert the EXIT waypoint after this waypoint
		exit_wp = agent.waypoints.insert_after(enter_wp, global_position, WaypointType.EXIT, self)

		# If exit_wp has no next waypoint, add one a short distance away
		if exit_wp.pt_next == null:
			agent.waypoints.insert_after(exit_wp, global_position + Vector2(64, 64), WaypointType.WAYPOINT, self)

	if id >= ContextMenuIDs.EDIT_EVENT:
		var event_index = id - ContextMenuIDs.EDIT_EVENT
		var event = _events[event_index]

		parent_object.base_editor.edit_event(event)

func _on_link():
	var all_selected_objects = get_tree().get_nodes_in_group("selected")

	if not all_selected_objects.is_empty():
		var selected_object = all_selected_objects[0].parent_object
		var waypoint_handler: AgentWaypointHandler = null
		var curr_wp: Waypoint = null

		if selected_object is Waypoint:
			waypoint_handler = selected_object.parent_object.waypoints
			curr_wp = selected_object

		if selected_object is Agent:
			waypoint_handler = selected_object.waypoints
			curr_wp = waypoint_handler.starting_node

		# Check if waypoint is already linked
		if curr_wp in linked_nodes:
			print_debug("Waypoint already linked")
			return

		# Check if waypoint is from the same agent
		if curr_wp.parent_object == parent_object:
			print_debug("Waypoint from same agent")
			return

		link_waypoint(curr_wp)

func _on_enter_vehicle():
	var all_selected_objects = get_tree().get_nodes_in_group("selected")

	if not all_selected_objects.is_empty():
		var selected_object = all_selected_objects[0].parent_object
		var waypoint_handler: AgentWaypointHandler = null
		var curr_wp: Waypoint = null

		if selected_object is Waypoint:
			waypoint_handler = selected_object.parent_object.waypoints
			curr_wp = selected_object

		if selected_object is Agent:
			waypoint_handler = selected_object.waypoints
			curr_wp = waypoint_handler.starting_node

		if waypoint_handler == null:
			print_debug("Unknown object type on Enter Vehicle")

		waypoint_handler.insert_after(curr_wp, global_position, WaypointType.ENTER, self)


func link_waypoint(waypoint_node: Waypoint):
	# Check if waypoint is already linked
	if waypoint_node in linked_nodes:
		print_debug("Waypoint already linked. Aborting.")
		return

	# Check if waypoint is from the same agent
	if waypoint_node.parent_object == parent_object:
		print_debug("Waypoint from same agent. Aborting.")
		return

	######
	# Add undo action
	######

	var undo_action = UndoRedoAction.new()

	var agent_id = parent_object.agent_id
	var waypoint_index = parent_object.waypoints.get_waypoint_index(self)

	var other_agent_id = waypoint_node.parent_object.agent_id
	var other_waypoint_index = waypoint_node.parent_object.waypoints.get_waypoint_index(waypoint_node)

	undo_action.action_name = "Link Waypoints A%sW%s to A%sW%s" % [agent_id, waypoint_index, waypoint_node.parent_object.agent_id, other_waypoint_index]

	# Get the agent refs
	var agent_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [agent_id])
	var other_agent_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [other_agent_id])
	undo_action.manual_add_item_to_store(parent_object, agent_ref)
	undo_action.manual_add_item_to_store(waypoint_node.parent_object, other_agent_ref)

	# Get the waypoint refs
	var waypoint_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(agent, index):
		if index == -1:
			return agent.waypoints.starting_node
		else:
			return agent.waypoints.waypoints[index]
		, [agent_ref, waypoint_index], agent_ref)
	undo_action.manual_add_item_to_store(self, waypoint_ref)

	var other_waypoint_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(agent, index):
		if index == -1:
			return agent.waypoints.starting_node
		else:
			return agent.waypoints.waypoints[index]
		, [other_agent_ref, other_waypoint_index], other_agent_ref)
	undo_action.manual_add_item_to_store(waypoint_node, other_waypoint_ref)

	# Add the waypoint to the other agent's linked waypoints
	undo_action.action_method(UndoRedoAction.DoType.Do, func(waypoint, other_waypoint):
		waypoint.linked_nodes.append(other_waypoint)
		other_waypoint.linked_nodes.append(waypoint)
		, [waypoint_ref, other_waypoint_ref], [waypoint_ref, other_waypoint_ref])

	# Queue redraw of waypoint lines
	undo_action.action_method(UndoRedoAction.DoType.Do, func(agent):
		agent.waypoints.waypoint_lines.queue_redraw()
		, [agent_ref], agent_ref)

	######
	# UNDO
	######

	# Undo the waypoint from the other agent's linked waypoints
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(waypoint, other_waypoint):
		waypoint.linked_nodes.erase(other_waypoint)
		other_waypoint.linked_nodes.erase(waypoint)
		, [waypoint_ref, other_waypoint_ref], [waypoint_ref, other_waypoint_ref])

	# Queue redraw of waypoint lines
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(agent):
		agent.waypoints.waypoint_lines.queue_redraw()
		, [agent_ref], agent_ref)

	UndoSystem.add_action(undo_action)

func unlink_waypoint(node: Waypoint):
	if node in linked_nodes:
		# linked_nodes.erase(node)
		# node.linked_nodes.erase(self)

		######
		# Add undo action
		######

		var undo_action = UndoRedoAction.new()
		undo_action.action_name = "Unlink Waypoints A%sW%s to A%sW%s" % [parent_object.agent_id, parent_object.waypoints.get_waypoint_index(self), node.parent_object.agent_id, node.parent_object.waypoints.get_waypoint_index(node)]

		# Get the agent refs
		var agent_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [parent_object.agent_id])
		var other_agent_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [node.parent_object.agent_id])

		# Get the waypoint refs
		var waypoint_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(agent, index):
			if index == -1:
				return agent.waypoints.starting_node
			else:
				return agent.waypoints.waypoints[index]
			, [agent_ref, parent_object.waypoints.get_waypoint_index(self)], agent_ref)

		var other_waypoint_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(agent, index):
			if index == -1:
				return agent.waypoints.starting_node
			else:
				return agent.waypoints.waypoints[index]
			, [other_agent_ref, node.parent_object.waypoints.get_waypoint_index(node)], other_agent_ref)

		# Remove the waypoint from both agents' linked waypoints
		undo_action.action_method(UndoRedoAction.DoType.Do, func(waypoint, other_waypoint):
			waypoint.linked_nodes.erase(other_waypoint)
			other_waypoint.linked_nodes.erase(waypoint)
			, [waypoint_ref, other_waypoint_ref], [waypoint_ref, other_waypoint_ref])

		# Queue redraw of waypoint lines
		undo_action.action_method(UndoRedoAction.DoType.Do, func(agent, other_agent):
			agent.waypoints.waypoint_lines.queue_redraw()
			other_agent.waypoints.waypoint_lines.queue_redraw()
			, [agent_ref, other_agent_ref], [agent_ref, other_agent_ref])

		######
		# UNDO
		######

		# Add the waypoint to both agents' linked waypoints
		undo_action.action_method(UndoRedoAction.DoType.Undo, func(waypoint, other_waypoint):
			waypoint.linked_nodes.append(other_waypoint)
			other_waypoint.linked_nodes.append(waypoint)
			, [waypoint_ref, other_waypoint_ref], [waypoint_ref, other_waypoint_ref])

		# Queue redraw of waypoint lines
		undo_action.action_method(UndoRedoAction.DoType.Undo, func(agent, other_agent):
			agent.waypoints.waypoint_lines.queue_redraw()
			other_agent.waypoints.waypoint_lines.queue_redraw()
			, [agent_ref, other_agent_ref], [agent_ref, other_agent_ref])

		UndoSystem.add_action(undo_action)

func _on_mouse(_mouse, event):
	if event.is_action_pressed("mouse_menu") and camera != null and clickable:
		_popup_menu_at_mouse()


func _popup_menu_at_mouse():
	var mouse_pos = MousePosition.mouse_global_position
	var mouse_rel_pos = MousePosition.mouse_relative_position

	_prepare_menu()

	# Popup the window
	context_menu.popup(Rect2i(mouse_rel_pos.x, mouse_rel_pos.y, context_menu.size.x, context_menu.size.y))


func _on_selected(selected: bool):
	if initialised:
		var shader: ShaderMaterial = _sprite.material
		shader.set_shader_parameter("selected", selected)

func _on_dragging(start_pos, current_pos):
	for enter in enter_nodes:
		enter.global_position = global_position
		enter.parent_object.waypoints.waypoint_lines.queue_redraw()

	for exit in exit_nodes:
		exit.global_position = global_position
		exit.parent_object.waypoints.waypoint_lines.queue_redraw()

	parent_object.waypoints.waypoint_lines.queue_redraw()


## Handles when mouse has stopped being held
func _on_hold_stop(start_pos, end_pos):
	if start_pos != end_pos:
		var undo_action = UndoRedoAction.new()
		var agent_id = parent_object.agent_id
		var waypoint_index = parent_object.waypoints.get_waypoint_index(self)

		undo_action.action_name = "Move Waypoint"

		#######
		# DO
		#######

		# Get the agent and waypoint references
		var agent_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [agent_id])
		var waypoint_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(agent, index):
			return agent.waypoints.waypoints[index]
			, [agent_ref, waypoint_index], agent_ref)

		# Set the waypoint's global position
		undo_action.action_property_ref(UndoRedoAction.DoType.Do, waypoint_ref, "global_position", global_position)

		undo_action.action_method(UndoRedoAction.DoType.Do, func(waypoint):
			for enter in waypoint.enter_nodes:
				enter.global_position = waypoint.global_position
				enter.parent_object.waypoints.waypoint_lines.queue_redraw()

			for exit in waypoint.exit_nodes:
				exit.global_position = waypoint.global_position
				exit.parent_object.waypoints.waypoint_lines.queue_redraw()
			, [waypoint_ref], waypoint_ref)

		# Queue redraw of waypoint lines
		undo_action.action_method(UndoRedoAction.DoType.Do, func(agent):
			agent.waypoints.waypoint_lines.queue_redraw()
			, [agent_ref], agent_ref)

		#######
		# UNDO
		#######

		# Undo the waypoint's global position
		undo_action.action_property_ref(UndoRedoAction.DoType.Undo, waypoint_ref, "global_position", start_pos)

		undo_action.action_method(UndoRedoAction.DoType.Undo, func(waypoint):
			for enter in waypoint.enter_nodes:
				enter.global_position = start_pos
				enter.parent_object.waypoints.waypoint_lines.queue_redraw()

			for exit in waypoint.exit_nodes:
				exit.global_position = start_pos
				exit.parent_object.waypoints.waypoint_lines.queue_redraw()
			, [waypoint_ref], waypoint_ref)

		# Queue redraw of waypoint lines
		undo_action.action_method(UndoRedoAction.DoType.Undo, func(agent):
			agent.waypoints.waypoint_lines.queue_redraw()
			, [agent_ref], agent_ref)

		# Manually add the agent and waypoint to the store
		undo_action.manual_add_item_to_store(parent_object, agent_ref)
		undo_action.manual_add_item_to_store(self, waypoint_ref)

		UndoSystem.add_action(undo_action, false)



func _disable(new_disable: bool):
	if initialised:
		_collision_shape.disabled = new_disable
		_sprite.visible = not new_disable

	disabled = new_disable


func _linked_ready_changed(value: bool):
	linked_ready = value
	linked_ready_changed.emit(value)


func _clickable(new_value:bool):
	clickable = new_value
	$DragableObject.clickable = new_value

func ui_scale_update(new_scale: float, old_scale: float):
	ui_scale = new_scale
	global_position = (global_position / old_scale) * new_scale

func add_event(event_info: SimulationEventExporterManual):
	_events.append(event_info)

func remove_event(event_info: SimulationEventExporterManual, propagate: bool):
	if _events.has(event_info):
		_events.erase(event_info)

	if propagate:
		# TODO: Call primary event emitter to remove event from all other wps
		pass
