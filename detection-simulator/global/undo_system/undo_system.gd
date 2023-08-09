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
		_action_list.resize(_action_list_pos + 1)

	if execute:
		new_action.do()

	_action_list.append(new_action)
	_action_list_pos += 1

func undo() -> bool:
	if _action_list_pos > -1:
		_action_list[_action_list_pos].undo()
		_action_list_pos -= 1

		return true

	return false

func redo() -> bool:
	if _action_list_pos < len(_action_list) - 1:
		_action_list_pos += 1
		_action_list[_action_list_pos].do()

		return true

	return false
