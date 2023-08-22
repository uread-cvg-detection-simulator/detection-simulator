extends Node2D

@export_group("Entity Groups")
@export var _agent_root: Node2D = null
@export var _sensor_root: Node2D = null

@export_group("GUI")
@export var _gui : CanvasLayer = null
@export var _rightclick_empty: PopupMenu = null

@export_subgroup("Labels")
@export var _status_label : Label = null

@export_subgroup("Buttons")
@export var _play_button : Button = null
@export var _save_button : Button = null
@export var _load_button : Button = null
@export var _autosave_check : CheckButton = null

@export_group("Scenes")
@export var _agent_base: PackedScene = null
@export var _waypoint_base: PackedScene = null
@export var _sensor_base: PackedScene = null

@export_group("File Handling")
@export var fd_writer: FileDialog = null
@export var fd_reader: FileDialog = null


var _agent_list: Array[Agent]

var _last_id = 0
var _last_sensor_id = 0

var _scrolling = false ## Set when drag-scrolling
var _right_click_position = null ## Set to ensure popup menus act on correct mouse position

var save_path = null
var _current_save_hash = 0
var _last_save_data: Dictionary = {}
var _data_to_save = false


enum empty_menu_enum {
	SPAWN_AGENT,
	SPAWN_SENSOR,
	RETURN_TO_CENTRE,
	RESET_ZOOM,
	CLEAR_UNDO_HISTORY,
	CREATE_WAYPOINT,
}

# Called when the node enters the scene tree for the first time.
func _ready():
	_prepare_menu()

	#fd_reader.current_dir = "~/"
	#fd_writer.current_dir = "~/"
	_save_button.disabled = true
	_autosave_check.disabled = true

func get_save_data() -> Dictionary:
	var save_data = {
		"version": 2,
		"agents": [],
		"sensors": [],
		"last_id": _last_id,
		"last_sensor_id": _last_sensor_id,
	}

	# Load Agents
	var agents = get_tree().get_nodes_in_group("agent")

	for agent in agents:
		save_data["agents"].append(agent.get_save_data())

	# Load Sensors
	var sensors = get_tree().get_nodes_in_group("sensor")

	for sensor in sensors:
		save_data["sensors"].append(sensor.get_save_data())

	return save_data

func load_save_data(data: Dictionary):
	# Clear agents and undo history
	for agent in _agent_root.get_children():
		agent.queue_free()

	UndoSystem.clear_history()

	# Load agents
	if data.has("version"):
		if data["version"] <= 2:

			for agent_data in data["agents"]:
				spawn_agent(Vector2.ZERO)
				var current_agent = TreeFuncs.get_agent_with_id(_last_id)
				current_agent.load_save_data(agent_data)

			if data["version"] >= 2:
				for sensor in data["sensors"]:
					spawn_sensor(Vector2.ZERO)
					var current_sensor = TreeFuncs.get_sensor_with_id(_last_id)
					current_sensor.load_save_data(sensor)

				_last_sensor_id = data["last_sensor_id"]


			_last_id = data["last_id"]
			UndoSystem.clear_history()
		else:
			print("Unknown save data version: %d" % data["version"])

func _prepare_menu():
	_rightclick_empty.clear()

	var selected_nodes = get_tree().get_nodes_in_group("selected")

	if len(selected_nodes) == 1:
		if selected_nodes[0].parent_object is Agent or selected_nodes[0].parent_object is Waypoint:
			_rightclick_empty.add_item("Create Waypoint", empty_menu_enum.CREATE_WAYPOINT)
			_rightclick_empty.add_separator()

	_rightclick_empty.add_item("Spawn New Agent", empty_menu_enum.SPAWN_AGENT)
	_rightclick_empty.add_item("Spawn New Sensor", empty_menu_enum.SPAWN_SENSOR)
	_rightclick_empty.add_separator()
	_rightclick_empty.add_item("Centre Grid", empty_menu_enum.RETURN_TO_CENTRE)
	_rightclick_empty.add_item("Reset Zoom", empty_menu_enum.RESET_ZOOM)
	_rightclick_empty.add_item("Clear Undo History", empty_menu_enum.CLEAR_UNDO_HISTORY)

	if not _rightclick_empty.is_connected("id_pressed", self._on_empty_menu_press):
		_rightclick_empty.connect("id_pressed", self._on_empty_menu_press)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	_gui.resize_spacer()

	if PlayTimer.play:
		var agents: Array = get_tree().get_nodes_in_group("agent")
		var finished_agents = 0

		for agent in agents:
			if agent.playing_finished:
				finished_agents += 1

		var new_status_label_text = "%d agent(s) moving - %d finished" % [len(agents) - finished_agents, finished_agents]

		_status_label.text = new_status_label_text

	# Compare save data
	var current_save_data = get_save_data()
	var button_text = ""

	var check_difference = false

	if _current_save_hash == 0:
		check_difference = true
		_current_save_hash = current_save_data.hash()
	else:
		if _current_save_hash != current_save_data.hash():
			check_difference = true
			_current_save_hash = current_save_data.hash()

	if check_difference:
		_save_button.disabled = true
		if _autosave_check.button_pressed:
			button_text = "Autosave On"

		if current_save_data.hash() != _last_save_data.hash():
			if _autosave_check.button_pressed and save_path != null:
				save_to_file(save_path)
			elif len(current_save_data["agents"]) == 0:
				_data_to_save = false
				button_text = "No Data"
			else:
				_data_to_save = true
				if not PlayTimer.play:
					_save_button.disabled = false
				button_text = "Unsaved Changes"
		else:
			_data_to_save = false
			if not _autosave_check.button_pressed:
				button_text = "Save"

		# If no file path, add (No file set)
		if save_path == null:
			button_text += " (No file set)"
		else:
			# Get the file name (excluding directory)
			# TODO: Does this need to be \ on Windows?
			var file_name = save_path.split("/")[-1]
			button_text += " (%s)" % file_name

		_save_button.text = button_text

	MousePosition.set_mouse_position(get_local_mouse_position(), get_viewport().get_mouse_position())


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

		$Camera2D.position -= tmp_event.relative / $Camera2D.zoom.x
	
	if event.is_action_pressed("zoom_in"):
		var current_zoom = $Camera2D.zoom
		
		current_zoom.x += 0.1
		current_zoom.y += 0.1
		
		$Camera2D.zoom = current_zoom
	if event.is_action_pressed("zoom_out"):
		var current_zoom = $Camera2D.zoom
		
		current_zoom.x -= 0.1
		current_zoom.y -= 0.1
		
		$Camera2D.zoom = current_zoom

