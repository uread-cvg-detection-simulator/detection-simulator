class_name Agent
extends CharacterBody2D

@onready var camera: Camera2D = null : set = _set_camera ## The camera to use for the mouse position
@export var colour: Color = Color.WHITE : set = _set_sprite_colour ## The colour of the target
@export var clickable: bool = true : set = _set_clickable

var agent_id: int = 0 : set = _set_agent_id ## The agent target id
signal agent_id_set(old_id, new_id) ## Signals whenever the agent id is set

enum AgentType {
	Circle,
	SquareTarget,
	PersonTarget,
	BoatTarget,
	CarTarget,
	Invisible,
}

@onready var _type_map = { AgentType.Circle : $circle_target,
						   AgentType.SquareTarget : $square_target,
						   AgentType.PersonTarget : $person_target,
						   AgentType.BoatTarget : $boat_target,
						   AgentType.CarTarget: $car_target }

var _type_string = {
	AgentType.Circle : "Circle",
	AgentType.SquareTarget: "Square",
	AgentType.PersonTarget: "Person",
	AgentType.BoatTarget: "Vessel",
	AgentType.CarTarget: "Vehicle",
	AgentType.Invisible: "Invisible"
}

@export var type_is_vehicle = { AgentType.Circle : false,
								AgentType.SquareTarget: false,
								AgentType.PersonTarget: false,
								AgentType.BoatTarget: true,
								AgentType.CarTarget: true}

@export var type_default_colours = { AgentType.Circle : Color.GREEN,
									 AgentType.SquareTarget : Color.WHITE,
									 AgentType.PersonTarget : Color.GREEN,
									 AgentType.BoatTarget: Color.GREEN,
									 AgentType.CarTarget: Color.GREEN }

@export_group("Scene References")
@export var state_machine: StateMachine = null
@export var dragable_object: DragableObjectComponent = null


@onready var _current_agent: AgentTarget = null
var agent_type: AgentType = AgentType.PersonTarget : set = _set_agent_type
var is_vehicle: bool = false
var collision_shape = null
var ui_scale = 1.0
@onready var context_menu: PopupMenu = $ContextMenu
@onready var waypoints: AgentWaypointHandler = $waypoints

enum ContextMenuIDs {
	DELETE,
	PROPERTIES,
}

#signal deleted(id) ## Signals when the agent has been manually deletec

var initialised: bool = false ## Specifies whether the module is initialised
var disabled: bool = false : set = _set_disabled ## Disables everything internally
var playing_finished: bool = false ## Specifies whether the agent has finished playing

var exporting_path = null
var exporting_file_access: FileAccess = null

var base_editor: ScenarioEditor = null : set = _set_editor

# Called when the node enters the scene tree for the first time.
func _ready():
	initialised = true

	_set_camera(camera)
	_set_agent_type(agent_type)

	# Create menu items and connect
	context_menu.add_item("Delete Agent", ContextMenuIDs.DELETE)
	context_menu.add_item("Properties", ContextMenuIDs.PROPERTIES)
	context_menu.connect("id_pressed", self._context_menu)

	PlayTimer.connect("start_playing", self._start_playing)
	PlayTimer.connect("stop_playing", self._stop_playing)

func get_save_data() -> Dictionary:
	var data = {
		"agent_id" : agent_id,
		"agent_type" : agent_type,
		"agent_version": 1,
		"colour" : {
			"r" : colour.r,
			"g" : colour.g,
			"b" : colour.b,
			"a" : colour.a,
		},
		"waypoints" : waypoints.get_save_data(),
	}

	return data

func load_save_data(data: Dictionary):
	if data.has("agent_version"):
		if data["agent_version"] == 1:
			agent_id = data["agent_id"]
			agent_type = data["agent_type"]
			colour = Color(data["colour"]["r"], data["colour"]["g"], data["colour"]["b"], data["colour"]["a"])
			waypoints.load_save_data(data["waypoints"])

			global_position = waypoints.starting_node.global_position
		else:
			print_debug("Agent version %d not supported" % [data["agent_version"]])
	else:
		print_debug("Unable to verify agent information: No version number")

func play_export() -> Dictionary:
	var data = {
		"id" : agent_id,
		"type" : _type_string[agent_type],
		"x": ((global_position.x / 64.0) / PlayTimer.ui_scale) * PlayTimer.export_scale,
		"y": ((-global_position.y / 64.0) / PlayTimer.ui_scale) * PlayTimer.export_scale,
		"visible": visible,
	}

	return data


## Start pathing through the waypoints
func _start_playing():
	if not disabled:

		state_machine.transition_to("follow_waypoints")

		#if PlayTimer.exporting and exporting_path != null:
		#	exporting_file_access = FileAccess.open(exporting_path, FileAccess.WRITE)

