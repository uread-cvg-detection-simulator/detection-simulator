class_name UndoRedoItemStore
extends RefCounted

var store = {}

func add_to_store(key, value):
	store[key] = value

func remove_from_store(key):
	store.erase(key)

func get_from_store(key):
	if store.has(key):
		return store[key]
	else:
		return null
