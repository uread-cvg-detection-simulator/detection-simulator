extends Node2D

@onready var _rightclick_empty: PopupMenu = $empty_right_click_menu
@onready var _agent_base: PackedScene = load("res://agents/agent.tscn")
@onready var _agent_root = $agents

var _agent_list: Array[Agent]

var _last_id = 0

var _scrolling = false ## Set when drag-scrolling
var _right_click_position = null ## Set to ensure popup menus act on correct mouse position

enum empty_menu_enum {
	SPAWN_AGENT,
	RETURN_TO_CENTRE,
	CLEAR_UNDO_HISTORY
}

# Called when the node enters the scene tree for the first time.
func _ready():
	_rightclick_empty.add_item("Spawn New Agent", empty_menu_enum.SPAWN_AGENT)
	_rightclick_empty.add_separator()
	_rightclick_empty.add_item("Centre Grid", empty_menu_enum.RETURN_TO_CENTRE)
	_rightclick_empty.add_item("Clear Undo History", empty_menu_enum.CLEAR_UNDO_HISTORY)
	_rightclick_empty.connect("id_pressed", self._on_empty_menu_press)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _unhandled_input(event):
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

	# Stop scrolling if mouse is released
	if _scrolling and event.is_action_released("mouse_selected"):
		_scrolling = false

	# Handle Undo System
	if event.is_action_pressed("ui_undo"):
		if UndoSystem.has_undo():
			UndoSystem.undo()

	if event.is_action_pressed("ui_redo"):
		if UndoSystem.has_redo():
			UndoSystem.redo()

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

func spawn_agent(position: Vector2):
	var undo_action = UndoRedoAction.new()
	undo_action._action_name = "Spawn Agent %d" % [_last_id + 1]

	############
	# DO ACTIONS
	############

	var duplicate_lambda = func(x):
		return x.duplicate()

	# Create the new agent at the provided location
	var newinstance_ref = undo_action.action_create_ref(UndoRedoAction.DoType.Do, _agent_base.instantiate)
	var duplicate_ref = undo_action.action_create_method_ref(UndoRedoAction.DoType.Do, newinstance_ref, duplicate_lambda)
	undo_action.action_remove_ref(UndoRedoAction.DoType.Do, newinstance_ref)

	# Set position and agent id
	undo_action.action_property_ref(UndoRedoAction.DoType.Do, duplicate_ref, "global_position", position)
	undo_action.action_property_ref(UndoRedoAction.DoType.Do, duplicate_ref, "agent_id", _last_id + 1)
	undo_action.action_property(UndoRedoAction.DoType.Do, self, "_last_id", _last_id + 1)

	# Add to scene tree
	undo_action.action_method_ref(UndoRedoAction.DoType.Do, duplicate_ref, _agent_root.add_child)
	undo_action.action_method_ref(UndoRedoAction.DoType.Do, duplicate_ref, func(x): x.add_to_group("agent"))

	# Set camera
	undo_action.action_property_ref(UndoRedoAction.DoType.Do, duplicate_ref, "camera", $Camera2D)

	##############
	# UNDO ACTIONS
	##############

	# Remove from scene tree
	undo_action.action_method_ref(UndoRedoAction.DoType.Undo, duplicate_ref, self.remove_child)

	# Reset last id
	undo_action.action_property(UndoRedoAction.DoType.Undo, self, "_last_id", _last_id)

	# Queue Deletion
	undo_action.action_method_ref(UndoRedoAction.DoType.Undo, duplicate_ref, func(x): x.queue_free())

	# Remove Reference
	undo_action.action_remove_ref(UndoRedoAction.DoType.Undo, duplicate_ref)

	########
	# COMMIT
	########

	UndoSystem.add_action(undo_action)