## Resets agent's playing parameters and position
func _stop_playing():
	playing_finished = false

	if exporting_file_access != null:
		exporting_file_access.close()
		exporting_file_access = null

	state_machine.transition_to("editor_state")



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _set_camera(new_camera: Camera2D):
	camera = new_camera

	if initialised:
		waypoints.camera = camera

## Sets the colour of the target sprite (replaces the white with whichever colour is passed in the argument)
func _set_sprite_colour(new_colour: Color):
	colour = new_colour

	if initialised and _current_agent != null:
		_current_agent.material.set_shader_parameter("new_colour", Vector4(new_colour.r, new_colour.g, new_colour.b, new_colour.a))

## Handles when agent is selected
func _on_selected(selected: bool):
	if initialised and _current_agent != null:
		if selected:
			print_debug("Agent %d selected" % [agent_id])
		else:
			print_debug("Agent %d deselected" % [agent_id])

		_current_agent.material.set_shader_parameter("selected", selected)


## Handles when mouse has stopped being held
func _on_hold_stop(start_pos, end_pos):
	if start_pos != end_pos:
		_move(start_pos, end_pos)


func _move(last_position: Vector2, new_position: Vector2):

	if new_position != global_position:
		global_position = new_position

	waypoints.starting_node.global_position = self.global_position
	waypoints.waypoint_lines.queue_redraw()

	var undo_action = UndoRedoAction.new()
	undo_action.action_name = "Move Agent %d" % agent_id

	var ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [agent_id])
	undo_action.action_property_ref(UndoRedoAction.DoType.Do, ref, "global_position", new_position / PlayTimer.ui_scale)
	undo_action.action_method(UndoRedoAction.DoType.Do, func(agent):
		agent.global_position = agent.global_position * PlayTimer.ui_scale
		agent.waypoints.starting_node.global_position = agent.global_position
	, [ref], ref)

	undo_action.action_property_ref(UndoRedoAction.DoType.Undo, ref, "global_position", last_position / PlayTimer.ui_scale)
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(agent):
		agent.global_position = agent.global_position * PlayTimer.ui_scale
		agent.waypoints.starting_node.global_position = agent.global_position
	, [ref], ref)


	# Queue redraw of waypoint lines
	undo_action.action_method(UndoRedoAction.DoType.Do, func(agent):
		agent.waypoints.waypoint_lines.queue_redraw()
		, [ref], ref)

	# Queue redraw of waypoint lines
	undo_action.action_method(UndoRedoAction.DoType.Undo, func(agent):
		agent.waypoints.waypoint_lines.queue_redraw()
		, [ref], ref)

	undo_action.manual_add_item_to_store(self, ref)

	UndoSystem.add_action(undo_action, false)



func _on_mouse(_mouse, event):
	if event.is_action_pressed("mouse_menu") and camera != null and clickable:
		var mouse_pos = MousePosition.mouse_global_position
		var mouse_rel_pos = MousePosition.mouse_relative_position

		# Popup the window
		context_menu.popup(Rect2i(mouse_rel_pos.x, mouse_rel_pos.y, context_menu.size.x, context_menu.size.y))

		print_debug("Right click at (%.2f, %.2f)" % [float(mouse_pos.x) / 64, - float(mouse_pos.y) / 64])

## Sets the agent id, and calls the relevant signal
func _set_agent_id(new_agent_id):
	emit_signal("agent_id_set", agent_id, new_agent_id)
	agent_id = new_agent_id

func _set_agent_type(new_agent_type: AgentType):
	if initialised:
		# Disable previous
		if _current_agent != null:
			_current_agent.disabled = true
			_current_agent._selection_area.disconnect("selection_toggled", self._on_selected)
			_current_agent._selection_area.disconnect("mouse_hold_start", self.dragable_object._on_hold)
			_current_agent._selection_area.disconnect("mouse_hold_end", self.dragable_object._on_hold_stop)
			_current_agent._selection_area.disconnect("mouse_click", self._on_mouse)
			_current_agent._selection_area.parent_object = null

			remove_child(collision_shape)
			_current_agent.add_child(collision_shape)
			collision_shape = null

		# Enable new
		if new_agent_type != AgentType.Invisible:
			_current_agent = _type_map[new_agent_type]
			_current_agent.disabled = false
			_current_agent._selection_area.connect("selection_toggled", self._on_selected)
			_current_agent._selection_area.connect("mouse_hold_start", self.dragable_object._on_hold)
			_current_agent._selection_area.connect("mouse_hold_end", self.dragable_object._on_hold_stop)
			_current_agent._selection_area.connect("mouse_click", self._on_mouse)
			_current_agent._selection_area.parent_object = self

			collision_shape = _current_agent._collision_shape
			_current_agent.remove_child(collision_shape)
			add_child(collision_shape)

			_set_sprite_colour(type_default_colours[new_agent_type])

			is_vehicle = type_is_vehicle[new_agent_type]
		else:
			_current_agent = null

	agent_type = new_agent_type

