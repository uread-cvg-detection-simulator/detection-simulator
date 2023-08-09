extends Node

var _action_list: Array[UndoRedoAction] = []
var _action_list_pos = -1 ## Latest action position

func has_undo() -> bool:
	if _action_list_pos >= 0 and not _action_list.is_empty():
		return true

	return false

func has_redo() -> bool:
	if not _action_list.is_empty() and _action_list_pos < len(_action_list) - 1:
		return true

	return false

func add_action(new_action: UndoRedoAction, execute: bool = true):
	if _action_list_pos != len(_action_list) - 1:
		for action in _action_list.slice(_action_list_pos+1):
			print_debug("Undo System: Finalising [ %s ]" % action._action_name)
			action.final()

		_action_list.resize(_action_list_pos + 1)

	if execute:
		new_action.do()

	print_debug("Undo System: New Action [ %s ]" % new_action._action_name)
	_action_list.append(new_action)
	_action_list_pos += 1

func undo() -> bool:
	if _action_list_pos > -1:
		print_debug("Undo System: Undo [ %s ]" % _action_list[_action_list_pos]._action_name)
		_action_list[_action_list_pos].undo()
		_action_list_pos -= 1

		return true

	return false

func redo() -> bool:
	if _action_list_pos < len(_action_list) - 1:
		print_debug("Undo System: Redo [ %s ]" % _action_list[_action_list_pos]._action_name)
		_action_list_pos += 1
		_action_list[_action_list_pos].do()

		return true

	return false

func clear_history():
	for action in _action_list:
		print_debug("Undo System: Clearing System - Finalising [ %s ]" % action._action_name)
		action.final()

	_action_list = []
	_action_list_pos = -1
