class_name UndoRedoActionItem
extends RefCounted

enum ActionType {
	METHOD,
	PROPERTY,
	CREATE_REF,
	CREATE_ARGS_REF,
	CREATE_METHOD_REF,
	METHOD_REF,
	METHOD_ARGS_REF,
	PROPERTY_REF,
	REMOVE_REF,
	UNSET,
}

var _action_type: ActionType = ActionType.UNSET
var _action_properties: Array = []
var _item_store: UndoRedoItemStore = null

## Call a method
func set_method(method: Callable):
	_action_type = ActionType.METHOD
	_action_properties = [method]

## Set a Property
func set_property(object: Object, property_name: String, value):
	_action_type = ActionType.PROPERTY
	_action_properties = [object, property_name, value]

func set_property_ref(ref: String, property_name: String, value):
	_action_type = ActionType.PROPERTY_REF
	_action_properties = [ref, property_name, value]

## Run a method that returns items into a temporary item store for this action
func set_create_ref(method: Callable) -> String:
	_action_type = ActionType.CREATE_REF

	var new_ref = Uuid.v4()
	_action_properties = [new_ref, method]

	return new_ref

## Run a method on an item store reference, and store it's output as a new reference
func set_create_args_ref(method: Callable, args: Array) -> String:
	_action_type = ActionType.CREATE_ARGS_REF

	var new_ref = Uuid.v4()
	_action_properties = [new_ref, method, args]

	return new_ref

## Run a method on an item store reference, and store it's output as a new reference
func set_create_method_ref(ref: String, method: Callable) -> String:
	_action_type = ActionType.CREATE_METHOD_REF

	var new_ref = Uuid.v4()
	_action_properties = [new_ref, ref, method]

	return new_ref

## Call a method with one argument with the object in the item store
## e.g. use a func/lambda to call the correct method
func set_method_ref(ref: String, method: Callable):
	_action_type = ActionType.METHOD_REF
	_action_properties = [ref, method]

## Call a method and replace the 'ref' in args with the object stored
## in the item store
## e.g. set_method_with_ref(reference, my_method, [ arg_1, arg_2, reference ])
##   -> my_method(arg_1, arg_2, referenced_object)
func set_method_with_ref(ref: String, method: Callable, args: Array):
	_action_type = ActionType.METHOD_ARGS_REF
	_action_properties = [ref, method, args]

## Remove an item from the item store
func set_remove_ref(ref: String):
	_action_type = ActionType.REMOVE_REF
	_action_properties = [ref]

## Run the action
func run():
	match _action_type:
		ActionType.METHOD:
			_action_properties[0].call()
		ActionType.PROPERTY:
			_action_properties[0].set(_action_properties[1], _action_properties[2])
		ActionType.PROPERTY_REF:
			if _item_store:
				var item = _item_store.get_from_store(_action_properties[0])
				item.set(_action_properties[1], _action_properties[2])
		ActionType.CREATE_REF:
			if _item_store:
				var item = _action_properties[1].call()
				_item_store.add_to_store(_action_properties[0], item)
		ActionType.CREATE_ARGS_REF:
			if _item_store:
				var item = _action_properties[1].callv(_action_properties[2])
				_item_store.add_to_store(_action_properties[0], item)
		ActionType.CREATE_METHOD_REF:
			if _item_store:
				var item = _item_store.get_from_store(_action_properties[1])
				var new_item = _action_properties[2].call(item)
				_item_store.add_to_store(_action_properties[0], new_item)
		ActionType.METHOD_REF:
			if _item_store:
				var item = _item_store.get_from_store(_action_properties[0])
				_action_properties[1].call(item)
		ActionType.METHOD_ARGS_REF:
			if _item_store:
				var item = _item_store.get_from_store(_action_properties[0])
				var args: Array = _action_properties[1]
				var args_ref_index = args.find(_action_properties[0])

				if args_ref_index != -1:
					args[args_ref_index] = item

				_action_properties[2].callv(args)
		ActionType.REMOVE_REF:
			if _item_store:
				_item_store.remove_from_store(_action_properties[0])