func _set_disabled(new_value: bool):
	if _current_agent != null:
		_current_agent.disabled = new_value

	disabled = new_value
	visible = not new_value
	waypoints.disabled = new_value

func _free_if_not_in_group():
	if not is_in_group("agent"):
		queue_free()

func _context_menu(id: ContextMenuIDs):
	match id:
		ContextMenuIDs.DELETE:
			print_debug("Deleted Agent %d" % [agent_id])
			_current_agent._selection_area.selected = false

			var undo_action = UndoRedoAction.new()
			undo_action.action_name = "Deleted Agent %d" % [agent_id]

			var ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [agent_id])
			undo_action.manual_add_item_to_store(self, ref)

			# Store event data if there are events to manage
			var event_data_ref = null
			if base_editor != null and base_editor.event_emittor != null:
				var event_data = base_editor.event_emittor.get_agent_events(agent_id)
				if not event_data["events_to_remove"].is_empty() or not event_data["events_to_modify"].is_empty():
					event_data_ref = undo_action.manual_add_item_to_store(event_data)

			# Store linked node data if there are linked nodes to manage
			var linked_data_ref = null
			if base_editor != null:
				var linked_data = base_editor.get_agent_linked_nodes(agent_id)
				if not linked_data["waypoints_to_unlink"].is_empty() or not linked_data["other_waypoints_to_unlink"].is_empty():
					linked_data_ref = undo_action.manual_add_item_to_store(linked_data)

			######
			# DO Actions (in order)
			######

			# 1. Remove agent from events BEFORE disabling the agent
			if event_data_ref != null:
				undo_action.action_object_call(UndoRedoAction.DoType.Do, base_editor.event_emittor, "remove_agent_from_events", [agent_id, event_data_ref], [event_data_ref])

			# 2. Remove agent from linked nodes BEFORE disabling the agent
			if linked_data_ref != null:
				undo_action.action_object_call(UndoRedoAction.DoType.Do, base_editor, "remove_agent_from_linked_nodes", [agent_id, linked_data_ref], [linked_data_ref])

			# 3. Remove agent from group and disable it
			undo_action.action_method(UndoRedoAction.DoType.Do, GroupHelpers.remove_node_from_group, [ref, "agent"], ref)
			undo_action.action_property_ref(UndoRedoAction.DoType.Do, ref, "disabled", true)

			######
			# UNDO Actions (in reverse order)
			######

			# 1. Re-enable agent and add back to group FIRST
			undo_action.action_property_ref(UndoRedoAction.DoType.Undo, ref, "disabled", false)
			undo_action.action_method(UndoRedoAction.DoType.Undo, GroupHelpers.add_node_to_group, [ref, "agent"], ref)

			# 2. Restore events AFTER agent is restored
			if event_data_ref != null:
				undo_action.action_object_call(UndoRedoAction.DoType.Undo, base_editor.event_emittor, "restore_agent_to_events", [agent_id, event_data_ref], [event_data_ref])

			# 3. Restore linked nodes AFTER agent is restored
			if linked_data_ref != null:
				undo_action.action_object_call(UndoRedoAction.DoType.Undo, base_editor, "restore_agent_to_linked_nodes", [agent_id, linked_data_ref], [linked_data_ref])

			# OnRemoval Actions - cleanup when undo action is discarded
			undo_action.action_object_call_ref(UndoRedoAction.DoType.OnRemoval, ref, "_free_if_not_in_group")

			# Clean up stored events when undo action is discarded
			if event_data_ref != null:
				undo_action.action_object_call(UndoRedoAction.DoType.OnRemoval, base_editor.event_emittor, "cleanup_stored_events_for_agent", [agent_id, event_data_ref], [event_data_ref])

			UndoSystem.add_action(undo_action)
		ContextMenuIDs.PROPERTIES:
			# HACK: select the current agent, and the properties window should pop up
			if _current_agent != null:
				_current_agent._selection_area.selected = true

func reset_position():
	global_position = waypoints.starting_node.global_position

func _set_clickable(new_value: bool):
	clickable = new_value
	dragable_object.clickable = new_value

func ui_scale_update(new_scale: float, old_scale: float):
	ui_scale = new_scale
	global_position = (global_position / old_scale) * new_scale
	waypoints.starting_node.global_position = (waypoints.starting_node.global_position / old_scale) * new_scale
	waypoints.waypoint_lines.queue_redraw()

func _set_editor(editor: ScenarioEditor):
	base_editor = editor
	waypoints.base_editor = editor
