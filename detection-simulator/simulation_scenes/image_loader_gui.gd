extends CanvasLayer

@export var play_bar_container: HBoxContainer = null
@export var play_bar_container_spacer: CanvasItem = null
@export var status_label: Label = null

func _ready():
	get_tree().get_root().connect("size_changed", self._on_size_changed)

func _on_size_changed():
	# Modify Properties size to
	if get_viewport():
		var viewport_size = get_viewport().size

		resize_spacer()

func resize_spacer():
	# Modify Properties size to
	var viewport_size = get_viewport().size

	# Expand "Spacer" (child node of play_bar_container) to fill the remaining space between previous and subsequent nodes
	var play_bar_previous_size = 0
	var play_bar_next_size = 0
	var spacer_found = false

	for child in play_bar_container.get_children():
		if child == play_bar_container_spacer:
			spacer_found = true
			continue

		if not spacer_found:
			play_bar_previous_size += child.size.x
		else:
			play_bar_next_size += child.size.x

	play_bar_container_spacer.custom_minimum_size.x = viewport_size.x - play_bar_previous_size - play_bar_next_size - 20
