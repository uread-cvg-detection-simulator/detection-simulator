extends HBoxContainer

@export_group("GUI Elements")
@export var label_index: Label = null
@export var label_agent_info: Label = null
@export var button_delete: Button = null

var _index: int = -1
var _agent_id: int = -1
var _waypoint_id: int = -1

signal delete_signal(agent_id: int, waypoint_id: int, index: int)

func set_info(agent_id: int, waypoint_id: int):
	_waypoint_id = waypoint_id
	_agent_id = agent_id

	_set_text()

func set_index(index: int):
	_index = index

	_set_text()

func _set_text():
	label_index.text = str(_index)
	label_agent_info.text = "    A{} W{}    " % [_agent_id, _waypoint_id]

func _on_delete_button_pressed():
	delete_signal.emit(_agent_id, _waypoint_id, _index)
