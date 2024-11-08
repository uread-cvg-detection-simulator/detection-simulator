extends Control

@export_group("Interactable GUI Elements")
@export var description_edit: TextEdit = null
@export var type_edit: TextEdit = null
@export var trigger_item_list: ItemList = null
@export var trigger_overall_item_list: ItemList = null

# Called when the node enters the scene tree for the first time.
func _ready():
	trigger_item_list.select(0)
	trigger_overall_item_list.select(0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
