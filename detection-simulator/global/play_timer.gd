extends Node

var current_time: float = 0.00
var previous_time: float = 0.00
var play: bool = false : set = _set_play
var exporting: bool = false
var export_scale: float = 1.0
var ui_scale: float = 1.0

signal start_playing()
signal stop_playing()

func _physics_process(delta):
	if play:
		# Is this timer accurate enough?
		previous_time = current_time
		current_time += delta

func _set_play(value):
	if value:
		current_time = 0.00
		emit_signal("start_playing")
	else:
		emit_signal("stop_playing")

	play = value

