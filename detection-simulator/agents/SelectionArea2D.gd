class_name SelectionArea2D
extends Area2D

# Based on https://www.youtube.com/watch?v=K9DenBHIDzU

signal selection_toggled(selection)

@export var exclusive = true
@export var selection_action = "mouse_selected"

var selected: bool = false : set = _set_selected

func _set_selected(new_selected: bool):
	if new_selected:
		_make_exclusive()
		add_to_group("selected")
	else:
		remove_from_group("selected")
	
	selected = new_selected
	emit_signal("selection_toggled", selected)

func _make_exclusive():
	if exclusive:
		get_tree().call_group("selected", "_set_selected", false)

# Must be connected to Area's input_event
func _on_input_event(viewport: Viewport, event, shape_idx):
	if event.is_action_pressed(selection_action):
		selected = not selected
		viewport.set_input_as_handled()

