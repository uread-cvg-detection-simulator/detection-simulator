class_name SelectionArea2D
extends Area2D

# Based on https://www.youtube.com/watch?v=K9DenBHIDzU

signal selection_toggled(selection)
signal mouse_click(button, event)
signal mouse_hold_start()
signal mouse_hold_end()

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
			# If selecting multiple, then temporarily disable exclusivity
			selection_exclusive = false
			selected = not selected
			selection_exclusive = true

		viewport.set_input_as_handled()
	elif event.is_action_pressed(selection_action):
		if !passthrough_mode:
			selected = not selected

		# Emit the event as a signal
		emit_signal("mouse_click", MOUSE_BUTTON_LEFT, event)
		viewport.set_input_as_handled()

		# Create mouse hold timer
		var temp_timer = get_tree().create_timer(0.25)
		temp_timer.connect("timeout", self._mouse_held_timeout)

	elif event.is_action_pressed("mouse_menu"):
		# Emit the event as a signal
		emit_signal("mouse_click", MOUSE_BUTTON_RIGHT, event)
		viewport.set_input_as_handled()

func _input(event):
	if _mouse_held and event.is_action_released("mouse_selected"):
		_mouse_held = false
		emit_signal("mouse_hold_end")
		print_debug("Mouse Unheld: %d" % get_instance_id())

var _mouse_hovered = false
var _mouse_held = false

func _mouse_held_timeout():
	if Input.is_action_pressed("mouse_selected"):
		_mouse_held = true
		emit_signal("mouse_hold_start")
		print_debug("Mouse Held: %d" % get_instance_id())

func _mouse_enter():
	_mouse_hovered = true
	add_to_group("mouse_hovered")

func _mouse_exit():
	_mouse_hovered = false
	remove_from_group("mouse_hovered")
