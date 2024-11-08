class_name UndoRedoAction
extends RefCounted

var action_name: String = ""
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
func manual_add_item_to_store(item, ref_object = null) -> String:
	var new_ref = null

	if ref_object:
		new_ref = ref_object
	else:
		new_ref = Uuid.v4()

	_item_store.add_to_store(new_ref, item)

	return new_ref

## Manually remove an item from store (happens immediately)
func manual_remove_item_from_store(ref_object: String):
	_item_store.remove_from_store(ref_object)

enum DoType {
	Do,
	Undo,
	OnRemoval,
}

## Call a method
func action_method(do_type: DoType, method: Callable, args: Array = [], args_ref = []):
	var new_action = UndoRedoActionItem.new()
	new_action.set_method(method, args, args_ref)

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

## Call a method and store the result in the item store
func action_store_method(do_type: DoType, method: Callable, args: Array = [], args_ref = []) -> String:
	var new_action = UndoRedoActionItem.new()
	var new_ref = new_action.set_store_method(method, args, args_ref)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

	return new_ref

## Set the property of an item in the item store
func action_property_ref(do_type: DoType, ref_object: String, property_name: String, value):
	var new_action = UndoRedoActionItem.new()
	new_action.set_property_ref(ref_object, property_name, value)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

## Call a method on an object
func action_object_call(do_type: DoType, object, method: String, args: Array = [], args_ref = []):
	var new_action = UndoRedoActionItem.new()
	new_action.set_object_call(object, method, args, args_ref)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

## Call a method on an item in the item store
func action_object_call_ref(do_type: DoType, ref_object: String, method: String, args: Array = [], args_ref = []):
	var new_action = UndoRedoActionItem.new()
	new_action.set_object_call_ref(ref_object, method, args, args_ref)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

## Call a method on an object and store the result in the item store
func action_store_object_call(do_type: DoType, object, method: String, args: Array = [], args_ref = []) -> String:
	var new_action = UndoRedoActionItem.new()
	var new_ref = new_action.set_store_object_call(object, method, args, args_ref)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

	return new_ref

## Call a method on an item in the item store and store the result in the item store
func action_store_object_call_ref(do_type: DoType, ref_object: String, method: String, args: Array = [], args_ref = []) -> String:
	var new_action = UndoRedoActionItem.new()
	var new_ref = new_action.set_store_object_call_ref(ref_object, method, args, args_ref)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)

	return new_ref

## Remove an item from the item store
func action_remove_item(do_type: DoType, ref_object: String):
	var new_action = UndoRedoActionItem.new()
	new_action.set_remove_item(ref_object)

	match do_type:
		DoType.Do:
			add_do(new_action)
		DoType.Undo:
			add_undo(new_action)
		DoType.OnRemoval:
			add_final(new_action)
