class_name SelectionArea2D
extends Area2D

# Based on https://www.youtube.com/watch?v=K9DenBHIDzU

signal selection_toggled(selection)
signal mouse_click(button, event)

@export var selection_exclusive = true
@export var selection_action = "mouse_selected"
@export var multi_selection_action = "mouse_multi_select"

@export var passthrough_mode = false ## Passes through left click rather than select

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
	if selection_exclusive:
		get_tree().call_group("selected", "_set_selected", false)

# Must be connected to Area's input_event
func _input_event(viewport: Viewport, event, shape_idx):
	if event.is_action_pressed(multi_selection_action):
		if !passthrough_mode:
			selection_exclusive = false
			selected = not selected
			selection_exclusive = true
		
		viewport.set_input_as_handled()
	elif event.is_action_pressed(selection_action):
		if !passthrough_mode:
			selected = not selected
		
		emit_signal("mouse_click", MOUSE_BUTTON_LEFT, event)
		viewport.set_input_as_handled()
	elif event.is_action_pressed("mouse_menu"):
		emit_signal("mouse_click", MOUSE_BUTTON_RIGHT, event)
		viewport.set_input_as_handled()