func _right_click(event: InputEventMouseButton):
	# Calculate the mouse relative position to place the
	# right click menu at the correct location

	var mouse_pos = MousePosition.mouse_global_position
	var mouse_rel_pos = MousePosition.mouse_relative_position
	var window_size = get_window().size / 2

	_prepare_menu()

	# Popup the window
	_rightclick_empty.popup(Rect2i(mouse_rel_pos.x, mouse_rel_pos.y, _rightclick_empty.size.x, _rightclick_empty.size.y))
	_right_click_position = mouse_pos

	print_debug("Right click at (%.2f, %.2f)" % [float(mouse_pos.x) / 64, - float(mouse_pos.y) / 64])

func _on_empty_menu_press(id: int):
	match id:
		empty_menu_enum.SPAWN_AGENT:
			spawn_agent(_right_click_position)
		empty_menu_enum.SPAWN_SENSOR:
			spawn_sensor(_right_click_position)
		empty_menu_enum.RETURN_TO_CENTRE:
			$Camera2D.set_global_position(Vector2(0, 0))
		empty_menu_enum.RESET_ZOOM:
			$Camera2D.zoom = Vector2(1.0, 1.0)
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

func spawn_sensor(position: Vector2):
	var undo_action = UndoRedoAction.new()
	undo_action.action_name = "Spawn Sensor %d" % [_last_sensor_id + 1]

	############
	# DO ACTIONS
	############

	# Create the new sensor at the provided location
	var newinstance_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, _sensor_base.instantiate)

	# Set position and sensor id
	undo_action.action_property_ref(UndoRedoAction.DoType.Do, newinstance_ref, "global_position", position)
	undo_action.action_property_ref(UndoRedoAction.DoType.Do, newinstance_ref, "sensor_id", _last_sensor_id + 1)
	undo_action.action_property(UndoRedoAction.DoType.Do, self, "_last_sensor_id", _last_sensor_id + 1)

	# Add to scene tree
	undo_action.action_method(UndoRedoAction.DoType.Do, _sensor_root.add_child, [newinstance_ref], newinstance_ref)
	undo_action.action_method(UndoRedoAction.DoType.Do, GroupHelpers.add_node_to_group, [newinstance_ref, "sensor"], newinstance_ref)

	##############
	# UNDO ACTIONS
	##############

	# Remove from scene tree
	undo_action.action_method(UndoRedoAction.DoType.Undo, _sensor_root.remove_child, [newinstance_ref], newinstance_ref)

	# Reset last id
	undo_action.action_property(UndoRedoAction.DoType.Undo, self, "_last_sensor_id", _last_sensor_id)

	# Queue Deletion
	undo_action.action_object_call_ref(UndoRedoAction.DoType.Undo, newinstance_ref, "queue_free")

	# Remove Reference
	undo_action.action_remove_item(UndoRedoAction.DoType.Undo, newinstance_ref)

	########
	# COMMIT
	########

	UndoSystem.add_action(undo_action)

	TreeFuncs.get_sensor_with_id(_last_sensor_id).selection_area.selected = true



## Start playing
func _on_play_button_pressed():
	PlayTimer.play = not PlayTimer.play

	if PlayTimer.play:
		_play_button.text = "Stop"
		_save_button.disabled = true
		_load_button.disabled = true
	else:
		_play_button.text = "Play"
		_status_label.text = "Nothing to report"
		if not _autosave_check.button_pressed:
			_save_button.disabled = false
		_load_button.disabled = false



func _on_load_button_pressed():
	fd_reader.visible = true
	fd_writer.visible = false


func _on_fd_writer_file_selected(path: String):
	save_to_file(path)

	_autosave_check.disabled = false
	_autosave_check.button_pressed = true
	save_path = path


func save_to_file(path: String):
	# Check file extension is .ds-json
	if not path.ends_with(".ds-json"):
		path += ".ds-json"

	var save_data = get_save_data()
	_last_save_data = save_data

	var save_file = FileAccess.open(path, FileAccess.WRITE)
	save_file.store_line(JSON.stringify(save_data))
	_current_save_hash = 0


func _on_save_button_pressed():
	fd_writer.visible = true
	fd_reader.visible = false


func _on_fd_reader_file_selected(path: String):
	var load_file = FileAccess.open(path, FileAccess.READ)

	if load_file.file_exists(path):
		var load_data_json = load_file.get_line()
		var load_data = JSON.parse_string(load_data_json)

		load_save_data(load_data)
		save_path = path
