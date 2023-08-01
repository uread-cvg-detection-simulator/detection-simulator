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
	RETURN_TO_CENTRE
}

# Called when the node enters the scene tree for the first time.
func _ready():
	_rightclick_empty.add_item("Spawn New Agent", empty_menu_enum.SPAWN_AGENT)
	_rightclick_empty.add_separator()
	_rightclick_empty.add_item("Centre Grid", empty_menu_enum.RETURN_TO_CENTRE)
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

func spawn_agent(position: Vector2):
	# Create the new agent at the provided location
	var new_agent = _agent_base.instantiate().duplicate()
	new_agent.global_position = position

	# Set a new ID (TODO: keep id list to agents, so can repurpose)
	new_agent.agent_id = _last_id + 1
	_last_id += 1

	# Add the new agent to the scene tree
	_agent_root.add_child(new_agent)

