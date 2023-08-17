extends Node2D

@onready var _rightclick_empty: PopupMenu = $empty_right_click_menu
@onready var _agent_base: PackedScene = load("res://agents/agent.tscn")
@onready var _waypoint_base: PackedScene = load("res://agents/waypoint.tscn")
@onready var _agent_root = $agents
@onready var _play_button = $CanvasLayer/PlayBar/HBoxContainer/Button
@onready var _status_label = $CanvasLayer/PlayBar/HBoxContainer/StatusInfo

var _agent_list: Array[Agent]

var _last_id = 0

var _scrolling = false ## Set when drag-scrolling
var _right_click_position = null ## Set to ensure popup menus act on correct mouse position

enum empty_menu_enum {
	SPAWN_AGENT,
	RETURN_TO_CENTRE,
	CLEAR_UNDO_HISTORY,
	CREATE_WAYPOINT,
}

# Called when the node enters the scene tree for the first time.
func _ready():
	_prepare_menu()

func _prepare_menu():
	_rightclick_empty.clear()

	var selected_nodes = get_tree().get_nodes_in_group("selected")

	if len(selected_nodes) == 1:
		if selected_nodes[0].parent_object is Agent or selected_nodes[0].parent_object is Waypoint:
			_rightclick_empty.add_item("Create Waypoint", empty_menu_enum.CREATE_WAYPOINT)
			_rightclick_empty.add_separator()

	_rightclick_empty.add_item("Spawn New Agent", empty_menu_enum.SPAWN_AGENT)
	_rightclick_empty.add_separator()
	_rightclick_empty.add_item("Centre Grid", empty_menu_enum.RETURN_TO_CENTRE)
	_rightclick_empty.add_item("Clear Undo History", empty_menu_enum.CLEAR_UNDO_HISTORY)

	if not _rightclick_empty.is_connected("id_pressed", self._on_empty_menu_press):
		_rightclick_empty.connect("id_pressed", self._on_empty_menu_press)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if PlayTimer.play:
		var agents: Array = get_tree().get_nodes_in_group("agent")
		var finished_agents = 0

		for agent in agents:
			if agent.playing_finished:
				finished_agents += 1

		var new_status_label_text = "%d agent(s) moving - %d finished" % [len(agents) - finished_agents, finished_agents]

		_status_label.text = new_status_label_text


func _unhandled_input(event):

	if not PlayTimer.play:
		# Handle scrolling and empty context menu if no object is hovered
		# over by the mouse
		if get_tree().get_nodes_in_group("mouse_hovered").is_empty():
			# Start up the scrolling
			if event.is_action_pressed("mouse_selected"):
				if not _scrolling:
					_scrolling = true

			# Launch the empty menu
			if event.is_action_pressed("mouse_menu"):
				# Handle Menu
				_right_click(event)

		# Handle Undo System
		if event.is_action_pressed("ui_undo"):
			if UndoSystem.has_undo():
				UndoSystem.undo()

		if event.is_action_pressed("ui_redo"):
			if UndoSystem.has_redo():
				UndoSystem.redo()
	else:
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

		$Camera2D.position -= tmp_event.relative


func _right_click(event: InputEventMouseButton):
	# Calculate the mouse relative position to place the
	# right click menu at the correct location
	var mouse_pos = get_global_mouse_position()
	var mouse_rel_pos = mouse_pos - $Camera2D.global_position
	var window_size = get_window().size / 2

	_prepare_menu()

	# Popup the window
	_rightclick_empty.popup(Rect2i(mouse_rel_pos.x + window_size.x, mouse_rel_pos.y + window_size.y, _rightclick_empty.size.x, _rightclick_empty.size.y))
	_right_click_position = mouse_pos

	print_debug("Right click at (%.2f, %.2f)" % [float(mouse_pos.x) / 64, - float(mouse_pos.y) / 64])

func _on_empty_menu_press(id: int):
	match id:
		empty_menu_enum.SPAWN_AGENT:
			spawn_agent(_right_click_position)
		empty_menu_enum.RETURN_TO_CENTRE:
			$Camera2D.set_global_position(Vector2(0, 0))
		empty_menu_enum.CLEAR_UNDO_HISTORY:
			UndoSystem.clear_history()
		empty_menu_enum.CREATE_WAYPOINT:
			var selected_nodes = get_tree().get_nodes_in_group("selected")

			if len(selected_nodes) == 1:
				var selected_node = selected_nodes[0].parent_object
				var new_waypoint = null

				if selected_node is Agent:
					new_waypoint = selected_node.waypoints.insert_after(selected_node.waypoints.starting_node, _right_click_position)
				elif selected_node is Waypoint:
					new_waypoint = selected_node.parent_object.waypoints.insert_after(selected_node, _right_click_position)

				new_waypoint._selection_area.selected = true
			else:
				print_debug("Inconsistent Edit State")


## Spawn a new agent at the provided position
func spawn_agent(position: Vector2):
	var undo_action = UndoRedoAction.new()
	undo_action.action_name = "Spawn Agent %d" % [_last_id + 1]

	############
	# DO ACTIONS
	############

	# Create the new agent at the provided location
	var newinstance_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, _agent_base.instantiate)
	var duplicate_ref = newinstance_ref

	# Set position and agent id
	undo_action.action_property_ref(UndoRedoAction.DoType.Do, duplicate_ref, "global_position", position)
	undo_action.action_property_ref(UndoRedoAction.DoType.Do, duplicate_ref, "agent_id", _last_id + 1)
	undo_action.action_property(UndoRedoAction.DoType.Do, self, "_last_id", _last_id + 1)

	# Add to scene tree
	undo_action.action_method(UndoRedoAction.DoType.Do, _agent_root.add_child, [duplicate_ref], duplicate_ref)
	undo_action.action_method(UndoRedoAction.DoType.Do, GroupHelpers.add_node_to_group, [duplicate_ref, "agent"], duplicate_ref)

	# Set camera
	undo_action.action_property_ref(UndoRedoAction.DoType.Do, duplicate_ref, "camera", $Camera2D)

	##############
	# UNDO ACTIONS
	##############

	# Remove from scene tree
	undo_action.action_method(UndoRedoAction.DoType.Undo, _agent_root.remove_child, [duplicate_ref], duplicate_ref)

	# Reset last id
	undo_action.action_property(UndoRedoAction.DoType.Undo, self, "_last_id", _last_id)

	# Queue Deletion
	undo_action.action_object_call_ref(UndoRedoAction.DoType.Undo, duplicate_ref, "queue_free")

	# Remove Reference
	undo_action.action_remove_item(UndoRedoAction.DoType.Undo, duplicate_ref)

	########
	# COMMIT
	########

	UndoSystem.add_action(undo_action)

	TreeFuncs.get_agent_with_id(_last_id)._current_agent._selection_area.selected = true

## Start playing
func _on_play_button_pressed():
	PlayTimer.play = not PlayTimer.play

	if PlayTimer.play:
		_play_button.text = "Stop"
	else:
		_play_button.text = "Play"
		_status_label.text = "Nothing to report"
