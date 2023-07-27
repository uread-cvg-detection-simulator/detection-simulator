extends Node2D

@onready var _rightclick_empty: PopupMenu = $empty_right_click_menu
@onready var _agent_base: PackedScene = load("res://agents/agent.tscn")
@onready var _agent_root = $agents

var _agent_list: Array[Agent]

enum empty_menu_enum {
	SPAWN_AGENT
}

# Called when the node enters the scene tree for the first time.
func _ready():
	_rightclick_empty.add_item("Spawn New Agent", empty_menu_enum.SPAWN_AGENT)
	_rightclick_empty.connect("id_pressed", self._on_empty_menu_press)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

var _scrolling = false

func _input(event):
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		_right_click(event)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var tmp_event: InputEventMouse = event

			if not _scrolling and tmp_event.is_pressed():
				_scrolling = true

			if _scrolling and tmp_event.is_released():
				_scrolling = false

	if event is InputEventMouseMotion and _scrolling:
		var tmp_event: InputEventMouseMotion = event

		$Camera2D.position -= tmp_event.relative

var _right_click_position = null

func _right_click(event: InputEventMouseButton):
	var mouse_pos = get_global_mouse_position()
	var mouse_rel_pos = mouse_pos - $Camera2D.global_position
	var window_size = get_window().size / 2

	_rightclick_empty.popup(Rect2i(mouse_rel_pos.x + window_size.x, mouse_rel_pos.y + window_size.y, _rightclick_empty.size.x, _rightclick_empty.size.y))
	_right_click_position = mouse_pos

func _on_empty_menu_press(id: int):
	if id == empty_menu_enum.SPAWN_AGENT:
		spawn_agent(_right_click_position)

func spawn_agent(position: Vector2):
	var new_agent: Agent = _agent_base.instantiate()
	new_agent.global_position = position

	_agent_root.add_child(new_agent)

