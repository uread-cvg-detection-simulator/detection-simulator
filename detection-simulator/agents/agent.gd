class_name Agent
extends CharacterBody2D

@onready var camera: Camera2D = null : set = _set_camera ## The camera to use for the mouse position
@export var colour: Color = Color.WHITE : set = _set_sprite_colour ## The colour of the target
@export var clickable: bool = true

var agent_id: int = 0 : set = _set_agent_id ## The agent target id
signal agent_id_set(old_id, new_id) ## Signals whenever the agent id is set

enum AgentType {
	Circle,
	SquareTarget,
	PersonTarget,
	Invisible,
}

@onready var _type_map = { AgentType.Circle : $circle_target,
						   AgentType.SquareTarget : $square_target,
						   AgentType.PersonTarget : $person_target }

var _type_string = {
	AgentType.Circle : "Circle",
	AgentType.SquareTarget: "Square",
	AgentType.PersonTarget: "Person",
	AgentType.Invisible: "Invisible"
}

@export var type_default_colours = { AgentType.Circle : Color.GREEN,
									 AgentType.SquareTarget : Color.WHITE,
									 AgentType.PersonTarget : Color.GREEN }

@onready var _current_agent: AgentTarget = null
var agent_type: AgentType = AgentType.PersonTarget : set = _set_agent_type
var collision_shape = null

@onready var context_menu: PopupMenu = $ContextMenu
@onready var waypoints = $waypoints

enum ContextMenuIDs {
	DELETE,
	PROPERTIES,
}

#signal deleted(id) ## Signals when the agent has been manually deletec

var initialised: bool = false ## Specifies whether the module is initialised
var disabled: bool = false : set = _set_disabled ## Disables everything internally

var playing_next_move_time: float = 0.0 ## The time at which the next move will be played
var playing_waypoint: Waypoint = null ## The waypoint that the agent is currently moving towards
var playing_target: Vector2 = Vector2.INF ## The target position of the next move
var playing_speed: float = 1.0 ## The speed at which the agent will move
var playing_finished: bool = false ## Specifies whether the agent has finished playing
var playing = false

var exporting_path = null
var exporting_file_access: FileAccess = null

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
		"x": global_position.x / 64.0,
		"y": - global_position.y / 64.0,
	}

	return data


func _update_target_information(waypoint: Waypoint):
	var current_time = PlayTimer.current_time
	var old_waypoint = playing_waypoint if playing_waypoint else waypoints.starting_node

	if old_waypoint.param_start_time:
		# If waypoint has a start time parameter, set the playing_next_move_time to that
		playing_next_move_time = old_waypoint.param_start_time
	elif old_waypoint.param_wait_time:
		# Calculate the time at which the next move will be played
		playing_next_move_time = current_time + old_waypoint.param_wait_time

	# Set the speed from the current waypoint
	playing_speed = old_waypoint.param_speed_mps * 64.0 # TODO: get this from grid-lines

	# Set the target position
	playing_target = waypoint.global_position

	# Update the current waypoint
	playing_waypoint = waypoint


## Start pathing through the waypoints
func _start_playing():
	if not disabled:
		_update_target_information(waypoints.starting_node)
		playing = true
		clickable = false
		waypoints.clickable = false

		#if PlayTimer.exporting and exporting_path != null:
		#	exporting_file_access = FileAccess.open(exporting_path, FileAccess.WRITE)

## Resets agent's playing parameters and position
func _stop_playing():
	playing_next_move_time = 0.0
	playing_target = Vector2.INF
	playing_speed = 1.0
	playing_finished = false
	playing = false
	clickable = true

	global_position = waypoints.starting_node.global_position
	waypoints.clickable = true

	if exporting_file_access != null:
		exporting_file_access.close()
		exporting_file_access = null

func _physics_process(delta):
	if not disabled:
		if playing and playing_next_move_time < PlayTimer.current_time:
			# Update position
			# TODO: use navigation system
			global_position = global_position.move_toward(playing_target, playing_speed * delta)

			# If reached target, update target information with next waypoint if there is one
			if global_position == playing_target:
				if playing_waypoint.pt_next:
					_update_target_information(playing_waypoint.pt_next)
				else:
					playing_finished = true
					playing = false

			if PlayTimer.exporting and exporting_file_access:
				pass

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

			undo_action.action_name = "Move Agent %d" % agent_id


			var ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [agent_id])
			undo_action.action_property_ref(UndoRedoAction.DoType.Do, ref, "global_position", global_position)
			undo_action.action_property_ref(UndoRedoAction.DoType.Undo, ref, "global_position", _moving_start_pos)

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


		_moving_start_pos = null

func _on_mouse(_mouse, event):
	if event.is_action_pressed("mouse_menu") and camera != null and clickable:
		var mouse_pos = MousePosition.mouse_global_position
		var mouse_rel_pos = MousePosition.mouse_relative_position

		# Popup the window
		context_menu.popup(Rect2i(mouse_rel_pos.x, mouse_rel_pos.y, context_menu.size.x, context_menu.size.y))

		print_debug("Right click at (%.2f, %.2f)" % [float(mouse_pos.x) / 64, - float(mouse_pos.y) / 64])

func _unhandled_input(event):
	if event is InputEventMouseMotion and _moving and clickable:
		self.global_position = get_global_mouse_position()

		waypoints.starting_node.global_position = self.global_position
		waypoints.waypoint_lines.queue_redraw()

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
			_current_agent._selection_area.disconnect("mouse_hold_start", self._on_hold)
			_current_agent._selection_area.disconnect("mouse_hold_end", self._on_hold_stop)
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
			_current_agent._selection_area.connect("mouse_hold_start", self._on_hold)
			_current_agent._selection_area.connect("mouse_hold_end", self._on_hold_stop)
			_current_agent._selection_area.connect("mouse_click", self._on_mouse)
			_current_agent._selection_area.parent_object = self

			collision_shape = _current_agent._collision_shape
			_current_agent.remove_child(collision_shape)
			add_child(collision_shape)

			_set_sprite_colour(type_default_colours[new_agent_type])
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

			undo_action.action_method(UndoRedoAction.DoType.Do, GroupHelpers.remove_node_from_group, [ref, "agent"], ref)
			undo_action.action_property_ref(UndoRedoAction.DoType.Do, ref, "disabled", true)

			undo_action.action_property_ref(UndoRedoAction.DoType.Undo, ref, "disabled", false)
			undo_action.action_method(UndoRedoAction.DoType.Undo, GroupHelpers.add_node_to_group, [ref, "agent"], ref)

			undo_action.action_object_call_ref(UndoRedoAction.DoType.OnRemoval, ref, "_free_if_not_in_group")

			UndoSystem.add_action(undo_action)
		ContextMenuIDs.PROPERTIES:
			# HACK: select the current agent, and the properties window should pop up
			if _current_agent != null:
				_current_agent._selection_area.selected = true

func reset_position():
	global_position = waypoints.starting_node.global_position
