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

func _input(event):
	if event is InputEventMouse and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		_right_click(event)

var _right_click_position = null

func _right_click(event: InputEventMouseButton):
	var mouse_pos = get_global_mouse_position()
	var window_size = get_window().size / 2

	_rightclick_empty.popup(Rect2i(mouse_pos.x + window_size.x, mouse_pos.y + window_size.y, _rightclick_empty.size.x, _rightclick_empty.size.y))
	_right_click_position = mouse_pos

func _on_empty_menu_press(id: int):
	if id == empty_menu_enum.SPAWN_AGENT:
		spawn_agent(_right_click_position)

func spawn_agent(position: Vector2):
	var new_agent: Agent = _agent_base.instantiate()
	new_agent.global_position = position

	_agent_root.add_child(new_agent)

