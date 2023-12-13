class_name DragableObjectComponent
extends Node2D

@export var parent_object: Node2D = null

signal while_moving(start_pos, current_pos)
signal finished_moving(start_pos, end_pos)

var clickable = true

var _moving = false
var _moving_start_pos: Vector2 = Vector2.ZERO

func _unhandled_input(event):
	if event is InputEventMouseMotion and _moving and clickable:
		parent_object.global_position = get_global_mouse_position()

		while_moving.emit(_moving_start_pos, parent_object.global_position)

func _on_hold():
	if clickable:
		_moving = true
		_moving_start_pos = parent_object.global_position

## Handles when mouse has stopped being held
func _on_hold_stop():
	_moving = false

	if _moving_start_pos:
		if _moving_start_pos != parent_object.global_position:
			finished_moving.emit(_moving_start_pos, parent_object.global_position)
			_moving_start_pos = Vector2.ZERO


