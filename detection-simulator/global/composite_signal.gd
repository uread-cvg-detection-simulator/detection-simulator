class_name CompositeSignal
extends Node

signal finished

var _remaining : int

func add_signal(sig: Signal):
	_remaining += 1
	await sig
	_remaining -= 1
	if _remaining == 0:
		finished.emit()


func add_call(object, method_name:String, argv:Array=[])->void:
	_remaining += 1
	await object.callv(method_name, argv)
	_remaining -= 1
	if _remaining == 0:
		finished.emit()
