class_name UndoRedoAction
extends RefCounted

var _action_name: String = ""
var _do_list: Array[UndoRedoActionItem] = []
var _undo_list: Array[UndoRedoActionItem] = []
var _del_list: Array[UndoRedoActionItem] = []

var _item_store: UndoRedoItemStore = UndoRedoItemStore.new()

func add_do(item: UndoRedoActionItem):
	item._item_store = _item_store
	_do_list.append(item)

func add_undo(item: UndoRedoActionItem):
	item._item_store = _item_store
	_undo_list.append(item)

func add_final(item: UndoRedoActionItem):
	item._item_store = _item_store
	_del_list.append(item)

func do():
	for action in _do_list:
		action.run()

func undo():
	for action in _undo_list:
		action.run()

func final():
	for action in _del_list:
		action.run()

## Manually add an item to store (happens immediately)
func add_item_to_store(item) -> String:
	var new_ref = Uuid.v4()
	
	_item_store.add_to_store(new_ref, item)
	
	return new_ref

func remove_item_from_store(ref: String):
	return _item_store.remove_from_store(ref)

enum DoType {
	Do,
	Undo,
	OnRemoval,
}

## Call a method
func action_method(do_type: DoType, method: Callable):
	var new_action = UndoRedoActionItem.new()
	new_action.set_method(method)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

## Set a Property
func action_property(do_type: DoType, object: Object, property_name: String, value):
	var new_action = UndoRedoActionItem.new()
	new_action.set_property(object, property_name, value)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

func action_property_ref(do_type: DoType, ref: String, property_name: String, value):
	var new_action = UndoRedoActionItem.new()
	new_action.set_property_ref(ref, property_name, value)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

## Run a method that returns items into a temporary item store for this action
func action_create_ref(do_type: DoType, method: Callable) -> String:
	var new_action = UndoRedoActionItem.new()
	var reference = new_action.set_create_ref(method)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

	return reference

## Run a method that returns items into a temporary item store for this action
func action_create_args_ref(do_type: DoType, method: Callable, args: Array) -> String:
	var new_action = UndoRedoActionItem.new()
	var reference = new_action.set_create_args_ref(method, args)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

	return reference

## Run a method on an item store reference, and store it's output as a new reference
func action_create_method_ref(do_type: DoType, ref: String, method: Callable) -> String:
	var new_action = UndoRedoActionItem.new()
	var reference = new_action.set_create_method_ref(ref, method)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

	return reference

## Call a method with one argument with the object in the item store
## e.g. use a func/lambda to call the correct method
func action_method_ref(do_type: DoType, ref: String, method: Callable):
	var new_action = UndoRedoActionItem.new()
	new_action.set_method_ref(ref, method)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

## Call a method and replace the 'ref' in args with the object stored
## in the item store
## e.g. set_method_with_ref(reference, my_method, [ arg_1, arg_2, reference ])
##   -> my_method(arg_1, arg_2, referenced_object)
func action_method_args_ref(do_type: DoType, ref: String, method: Callable, args: Array):
	var new_action = UndoRedoActionItem.new()
	new_action.set_method_with_ref(ref, method, args)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

## Call a method with one argument with the object in the item store
## e.g. use a func/lambda to call the correct method
func action_remove_ref(do_type: DoType, ref: String):
	var new_action = UndoRedoActionItem.new()
	new_action.set_remove_ref(ref)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

func action_object_call(do_type: DoType, object: Object, method: String, args: Array = []):
	var new_action = UndoRedoActionItem.new()
	new_action.set_object_call(object, method, args)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

func action_object_call_ref(do_type: DoType, ref: String, method: String, args: Array = []):
	var new_action = UndoRedoActionItem.new()
	new_action.set_object_call_ref(ref, method, args)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)
