class_name UndoRedoActionItem
extends RefCounted

enum ActionType {
	METHOD,
	PROPERTY,

	STORE_METHOD,

	PROPERTY_REF,

	OBJECT_CALL,
	OBJECT_CALL_REF,

	STORE_OBJECT_CALL,
	STORE_OBJECT_CALL_REF,

	REMOVE_REF,
	UNSET,
}

var _action_type: ActionType = ActionType.UNSET
var _action_properties: Array = []
var _item_store: UndoRedoItemStore = null

func _duplicate(array):

	if array is Array:
		var new_array = []
		for item in array:
			if item is String:
				var new_string = item
				new_array.append(new_string)
			elif item is Array:
				new_array.append(_duplicate(item))
			else:
				new_array.append(item)
		return new_array
	else:
		return array

## Call a method
##
## arg_refs is a list of references to items in the item store
##          if found in the list of args, they will be replaced with the item
func set_method(method: Callable, args: Array = [], arg_refs = []):
	_action_type = ActionType.METHOD
	_action_properties = [method, _duplicate(args), _duplicate(arg_refs)]

## Set a Property
func set_property(object: Object, property_name: String, value):
	_action_type = ActionType.PROPERTY
	_action_properties = [object, property_name, _duplicate(value)]

## Run a method and store the output in the item store
##
## arg_refs is a list of references to items in the item store
##          if found in the list of args, they will be replaced with the item
func set_store_method(method: Callable, args: Array, arg_refs = []) -> String:
	_action_type = ActionType.STORE_METHOD

	var new_ref = Uuid.v4()
	_action_properties = [new_ref, method, _duplicate(args), _duplicate(arg_refs)]

	return new_ref

## Set the property of an item in the item store
func set_property_ref(ref: String, property_name: String, value):
	_action_type = ActionType.PROPERTY_REF
	_action_properties = [ref, property_name, _duplicate(value)]


## Call a method on an object
## WARNING: This will crash if the object is deleted
##
## arg_refs is a list of references to items in the item store
##          if found in the list of args, they will be replaced with the item
func set_object_call(object: Object, method: String, args: Array = [], arg_refs = []):
	_action_type = ActionType.OBJECT_CALL
	_action_properties = [object, method, _duplicate(args), _duplicate(arg_refs)]

## Call a method on an object in the item store
##
## arg_refs is a list of references to items in the item store
##          if found in the list of args, they will be replaced with the item
func set_object_call_ref(ref: String, method: String, args: Array = [], arg_refs = []):
	_action_type = ActionType.OBJECT_CALL_REF
	_action_properties = [ref, method, _duplicate(args), _duplicate(arg_refs)]

## Call a method on an object and store the output in the item store
## WARNING: This will crash if the object is deleted
##
## arg_refs is a list of references to items in the item store
##          if found in the list of args, they will be replaced with the item
func set_store_object_call(object: Object, method: String, args: Array = [], arg_refs = []) -> String:
	_action_type = ActionType.STORE_OBJECT_CALL

	var new_ref = Uuid.v4()
	_action_properties = [new_ref, object, method, _duplicate(args), _duplicate(arg_refs)]

	return new_ref

## Call a method on an object in the item store and store the output in the item store
##
## arg_refs is a list of references to items in the item store
##  		if found in the list of args, they will be replaced with the item
func set_store_object_call_ref(ref: String, method: String, args: Array = [], arg_refs = []) -> String:
	_action_type = ActionType.STORE_OBJECT_CALL_REF

	var new_ref = Uuid.v4()
	_action_properties = [new_ref, ref, method, _duplicate(args), _duplicate(arg_refs)]

	return new_ref

## Remove an item from the item store
func set_remove_item(ref: String):
	_action_type = ActionType.REMOVE_REF
	_action_properties = [ref]

## Finds the items in the item store and replaces the args with the items
## refs can be a list of strings or a single string
func _replace_args_with_ref(args: Array, refs):
	var new_args = args.duplicate()

	if refs is String:
		refs = [refs]

	for ref in refs:
		var index = new_args.find(ref)
		if index != -1:
			new_args[index] = _item_store.get_from_store(ref)

	return new_args


## Run the action
func run():
	#print_debug("Running action: " + str(_action_type) + " " + str(_action_properties))
	match _action_type:
		ActionType.METHOD:
			# 0 = method
			# 1 = args
			# 2 = arg refs
			if _action_properties[1].size() == 0:
				_action_properties[0].call()
			else:
				var args = _replace_args_with_ref(_action_properties[1], _action_properties[2])
				_action_properties[0].callv(args)
		ActionType.PROPERTY:
			# 0 = object
			# 1 = property name
			# 2 = value
			_action_properties[0].set(_action_properties[1], _action_properties[2])
		ActionType.STORE_METHOD:
			# 0 = output ref
			# 1 = method
			# 2 = args
			# 3 = arg refs
			if _item_store:
				# If no args, just call the method
				# If args, replace the args with the items in the item store
				var result = null
				if _action_properties[2].size() == 0:
					result = _action_properties[1].call()
				else:
					var args = _replace_args_with_ref(_action_properties[2], _action_properties[3])
					result = _action_properties[1].callv(args)

				_item_store.add_to_store(_action_properties[0], result)
		ActionType.PROPERTY_REF:
			# 0 = ref
			# 1 = property name
			# 2 = value
			if _item_store:
				var item = _item_store.get_from_store(_action_properties[0])
				item.set(_action_properties[1], _action_properties[2])
		ActionType.OBJECT_CALL:
			# 0 = object
			# 1 = method
			# 2 = args
			# 3 = arg refs
			if _item_store:
				# If no args, just call the method
				# If args, replace the args with the items in the item store
				if _action_properties[2].size() == 0:
					_action_properties[1].call(_action_properties[0])
				else:
					var args = _replace_args_with_ref(_action_properties[2], _action_properties[3])
					_action_properties[1].callv(_action_properties[0], args)
			else:
				_action_properties[1].call(_action_properties[0], _action_properties[2])
		ActionType.OBJECT_CALL_REF:
			# 0 = ref
			# 1 = method
			# 2 = args
			# 3 = arg refs
			if _item_store:
				var item = _item_store.get_from_store(_action_properties[0])
				# If no args, just call the method
				# If args, replace the args with the items in the item store
				if _action_properties[2].size() == 0:
					item.call(_action_properties[1])
				else:
					var args = _replace_args_with_ref(_action_properties[2], _action_properties[3])
					item.callv(_action_properties[1], args)
		ActionType.STORE_OBJECT_CALL:
			# 0 = output ref
			# 1 = object
			# 2 = method
			# 3 = args
			if _item_store:
				var result = null
				if _action_properties[3].size() == 0:
					result = _action_properties[1].call(_action_properties[2])
				else:
					var args = _replace_args_with_ref(_action_properties[3], _action_properties[4])
					result = _action_properties[1].callv(_action_properties[2], args)
				_item_store.add_to_store(_action_properties[0], result)
		ActionType.STORE_OBJECT_CALL_REF:
			# 0 = output ref
			# 1 = ref
			# 2 = method
			# 3 = args
			if _item_store:
				var item = _item_store.get_from_store(_action_properties[1])
				var result = null
				if _action_properties[3].size() == 0:
					result = item.call(_action_properties[2])
				else:
					var args = _replace_args_with_ref(_action_properties[3], _action_properties[4])
					result = item.callv(_action_properties[2], args)
				_item_store.add_to_store(_action_properties[0], result)
		ActionType.REMOVE_REF:
			# 0 = ref
			if _item_store:
				_item_store.remove_from_store(_action_properties[0])
