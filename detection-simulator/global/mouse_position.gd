extends Node2D

var mouse_global_position: Vector2 = Vector2.ZERO
var mouse_relative_position: Vector2 = Vector2.ZERO

func set_mouse_position(scene_global_position: Vector2, viewport_mouse_position: Vector2):
	mouse_global_position = scene_global_position
	mouse_relative_position = viewport_mouse_position
