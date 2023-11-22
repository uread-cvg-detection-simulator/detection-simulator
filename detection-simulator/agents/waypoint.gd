class_name Waypoint
extends Node2D

@onready var pt_next: Waypoint = null
@onready var pt_previous: Waypoint = null

@onready var _sprite = $Sprite2D
@onready var _selection_area = $SelectionArea2D
@onready var _collision_shape = $SelectionArea2D/CollisionPolygon2D

@export var disabled: bool = false : set = _disable
@export var clickable: bool = true

@onready var context_menu = $ContextMenu

enum ContextMenuIDs {
	DELETE,
	PROPERTIES,
	LINK_WAYPOINT,
	ENTER_VEHICLE,
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

var parent_object: Agent = null

var initialised = false
@export var camera: Camera2D = null

var attempting_link = false
var linked_nodes: Array[Waypoint] = []
var linked_ready: bool = false

var load_linked_nodes: Array = []

# Called when the node enters the scene tree for the first time.
func _ready():
	initialised = true

	if disabled:
		_disable(disabled)

	# Connect to the selection area's mouse events
	_selection_area.connect("selection_toggled", self._on_selected)
	_selection_area.connect("mouse_hold_start", self._on_hold)
	_selection_area.connect("mouse_hold_end", self._on_hold_stop)
	_selection_area.connect("mouse_click", self._on_mouse)


func _prepare_menu():
	context_menu.clear()

	context_menu.add_item("Delete Waypoint", ContextMenuIDs.DELETE)
	context_menu.add_item("Properties", ContextMenuIDs.PROPERTIES)

	context_menu.add_separator()
	context_menu.add_item("Start Linking...", ContextMenuIDs.LINK_WAYPOINT)

	# If waypoint of another agent is selected, add "Enter Vehicle" to the menu
	var all_selected_objects = get_tree().get_nodes_in_group("selected")

	if not all_selected_objects.is_empty():
		var selected_object = all_selected_objects[0].parent_object
		var valid_enter_exit = false

		if selected_object is Waypoint:
			if selected_object.parent_object != parent_object and parent_object.is_vehicle:
				valid_enter_exit = true

		if selected_object is Agent:
			if selected_object != parent_object and parent_object.is_vehicle:
				valid_enter_exit = true

		if valid_enter_exit:
			context_menu.add_separator()
			context_menu.add_item("Enter Vehicle", ContextMenuIDs.ENTER_VEHICLE)

	if not context_menu.is_connected("id_pressed", self._context_menu_id_pressed):
		context_menu.connect("id_pressed", self._context_menu_id_pressed)

func get_save_data() -> Dictionary:
	var save_data = {
		"waypoint_version": 2,
		"global_position": {
			"x": global_position.x,
			"y": global_position.y,
		},
		"param_speed_mps": param_speed_mps,
		"param_start_time": param_start_time,
		"param_wait_time": param_wait_time,
		"linked_nodes": [],
	}

	for node in linked_nodes:
		var node_data = {
			"agent_id": node.parent_object.agent_id,
			"waypoint_index": node.parent_object.waypoints.get_waypoint_index(node),
		}

		save_data["linked_nodes"].append(node_data)

	return save_data

func load_save_data(data: Dictionary):
	if data.has("waypoint_version"):
		if data["waypoint_version"] <= 2:
			global_position = Vector2(data["global_position"]["x"], data["global_position"]["y"])
			param_speed_mps = data["param_speed_mps"] if data["param_speed_mps"] != null else null
			param_start_time = data["param_start_time"] if data["param_start_time"] != null else null
			param_wait_time = data["param_wait_time"] if data["param_wait_time"] != null else null

			if data["waypoint_version"] >= 2:
				if not data["linked_nodes"].is_empty():
					load_linked_nodes = data["linked_nodes"]
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
			var waypoint = agent.waypoints.get_waypoint(waypoint_index)

			if waypoint not in linked_nodes:
				linked_nodes.append(waypoint)
				waypoint.linked_nodes.append(self)

		parent_object.waypoints.waypoint_lines.queue_redraw()

		load_linked_nodes.clear()

func _context_menu_id_pressed(id: ContextMenuIDs):
	match id:
		ContextMenuIDs.DELETE:
			parent_object.waypoints.delete_waypoint(self)
		ContextMenuIDs.PROPERTIES:
			# HACK: Select the waypoint, then the properties dialog will be opened
			_selection_area.selected = true
		ContextMenuIDs.LINK_WAYPOINT:
			# Start selection for another waypoint
			GroupHelpers.connect("node_grouped", self._on_link_grouped)
			print_debug("Start linking waypoint")
			attempting_link = true
		ContextMenuIDs.ENTER_VEHICLE:
			_on_enter_vehicle()

func _on_enter_vehicle():
	# If waypoint of another agent is selected, add "Enter Vehicle" to the menu
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
		
		waypoint_handler.insert_after(curr_wp, global_position, WaypointType.ENTER)

func _on_link_grouped(group: String, node: Node):

	if group == "selected":

		var waypoint_node = null;

		if node.parent_object is Waypoint:
			waypoint_node = node.parent_object
		elif node.parent_object is Agent:
			waypoint_node = node.parent_object.waypoints.starting_node
		else:
			print_debug("Node is not a waypoint or agent")
			return

		# Check if waypoint is already linked
		if waypoint_node in linked_nodes:
			print_debug("Waypoint already linked")
			return

		# Check if waypoint is from the same agent
		if waypoint_node.parent_object == parent_object:
			print_debug("Waypoint from same agent")
			return

		#linked_nodes.append(node)
		#node.linked_nodes.append(self)

		GroupHelpers.disconnect("node_grouped", self._on_link_grouped)
		attempting_link = false

		link_waypoint(waypoint_node)


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

var _moving = false ## defines whether the agent is being dragged
var _moving_start_pos = null

## Handles when mouse is being held
func _on_hold():
	if clickable:
		_moving = true
		_moving_start_pos = global_position

## Handles when mouse has stopped being held
func _on_hold_stop():
	_moving = false

	if _moving_start_pos:
		if _moving_start_pos != global_position:
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

			# Queue redraw of waypoint lines
			undo_action.action_method(UndoRedoAction.DoType.Do, func(agent):
				agent.waypoints.waypoint_lines.queue_redraw()
				, [agent_ref], agent_ref)

			#######
			# UNDO
			#######

			# Undo the waypoint's global position
			undo_action.action_property_ref(UndoRedoAction.DoType.Undo, waypoint_ref, "global_position", _moving_start_pos)


			# Queue redraw of waypoint lines
			undo_action.action_method(UndoRedoAction.DoType.Undo, func(agent):
				agent.waypoints.waypoint_lines.queue_redraw()
				, [agent_ref], agent_ref)

			# Manually add the agent and waypoint to the store
			undo_action.manual_add_item_to_store(parent_object, agent_ref)
			undo_action.manual_add_item_to_store(self, waypoint_ref)

			UndoSystem.add_action(undo_action, false)


		_moving_start_pos = null


func _unhandled_input(event):
	if event is InputEventMouseMotion and _moving and clickable:
		self.global_position = get_global_mouse_position()

		if parent_object:
			parent_object.waypoints.waypoint_lines.queue_redraw()

	# Stop linking if ui_cancel is pressed
	if event.is_action_pressed("ui_cancel") and attempting_link:
		GroupHelpers.disconnect("node_grouped", self._on_link_grouped)
		attempting_link = false
		print_debug("Stop linking waypoint")


func _disable(new_disable: bool):
	if initialised:
		_collision_shape.disabled = new_disable
		_sprite.visible = not new_disable

	disabled = new_disable
